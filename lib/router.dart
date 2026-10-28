import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/domain/access_matrix.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/beranda/beranda_screen.dart';
import 'features/dev/gallery_screen.dart';
import 'features/evaluasi/evaluasi_screen.dart';
import 'features/input_actual/input_actual_screen.dart';
import 'features/konfigurasi/konfigurasi_screen.dart';
import 'features/lainnya/lainnya_screen.dart';
import 'features/manpower/manpower_screen.dart';
import 'features/notifikasi/notifikasi_screen.dart';
import 'features/prediksi/prediksi_screen.dart';
import 'features/profil/profil_screen.dart';
import 'features/riwayat/riwayat_screen.dart';
import 'features/shell/app_shell.dart';

/// Bridges Riverpod auth changes to go_router's refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// RoleGuard: decides where a location may go for the current session.
/// Returns null to allow, or a redirect target.
String? roleGuard(AuthState auth, Uri uri) {
  final path = uri.path;
  if (path == Routes.gallery) return kDebugMode ? null : Routes.splash;
  if (path == Routes.splash) return null;
  switch (auth.status) {
    case AuthStatus.unknown:
      return Routes.splash;
    case AuthStatus.signedOut:
      if (Routes.public.contains(path)) return null;
      return auth.sessionExpired ? '${Routes.login}?expired=1' : Routes.login;
    case AuthStatus.signedIn:
      if (path == Routes.login || path == Routes.forgotPassword) return Routes.beranda;
      final role = auth.user!.role;
      return AccessMatrix.canOpen(role, path) ? null : Routes.beranda;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => roleGuard(ref.read(authControllerProvider), state.uri),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.login,
        builder: (_, s) => LoginScreen(sessionExpired: s.uri.queryParameters['expired'] == '1'),
        routes: [GoRoute(path: 'lupa', builder: (_, _) => const ForgotPasswordScreen())],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.beranda, builder: (_, _) => const BerandaScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.prediksi, builder: (_, _) => const PrediksiScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.manpower, builder: (_, _) => const ManpowerScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.evaluasi, builder: (_, _) => const EvaluasiScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.lainnya, builder: (_, _) => const LainnyaScreen())]),
        ],
      ),
      GoRoute(path: Routes.inputActual, builder: (_, _) => const InputActualScreen()),
      GoRoute(path: Routes.konfigurasi, builder: (_, _) => const KonfigurasiScreen()),
      GoRoute(path: Routes.riwayat, builder: (_, _) => const RiwayatScreen()),
      GoRoute(path: Routes.notifikasi, builder: (_, _) => const NotifikasiScreen()),
      GoRoute(path: Routes.profil, builder: (_, _) => const ProfilScreen()),
      GoRoute(path: Routes.gallery, builder: (_, _) => const GalleryScreen()),
    ],
    errorBuilder: (_, _) => const Scaffold(body: Center(child: Text('Halaman tidak ditemukan'))),
  );
});
