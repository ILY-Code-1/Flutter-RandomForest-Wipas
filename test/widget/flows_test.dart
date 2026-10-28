// Write flows and auth flows against the fake Firestore.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/core/widgets/widgets.dart';
import 'package:wipas_app/features/auth/auth_controller.dart';
import 'package:wipas_app/features/manpower/manpower_screen.dart';
import 'package:wipas_app/features/riwayat/csv_export.dart';
import 'package:wipas_app/features/riwayat/riwayat_screen.dart';

import '../../firebase/seed/seed_data.dart';
import '../support/harness.dart';

const _h1 = 'pred_WH-CKG-01_20261009';

class _FakeSaver extends CsvSaver {
  _FakeSaver({this.fail = false});
  final bool fail;
  String? content;
  String? name;

  @override
  Future<File> write(String name, String content) async {
    if (fail) throw const FileSystemException('disk full');
    this.name = name;
    this.content = content;
    return File(name);
  }

  @override
  Future<void> share(File file) async {}
}

/// Auth mock that rejects every password sign-in.
class _RejectingAuth extends MockFirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) =>
      Future.error(FirebaseAuthException(code: 'invalid-credential'));
}

Finder _field(String key) => find.byKey(Key(key));

void main() {
  group('Manpower decisions', () {
    testWidgets('manajer approves → decision_logs entry + status Disetujui', (tester) async {
      final app = await pumpApp(tester, role: Role.manajer, location: '/manpower', size: tall);
      await tester.tap(find.byKey(const Key('btn-setujui')));
      await settle(tester);
      expect(find.text('Setujui rekomendasi?'), findsOneWidget);
      expect(find.textContaining('Rider 37, Driver 7, Op. Inbound 37, dan Op. Outbound 31'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await settle(tester);

      final logs = await app.firestore.collection('decision_logs').where('pred_id', isEqualTo: _h1).get();
      expect(logs.docs, hasLength(1));
      final d = logs.docs.single.data();
      expect(d['decision'], 'approved');
      expect(d['decided_by'], uidFor('manajer'));
      expect(d['manpower_final'], {'rider': 37, 'driver': 7, 'op_inbound': 37, 'op_outbound': 31});
      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.byKey(const Key('btn-setujui')), findsNothing);
    });

    testWidgets('cancel keeps the recommendation pending', (tester) async {
      final app = await pumpApp(tester, role: Role.manajer, location: '/manpower', size: tall);
      await tester.tap(find.byKey(const Key('btn-setujui')));
      await settle(tester);
      await tester.tap(find.text('Batal'));
      await settle(tester);
      final logs = await app.firestore.collection('decision_logs').where('pred_id', isEqualTo: _h1).get();
      expect(logs.docs, isEmpty);
    });

    testWidgets('manual adjustment requires a reason', (tester) async {
      final app = await pumpApp(tester, role: Role.manajer, location: '/manpower', size: tall);
      await tester.tap(find.byKey(const Key('btn-sesuaikan')));
      await settle(tester);
      expect(find.text('Sesuaikan manual'), findsWidgets);
      await tester.tap(find.byKey(const Key('btn-simpan-penyesuaian')));
      await settle(tester);
      expect(find.text(AdjustSheet.reasonRequired), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add).first); // first stepper = Rider
        await tester.pump();
      }
      expect(find.text('Rekomendasi 37 (+3)'), findsOneWidget);
      await tester.enterText(_field('adjust-reason'), 'Antrean backlog 640 paket perlu tambahan kurir');
      await tester.tap(find.byKey(const Key('btn-simpan-penyesuaian')));
      await settle(tester);

      final logs = await app.firestore.collection('decision_logs').where('pred_id', isEqualTo: _h1).get();
      expect(logs.docs, hasLength(1));
      final d = logs.docs.single.data();
      expect(d['decision'], 'adjusted');
      expect(d['reason'], 'Antrean backlog 640 paket perlu tambahan kurir');
      expect((d['manpower_final'] as Map)['rider'], 40);
      expect(find.text('Disesuaikan manual'), findsOneWidget);
      expect(find.textContaining('Rider 40 (rekomendasi 37)'), findsOneWidget);
    });

    testWidgets('offline disables actions with a hint (buttons stay visible)', (tester) async {
      await pumpApp(tester, role: Role.manajer, location: '/manpower', online: false, size: tall);
      expect(find.text(offlineActionHint), findsNWidgets(2));
      final btn = tester.widget<FilledButton>(
          find.descendant(of: find.byKey(const Key('btn-setujui')), matching: find.byType(FilledButton)));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Cara hitung sheet shows the substituted formula', (tester) async {
      await pumpApp(tester, role: Role.supervisor, location: '/manpower', size: tall);
      await tester.tap(find.text('Cara hitung').first);
      await settle(tester);
      expect(find.text('Cara hitung · Rider'), findsOneWidget);
      expect(find.text('(18.420 × 0,70) ÷ 350'), findsOneWidget);
      expect(find.text('12.894 ÷ 350 = 36,84'), findsOneWidget);
      expect(find.text('Dibulatkan ke atas: 37 orang'), findsOneWidget);
    });
  });

  group('Input Actual', () {
    testWidgets('supervisor reminder, validation and save', (tester) async {
      final app = await pumpApp(tester, role: Role.supervisor, location: '/input-actual', scenario: SeedScenario.fallback, size: tall);
      expect(find.text('Actual hari ini belum diinput'), findsOneWidget);
      expect(find.textContaining('Kam, 8 Okt 2026 (hari ini)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-simpan-actual')));
      await settle(tester);
      expect(find.text('Actual inbound wajib diisi.'), findsOneWidget);

      await tester.enterText(_field('actual-field'), '-500');
      await tester.pump();
      expect(find.text('Nilai tidak boleh negatif.'), findsOneWidget);

      await tester.enterText(_field('actual-field'), '17.560');
      await tester.pump();
      expect(find.text('Perbandingan dengan prediksi'), findsOneWidget);
      expect(find.text('+360 paket (+2,1%)'), findsOneWidget);
      expect(find.text('Dampak ke Rolling MAE 7 hari'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-simpan-actual')));
      await settle(tester);
      final doc = await app.firestore.doc('predictions/pred_WH-CKG-01_20261008').get();
      expect(doc.data()!['actual_inbound'], 17560);
      expect(doc.data()!['actual_input_by'], uidFor('supervisor'));
      expect(find.textContaining('tersimpan: 17.560 paket'), findsOneWidget);
    });

    testWidgets('offline disables Simpan', (tester) async {
      await pumpApp(tester, role: Role.admin, location: '/input-actual', online: false, size: tall);
      expect(find.text(offlineActionHint), findsOneWidget);
    });
  });

  group('Konfigurasi', () {
    testWidgets('ratio error disables save; valid change saves config + history', (tester) async {
      final app = await pumpApp(tester, role: Role.manajer, location: '/konfigurasi', size: tall);
      expect(find.text('Belum ada perubahan untuk disimpan.'), findsOneWidget);

      await tester.enterText(_field('cfg-ratio_rider'), '0,75');
      await tester.pump();
      expect(find.text('Ratio_Rider + Ratio_Driver harus = 1,00 (saat ini 1,05).'), findsOneWidget);
      expect(find.text('Perbaiki nilai yang belum valid untuk melihat pratinjau.'), findsOneWidget);

      await tester.enterText(_field('cfg-ratio_rider'), '0,70');
      await tester.enterText(_field('cfg-capacity_rider'), '400');
      await tester.enterText(_field('cfg-capacity_op_outbound'), '650');
      await tester.pump();
      expect(find.text('saat ini 37 (−4)'), findsOneWidget);
      expect(find.text('saat ini 31 (−2)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-simpan-config')));
      await settle(tester);
      expect(find.text('Simpan konfigurasi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await settle(tester);

      final cfg = await app.firestore.doc('operational_configs/WH-CKG-01').get();
      expect(cfg.data()!['capacity_rider'], 400);
      expect(cfg.data()!['capacity_op_outbound'], 650);
      expect(cfg.data()!['updated_by'], uidFor('manajer'));
      final hist = await app.firestore.collection('config_history').get();
      expect(hist.docs, hasLength(4));
      expect(find.text('Capacity_Rider: 350 → 400'), findsOneWidget);
    });

    testWidgets('capacity 0 shows a field error', (tester) async {
      await pumpApp(tester, role: Role.admin, location: '/konfigurasi', size: tall);
      await tester.enterText(_field('cfg-capacity_driver'), '0');
      await tester.pump();
      expect(find.text('Nilai harus lebih dari 0.'), findsOneWidget);
    });
  });

  group('Notifikasi', () {
    testWidgets('filter and mark all read', (tester) async {
      final app = await pumpApp(tester, location: '/notifikasi');
      expect(find.text('2 belum dibaca · 4 total'), findsOneWidget);
      final chipBar = find.descendant(of: find.byType(WipasFilterChipBar), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.widgetWithText(WipasFilterChip, 'Batch'), 120, scrollable: chipBar);
      await tester.tap(find.widgetWithText(WipasFilterChip, 'Batch'));
      await settle(tester);
      expect(find.text('Batch prediksi selesai'), findsOneWidget);
      expect(find.text('Deviasi prediksi >15%'), findsNothing);
      await tester.scrollUntilVisible(find.widgetWithText(WipasFilterChip, 'Semua'), -120, scrollable: chipBar);
      await tester.tap(find.widgetWithText(WipasFilterChip, 'Semua'));
      await settle(tester);
      await tester.tap(find.text('Tandai semua dibaca'));
      await settle(tester);
      final reads = await app.firestore.collection('users/${uidFor('admin')}/notification_reads').get();
      expect(reads.docs, hasLength(4));
      expect(find.text('0 belum dibaca · 4 total'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await pumpApp(tester, location: '/notifikasi', scenario: SeedScenario.empty);
      expect(find.text('Belum ada notifikasi'), findsOneWidget);
    });
  });

  group('Export CSV (admin)', () {
    testWidgets('success state with BOM file', (tester) async {
      final saver = _FakeSaver();
      await pumpApp(tester, location: '/riwayat', size: tall, overrides: [csvSaverProvider.overrideWithValue(saver)]);
      await tester.tap(find.byKey(const Key('btn-export')));
      await settle(tester);
      expect(find.text('File siap diunduh'), findsOneWidget);
      expect(find.text('Export lagi'), findsOneWidget);
      expect(saver.name, 'riwayat_wipas_2026-10-03_2026-10-09.csv');
      expect(saver.content!.startsWith('﻿${CsvExport.header.join(',')}'), isTrue);
      expect('\r\n'.allMatches(saver.content!).length, 8);
    });

    testWidgets('failure state offers retry', (tester) async {
      await pumpApp(tester,
          location: '/riwayat', size: tall, overrides: [csvSaverProvider.overrideWithValue(_FakeSaver(fail: true))]);
      await tester.tap(find.byKey(const Key('btn-export')));
      await settle(tester);
      expect(find.text('Export gagal'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('Auth', () {
    testWidgets('wrong credentials show the design error', (tester) async {
      final auth = _RejectingAuth();
      await pumpApp(tester, role: null, location: '/login', auth: auth);
      await tester.enterText(find.byKey(const Key('login-email')), 'rina.putri@perusahaan.id');
      await tester.enterText(find.byKey(const Key('login-password')), 'salah');
      await tester.tap(find.byKey(const Key('login-submit')));
      await settle(tester);
      expect(find.text(AuthMessages.wrongCredentials), findsOneWidget);
    });

    testWidgets('valid credentials via the form open Beranda for the role', (tester) async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: uidFor('supervisor'), email: 'supervisor@wipas.example', displayName: 'Rina Putri'),
      );
      await pumpApp(tester, role: null, location: '/login', auth: auth);
      await tester.enterText(find.byKey(const Key('login-email')), 'supervisor@wipas.example');
      await tester.enterText(find.byKey(const Key('login-password')), demoPassword);
      await tester.tap(find.byKey(const Key('login-submit')));
      await settle(tester);
      expect(find.text('Hub Cakung (WH-CKG-01)'), findsOneWidget);
      expect(find.text('Supervisor Operasional'), findsOneWidget);
    });

    testWidgets('account without a valid role is rejected with a message', (tester) async {
      final db = await tester.runAsync(() => seededFirestore()) as dynamic;
      await tester.runAsync(() => db.doc('users/${uidFor('viewer')}').update({'role': 'superuser'}));
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: uidFor('viewer'), email: 'viewer@wipas.example'),
      );
      await pumpApp(tester, role: null, location: '/login', auth: auth, firestore: db);
      await tester.enterText(find.byKey(const Key('login-email')), 'viewer@wipas.example');
      await tester.enterText(find.byKey(const Key('login-password')), demoPassword);
      await tester.tap(find.byKey(const Key('login-submit')));
      await settle(tester);
      expect(find.text(AuthMessages.noRole), findsOneWidget);
      expect(find.text('Hub Cakung (WH-CKG-01)'), findsNothing);
    });

    testWidgets('session older than 24 hours ends with the Sesi berakhir banner', (tester) async {
      await pumpApp(tester, prefs: {
        'session_started_ms': testNow.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
      });
      expect(find.text('Sesi berakhir'), findsOneWidget);
      expect(find.text('Masuk'), findsWidgets);
    });

    testWidgets('logout via Profil dialog returns to Login', (tester) async {
      await pumpApp(tester, location: '/profil', size: tall);
      await tester.tap(find.widgetWithText(WipasDestructiveButton, 'Keluar'));
      await settle(tester);
      expect(find.text('Keluar dari WIPAS?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Keluar')));
      await settle(tester);
      expect(find.text('Gunakan akun WIPAS dari administrator.'), findsOneWidget);
    });

    testWidgets('forgot password shows confirmation', (tester) async {
      await pumpApp(tester, role: null, location: '/login/lupa');
      await tester.enterText(find.byType(TextField), 'bukan-email');
      await tester.tap(find.text('Kirim tautan reset'));
      await settle(tester);
      expect(find.textContaining('Masukkan email yang valid'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rina.putri@perusahaan.id');
      await tester.tap(find.text('Kirim tautan reset'));
      await settle(tester);
      expect(find.text('Tautan reset telah dikirim ke email'), findsOneWidget);
    });
  });
}
