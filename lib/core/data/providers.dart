import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_controller.dart';
import '../config/app_config.dart';
import '../format/formatters.dart';
import 'connectivity_service.dart';
import 'models.dart';
import 'repository.dart';

// ------------------------------------------------------------ infrastructure

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Must be overridden in `main()` / tests with a loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('sharedPrefsProvider'));

/// Injectable clock (tests pin "now").
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => PluginConnectivityService());

/// True when the device has network connectivity.
final onlineProvider = StreamProvider<bool>((ref) => ref.watch(connectivityServiceProvider).watchOnline());

/// True when offline. Unknown connectivity counts as online.
final isOfflineProvider = Provider<bool>((ref) => ref.watch(onlineProvider).valueOrNull == false);

final syncClockProvider = StateNotifierProvider<SyncClock, DateTime?>(
    (ref) => SyncClock(ref.watch(sharedPrefsProvider), ref.watch(clockProvider)));

/// Today's date in WIB.
final todayProvider = Provider<DateTime>((ref) => Fmt.todayWib(ref.watch(clockProvider)()));

// ------------------------------------------------------------------- session

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);

final repositoryProvider = Provider<WipasRepository>((ref) {
  final wh = ref.watch(currentUserProvider.select((u) => u?.whId)) ?? AppConfig.defaultWhId;
  return WipasRepository(ref.watch(firestoreProvider), wh);
});

/// Unwraps a [Snap] stream and reports the cache flag to the [SyncClock].
Stream<T> _tracked<T>(Ref ref, Stream<Snap<T>> source) {
  final clock = ref.read(syncClockProvider.notifier);
  return source.map((s) {
    scheduleMicrotask(() => clock.report(fromCache: s.fromCache));
    return s.data;
  });
}

final warehouseProvider = StreamProvider<Warehouse>((ref) => ref.watch(repositoryProvider).watchWarehouse());

/// "Hub Cakung" (falls back to the warehouse id).
final warehouseNameProvider = Provider<String>((ref) {
  final repo = ref.watch(repositoryProvider);
  return ref.watch(warehouseProvider).valueOrNull?.name ?? repo.whId;
});

// ---------------------------------------------------------------- data feeds

/// Newest prediction = the batch's H+1 target.
final latestPredictionProvider = StreamProvider.autoDispose<Prediction?>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchLatestPrediction()));

/// Target date selected on Beranda/Prediksi (null = latest H+1).
final selectedDateProvider = StateProvider<DateTime?>((ref) => null);

/// Range query key: inclusive end date and number of days.
typedef DateRange = ({DateTime end, int days});

final predictionsInRangeProvider = StreamProvider.autoDispose.family<List<Prediction>, DateRange>((ref, r) {
  final start = r.end.subtract(Duration(days: r.days - 1));
  return _tracked(ref, ref.watch(repositoryProvider).watchPredictions(start, r.end, limit: r.days));
});

final configProvider = StreamProvider.autoDispose<OperationalConfig?>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchConfig()));

final modelHealthProvider = StreamProvider.autoDispose<ModelHealth?>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchModelHealth()));

final modelHealthHistoryProvider = StreamProvider.autoDispose.family<List<ModelHealthPoint>, DateTime>(
    (ref, end) => _tracked(ref, ref.watch(repositoryProvider).watchModelHealthHistory(end)));

final latestBatchProvider = StreamProvider.autoDispose<BatchLog?>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchLatestBatch()));

final datasetStatusProvider = StreamProvider.autoDispose<DatasetStatus?>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchDatasetStatus()));

final decisionsForProvider = StreamProvider.autoDispose.family<List<DecisionLog>, String>(
    (ref, predId) => _tracked(ref, ref.watch(repositoryProvider).watchDecisionsFor(predId)));

final recentDecisionsProvider = StreamProvider.autoDispose<List<DecisionLog>>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchRecentDecisions()));

final configHistoryProvider = StreamProvider.autoDispose<List<ConfigHistoryEntry>>(
    (ref) => _tracked(ref, ref.watch(repositoryProvider).watchConfigHistory()));

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return _tracked(ref, ref.watch(repositoryProvider).watchNotifications(user.role.id));
});

final readIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const {});
  return ref.watch(repositoryProvider).watchReadIds(user.uid);
});

/// Number of unread notifications (bell badge).
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  final read = ref.watch(readIdsProvider).valueOrNull ?? const {};
  return list.where((n) => !read.contains(n.id)).length;
});

/// Failed load attempts per screen key; after 3 the error state suggests
/// contacting IT Support.
final retryCountProvider = StateProvider.family<int, String>((ref, key) => 0);
