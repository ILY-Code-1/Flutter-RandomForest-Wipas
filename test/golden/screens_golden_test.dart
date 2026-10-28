// Golden tests at the 360×800 reference size. They replace on-device visual
// comparison when no Android emulator is available (see docs/HANDOFF.md).
// Regenerate with: flutter test --update-goldens test/golden
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/data/providers.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/features/prediksi/prediksi_screen.dart';

import '../../firebase/seed/seed_data.dart';
import '../support/harness.dart';

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  final cases = <(String, Role?, String, SeedScenario, bool)>[
    ('login', null, '/login', SeedScenario.normal, true),
    ('beranda_admin', Role.admin, '/beranda', SeedScenario.normal, true),
    ('beranda_manajer', Role.manajer, '/beranda', SeedScenario.normal, true),
    ('beranda_supervisor', Role.supervisor, '/beranda', SeedScenario.normal, true),
    ('beranda_viewer', Role.viewer, '/beranda', SeedScenario.normal, true),
    ('beranda_admin_offline', Role.admin, '/beranda', SeedScenario.normal, false),
    ('beranda_admin_kosong', Role.admin, '/beranda', SeedScenario.empty, true),
    ('prediksi_admin', Role.admin, '/prediksi', SeedScenario.normal, true),
    ('prediksi_viewer_fallback', Role.viewer, '/prediksi', SeedScenario.fallback, true),
    ('manpower_manajer', Role.manajer, '/manpower', SeedScenario.normal, true),
    ('manpower_supervisor', Role.supervisor, '/manpower', SeedScenario.normal, true),
    ('evaluasi_admin', Role.admin, '/evaluasi', SeedScenario.normal, true),
    ('evaluasi_manajer_degraded', Role.manajer, '/evaluasi', SeedScenario.degraded, true),
    ('input_actual_supervisor', Role.supervisor, '/input-actual', SeedScenario.fallback, true),
    ('konfigurasi_admin', Role.admin, '/konfigurasi', SeedScenario.normal, true),
    ('riwayat_admin', Role.admin, '/riwayat', SeedScenario.normal, true),
    ('notifikasi_admin', Role.admin, '/notifikasi', SeedScenario.normal, true),
    ('lainnya_admin', Role.admin, '/lainnya', SeedScenario.normal, true),
    ('profil_admin', Role.admin, '/profil', SeedScenario.normal, true),
  ];

  for (final c in cases) {
    testWidgets('golden ${c.$1}', (tester) async {
      await pumpApp(tester, role: c.$2, location: c.$3, scenario: c.$4, online: c.$5);
      await _golden(tester, c.$1);
    });
  }

  testWidgets('golden prediksi_manajer_grafik', (tester) async {
    await pumpApp(tester, role: Role.manajer, location: '/prediksi',
        overrides: [prediksiViewProvider.overrideWith((ref) => PrediksiView.grafik)]);
    await _golden(tester, 'prediksi_manajer_grafik');
  });

  testWidgets('golden beranda_admin_loading', (tester) async {
    await pumpApp(tester, overrides: [latestPredictionProvider.overrideWith((ref) => neverStream())]);
    await _golden(tester, 'beranda_admin_loading');
  });

  testWidgets('golden prediksi_admin_error', (tester) async {
    await pumpApp(tester, location: '/prediksi',
        overrides: [latestPredictionProvider.overrideWith((ref) => Stream.error(StateError('offline')))]);
    await _golden(tester, 'prediksi_admin_error');
  });
}
