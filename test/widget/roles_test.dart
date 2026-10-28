// Per-role visibility: controls a role may not use are hidden, not disabled.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/core/widgets/widgets.dart';

import '../support/harness.dart';

Finder _tab(String label) => find.descendant(of: find.byType(WipasBottomNav), matching: find.text(label));

void main() {
  group('Bottom navigation', () {
    for (final r in [Role.admin, Role.manajer]) {
      testWidgets('${r.id} sees 5 tabs', (tester) async {
        await pumpApp(tester, role: r);
        for (final t in ['Beranda', 'Prediksi', 'Manpower', 'Evaluasi', 'Lainnya']) {
          expect(_tab(t), findsOneWidget, reason: '${r.id}: $t');
        }
      });
    }

    testWidgets('supervisor has no Evaluasi tab', (tester) async {
      await pumpApp(tester, role: Role.supervisor);
      expect(_tab('Evaluasi'), findsNothing);
      expect(_tab('Manpower'), findsOneWidget);
    });

    testWidgets('viewer has no Manpower tab', (tester) async {
      await pumpApp(tester, role: Role.viewer);
      expect(_tab('Manpower'), findsNothing);
      expect(_tab('Evaluasi'), findsOneWidget);
    });
  });

  group('Beranda per role', () {
    testWidgets('admin: Input Actual + Konfigurasi + Manpower card', (tester) async {
      await pumpApp(tester, size: tall);
      expect(find.text('Input Actual Inbound'), findsOneWidget);
      expect(find.text('Konfigurasi Kapasitas'), findsOneWidget);
      expect(find.text('Rekomendasi Manpower'), findsOneWidget);
      expect(find.text('Tinjau & Setujui Alokasi'), findsNothing);
      expect(find.text('Lihat Evaluasi'), findsWidgets);
    });

    testWidgets('manajer: approval card, no Input Actual', (tester) async {
      await pumpApp(tester, role: Role.manajer, size: tall);
      expect(find.text('Tinjau & Setujui Alokasi'), findsOneWidget);
      expect(find.text('Menunggu persetujuan'), findsOneWidget);
      expect(find.text('Input Actual Inbound'), findsNothing);
      expect(find.text('Konfigurasi Kapasitas'), findsNothing);
      expect(find.textContaining('Keputusan akhir ada di Anda'), findsOneWidget);
    });

    testWidgets('supervisor: Input Actual only, manpower read-only, no Evaluasi link', (tester) async {
      await pumpApp(tester, role: Role.supervisor, size: tall);
      expect(find.text('Input Actual Inbound'), findsOneWidget);
      expect(find.text('Konfigurasi Kapasitas'), findsNothing);
      expect(find.text('Tinjau & Setujui Alokasi'), findsNothing);
      expect(find.byType(WipasReadOnlyChip), findsOneWidget);
      expect(find.text('Lihat Evaluasi'), findsNothing);
    });

    testWidgets('viewer: read-only, no manpower card or links', (tester) async {
      await pumpApp(tester, role: Role.viewer, size: tall);
      expect(find.text('Dashboard tanpa akses ubah'), findsOneWidget);
      expect(find.text('Rekomendasi Manpower'), findsNothing);
      expect(find.text('Lihat detail'), findsNothing);
      expect(find.text('Input Actual Inbound'), findsNothing);
      expect(find.text('Evaluasi Projection'), findsOneWidget);
    });
  });

  for (final r in Role.values) {
    testWidgets('Prediksi (${r.id}): read-only, Faktor pendorong hidden for supervisor only', (tester) async {
      await pumpApp(tester, role: r, location: '/prediksi', size: tall);
      expect(find.byType(WipasReadOnlyChip), findsWidgets);
      expect(find.text('Faktor pendorong'), r == Role.supervisor ? findsNothing : findsOneWidget, reason: r.id);
    });
  }

  testWidgets('Manpower: supervisor read-only without actions', (tester) async {
    await pumpApp(tester, role: Role.supervisor, location: '/manpower', size: tall);
    expect(find.text('Setujui rekomendasi'), findsNothing);
    expect(find.text('Sesuaikan manual'), findsNothing);
    expect(find.text('Cara hitung'), findsNWidgets(4));
    expect(find.byType(WipasReadOnlyChip), findsOneWidget);
  });

  for (final r in [Role.admin, Role.manajer]) {
    testWidgets('Manpower: ${r.id} can act', (tester) async {
      await pumpApp(tester, role: r, location: '/manpower', size: tall);
      expect(find.text('Setujui rekomendasi'), findsOneWidget);
      expect(find.text('Sesuaikan manual'), findsOneWidget);
    });
  }

  group('Route guard', () {
    final denied = <Role, List<String>>{
      Role.viewer: ['/manpower', '/input-actual', '/konfigurasi'],
      Role.supervisor: ['/evaluasi', '/konfigurasi'],
      Role.manajer: ['/input-actual'],
    };
    denied.forEach((role, paths) {
      for (final path in paths) {
        testWidgets('${role.id} cannot open $path', (tester) async {
          final app = await pumpApp(tester, role: role, location: path);
          expect(app.router.routerDelegate.currentConfiguration.uri.path, '/beranda');
        });
      }
    });
  });

  group('Riwayat', () {
    testWidgets('admin: export + decisions', (tester) async {
      await pumpApp(tester, location: '/riwayat', size: tall);
      expect(find.text('Riwayat & Export'), findsOneWidget);
      expect(find.text('Export CSV'), findsWidgets);
      expect(find.text('Disetujui'), findsWidgets);
      expect(find.text('Menunggu keputusan'), findsOneWidget);
    });

    for (final r in [Role.manajer, Role.supervisor]) {
      testWidgets('${r.id}: decisions without export', (tester) async {
        await pumpApp(tester, role: r, location: '/riwayat', size: tall);
        expect(find.text('Export CSV'), findsNothing, reason: r.id);
        expect(find.text('Disetujui'), findsWidgets, reason: r.id);
      });
    }

    testWidgets('viewer: no export and no decision column', (tester) async {
      await pumpApp(tester, role: Role.viewer, location: '/riwayat', size: tall);
      expect(find.text('Export CSV'), findsNothing);
      expect(find.text('Disetujui'), findsNothing);
      expect(find.text('Menunggu keputusan'), findsNothing);
      expect(find.text('Prediksi & actual'), findsOneWidget);
      expect(find.textContaining('Perlu Perhatian'), findsWidgets);
    });

    testWidgets('14 hari filter extends the list', (tester) async {
      await pumpApp(tester, location: '/riwayat', size: tall);
      expect(find.text('3 Okt – 9 Okt 2026'), findsOneWidget);
      await tester.tap(find.text('14 hari'));
      await settle(tester);
      expect(find.text('26 Sep – 9 Okt 2026'), findsOneWidget);
    });
  });

  for (final r in Role.values) {
    testWidgets('Lainnya menu for ${r.id}', (tester) async {
      await pumpApp(tester, role: r, location: '/lainnya');
      final canConfig = r == Role.admin || r == Role.manajer;
      expect(find.text('Konfigurasi kapasitas'), canConfig ? findsOneWidget : findsNothing, reason: r.id);
      expect(find.text(r == Role.admin ? 'Riwayat & export' : 'Riwayat'), findsOneWidget, reason: r.id);
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Profil & pengaturan'), findsOneWidget);
    });
  }

  testWidgets('Notifikasi for supervisor excludes batch notifications (audience_roles)', (tester) async {
    await pumpApp(tester, role: Role.supervisor, location: '/notifikasi');
    expect(find.text('Batch prediksi selesai'), findsNothing);
    expect(find.text('Deviasi prediksi >15%'), findsWidgets);
  });

  testWidgets('Notifikasi for admin includes batch notifications', (tester) async {
    await pumpApp(tester, role: Role.admin, location: '/notifikasi');
    expect(find.text('Batch prediksi selesai'), findsOneWidget);
  });

  testWidgets('Evaluasi viewer is read-only', (tester) async {
    await pumpApp(tester, role: Role.viewer, location: '/evaluasi');
    expect(find.byType(WipasReadOnlyChip), findsOneWidget);
    expect(find.text('Kesehatan model'), findsOneWidget);
  });

  testWidgets('Text scale 130% renders Beranda without overflow', (tester) async {
    await pumpApp(tester, textScale: 1.3, size: const Size(360, 3000));
    expect(tester.takeException(), isNull);
    expect(find.text('Tren inbound 14 hari'), findsOneWidget);
  });
}
