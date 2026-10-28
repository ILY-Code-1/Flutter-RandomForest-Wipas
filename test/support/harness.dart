import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wipas_app/app.dart';
import 'package:wipas_app/core/data/connectivity_service.dart';
import 'package:wipas_app/core/data/providers.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/router.dart';

import '../../firebase/seed/seed_data.dart';

/// "Now" used by every test: Thu 8 Oct 2026 20:00 WIB → H+1 = Fri 9 Oct.
final testNow = DateTime.utc(2026, 10, 8, 13);
final testToday = DateTime.utc(2026, 10, 8);

String uidFor(String key) => 'uid-$key';
final testUids = {for (final a in demoAccounts) a.key: uidFor(a.key)};

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity(this.online);
  final bool online;
  @override
  Stream<bool> watchOnline() => Stream.value(online);
}

Object? _toFirestore(Object? v) {
  if (v is DateTime) return Timestamp.fromDate(v);
  if (v is List) return v.map(_toFirestore).toList();
  if (v is Map) return v.map((k, val) => MapEntry(k as String, _toFirestore(val)));
  return v;
}

/// Writes the seed into a fake Firestore.
Future<FakeFirebaseFirestore> seededFirestore({SeedScenario scenario = SeedScenario.normal}) async {
  final db = FakeFirebaseFirestore();
  for (final d in buildSeed(today: testToday, uids: testUids, scenario: scenario)) {
    await db.doc(d.path).set(Map<String, dynamic>.from(_toFirestore(d.data) as Map));
  }
  return db;
}

bool _fontsLoaded = false;

/// Loads Inter + Material Icons so goldens show real glyphs.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  _fontsLoaded = true;
}

/// Running app under test.
class TestApp {
  TestApp(this.container, this.firestore);
  final ProviderContainer container;
  final FakeFirebaseFirestore firestore;

  GoRouter get router => container.read(routerProvider);
}

/// Pumps the full app signed in as [role] at [location] (360×800, reduced
/// motion). Extra provider [overrides] can force loading/error states.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Role? role = Role.admin,
  String location = '/beranda',
  SeedScenario scenario = SeedScenario.normal,
  bool online = true,
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
  FakeFirebaseFirestore? firestore,
  MockFirebaseAuth? auth,
  double textScale = 1.0,
  Size size = const Size(360, 800),
}) async {
  await loadFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });

  SharedPreferences.setMockInitialValues({
    // Fresh session started 1 hour before "now".
    if (role != null) 'session_started_ms': testNow.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();
  final db = firestore ?? await tester.runAsync(() => seededFirestore(scenario: scenario)) as FakeFirebaseFirestore;
  final account = role == null ? null : demoAccounts.firstWhere((a) => a.role == role.id);
  final mockAuth = auth ?? MockFirebaseAuth(
    signedIn: role != null,
    mockUser: account == null
        ? null
        : MockUser(uid: uidFor(account.key), email: account.email, displayName: account.displayName),
  );

  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(mockAuth),
    sharedPrefsProvider.overrideWithValue(sp),
    clockProvider.overrideWithValue(() => testNow),
    connectivityServiceProvider.overrideWithValue(FakeConnectivity(online)),
    ...overrides,
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const WipasApp()));
  await settle(tester);
  // Skip the splash wait.
  await tester.pump(const Duration(milliseconds: 1600));
  await settle(tester);
  if (location != '/beranda' || role == null) {
    container.read(routerProvider).go(location);
    await settle(tester);
  }
  return TestApp(container, db);
}

/// Pumps until streams/futures settle (bounded; skeletons are static under
/// reduced motion).
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Tall viewport so whole scrollable screens are built (presence checks).
const tall = Size(360, 5000);

/// A stream that never emits (forces the loading state).
Stream<T> neverStream<T>() => StreamController<T>().stream;
