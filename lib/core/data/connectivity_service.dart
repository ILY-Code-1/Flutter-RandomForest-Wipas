import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports whether the device has a network connection.
abstract class ConnectivityService {
  Stream<bool> watchOnline();
}

class PluginConnectivityService implements ConnectivityService {
  PluginConnectivityService([Connectivity? connectivity]) : _c = connectivity ?? Connectivity();
  final Connectivity _c;

  static bool _isOnline(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  @override
  Stream<bool> watchOnline() async* {
    yield _isOnline(await _c.checkConnectivity());
    yield* _c.onConnectivityChanged.map(_isOnline).distinct();
  }
}

/// Stores the time of the last snapshot that came from the server
/// (not from the offline cache), shown as "Terakhir disinkronkan".
class SyncClock extends StateNotifier<DateTime?> {
  SyncClock(this._prefs, this._now) : super(_read(_prefs));

  static const prefsKey = 'last_server_sync_ms';
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static DateTime? _read(SharedPreferences p) {
    final ms = p.getInt(prefsKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Call for every snapshot; only server snapshots move the clock.
  void report({required bool fromCache}) {
    if (fromCache) return;
    final now = _now();
    // Avoid hammering shared_preferences: at most once per 30 s.
    if (state != null && now.difference(state!).inSeconds.abs() < 30) return;
    state = now;
    unawaited(_prefs.setInt(prefsKey, now.millisecondsSinceEpoch));
  }
}
