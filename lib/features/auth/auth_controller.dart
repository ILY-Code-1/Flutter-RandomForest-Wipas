import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.user, this.sessionExpired = false, this.message});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final AppUser? user;

  /// Set after an automatic 24-hour sign-out (Login shows "Sesi berakhir").
  final bool sessionExpired;

  /// Account problem shown on Login (e.g. missing role document).
  final String? message;
}

/// Auth messages shown in the UI.
class AuthMessages {
  AuthMessages._();
  static const wrongCredentials = 'Email atau password salah';
  static const invalidEmail = 'Format email tidak valid';
  static const network = 'Tidak dapat terhubung. Periksa koneksi lalu coba lagi.';
  static const tooMany = 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
  static const noRole = 'Akun belum memiliki role. Hubungi administrator.';
  static const generic = 'Gagal masuk. Coba lagi.';
}

/// Exception carrying a user-facing message.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider).collection(Col.users),
    ref.watch(sharedPrefsProvider),
    ref.watch(clockProvider),
  );
});

/// Owns the Firebase Auth session, loads the role from `users/{uid}` and
/// enforces the 24-hour session lifetime.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._auth, this._users, this._prefs, this._now) : super(const AuthState.unknown()) {
    _sub = _auth.authStateChanges().listen(_onUser, onError: (_) {
      state = const AuthState(status: AuthStatus.signedOut);
    });
  }

  static const sessionKey = 'session_started_ms';

  final FirebaseAuth _auth;
  final CollectionReference<Map<String, dynamic>> _users;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  StreamSubscription<User?>? _sub;
  bool _expiring = false;

  Future<void> _onUser(User? user) async {
    if (user == null) {
      state = AuthState(
        status: AuthStatus.signedOut,
        sessionExpired: _expiring || state.sessionExpired,
        message: state.message,
      );
      _expiring = false;
      return;
    }
    if (_sessionStart() == null) _markSessionStart();
    if (isSessionExpired()) {
      await expireSession();
      return;
    }
    try {
      final doc = await _users.doc(user.uid).get();
      final appUser = AppUser.fromDoc(user.uid, doc.data(), fallbackEmail: user.email);
      if (appUser == null) {
        state = const AuthState(status: AuthStatus.signedOut, message: AuthMessages.noRole);
        await _auth.signOut();
        return;
      }
      state = AuthState(status: AuthStatus.signedIn, user: appUser);
    } catch (_) {
      state = const AuthState(status: AuthStatus.signedOut, message: AuthMessages.network);
      await _auth.signOut();
    }
  }

  DateTime? _sessionStart() {
    final ms = _prefs.getInt(sessionKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  void _markSessionStart() => _prefs.setInt(sessionKey, _now().millisecondsSinceEpoch);

  /// True when the current session is older than [AppConfig.sessionLifetime].
  bool isSessionExpired() {
    final start = _sessionStart();
    if (start == null) return false;
    return _now().difference(start) >= AppConfig.sessionLifetime;
  }

  /// Signs out because the session lifetime elapsed.
  Future<void> expireSession() async {
    _expiring = true;
    await _prefs.remove(sessionKey);
    if (_auth.currentUser == null) {
      state = const AuthState(status: AuthStatus.signedOut, sessionExpired: true);
      _expiring = false;
      return;
    }
    await _auth.signOut();
  }

  /// Called when the app resumes; signs out an expired session.
  Future<void> checkSession() async {
    if (state.status == AuthStatus.signedIn && isSessionExpired()) await expireSession();
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState(status: state.status, user: state.user);
    try {
      _markSessionStart();
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      await _prefs.remove(sessionKey);
      throw AuthFailure(mapAuthError(e.code));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Do not reveal whether an account exists.
      if (e.code == 'user-not-found') return;
      throw AuthFailure(mapAuthError(e.code));
    }
  }

  Future<void> signOut() async {
    await _prefs.remove(sessionKey);
    state = const AuthState(status: AuthStatus.signedOut);
    await _auth.signOut();
  }

  static String mapAuthError(String code) => switch (code) {
        'invalid-email' => AuthMessages.invalidEmail,
        'wrong-password' || 'user-not-found' || 'invalid-credential' || 'user-disabled' =>
          AuthMessages.wrongCredentials,
        'network-request-failed' => AuthMessages.network,
        'too-many-requests' => AuthMessages.tooMany,
        _ => AuthMessages.generic,
      };

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
