// Main flow on a real device against the LOCAL Firebase Emulator:
// login as Manajer → approve the H+1 recommendation → decision is logged.
//
// Prerequisites (see docs/testing.md):
//   firebase emulators:start --only auth,firestore --project demo-wipas
//   dart run firebase/seed/seed.dart --scenario=normal
//   flutter test integration_test --dart-define=EMULATOR_HOST=10.0.2.2
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wipas_app/core/config/app_config.dart';
import 'package:wipas_app/main.dart' as app;

Future<void> _pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manajer approves the recommendation and the decision is logged', (tester) async {
    expect(AppConfig.useEmulator, isTrue, reason: 'Integration tests must run against the emulator only.');
    await app.main();

    await _pumpUntil(tester, find.byKey(const Key('login-email')));
    await tester.enterText(find.byKey(const Key('login-email')), 'manajer@wipas.example');
    await tester.enterText(find.byKey(const Key('login-password')), AppConfig.demoPassword);
    await tester.tap(find.byKey(const Key('login-submit')));

    await _pumpUntil(tester, find.text('Tinjau & Setujui Alokasi'));
    await tester.tap(find.text('Tinjau & Setujui Alokasi'));

    await _pumpUntil(tester, find.byKey(const Key('btn-setujui')));
    await tester.ensureVisible(find.byKey(const Key('btn-setujui')));
    await tester.tap(find.byKey(const Key('btn-setujui')));
    await _pumpUntil(tester, find.text('Setujui rekomendasi?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));

    await _pumpUntil(tester, find.text('Disetujui'));

    final latest = await FirebaseFirestore.instance
        .collection('predictions')
        .where('wh_id', isEqualTo: AppConfig.defaultWhId)
        .orderBy('target_date', descending: true)
        .limit(1)
        .get();
    final predId = latest.docs.single.id;
    final logs = await FirebaseFirestore.instance.collection('decision_logs').where('pred_id', isEqualTo: predId).get();
    expect(logs.docs, isNotEmpty);
    expect(logs.docs.first.data()['decision'], 'approved');
  });
}
