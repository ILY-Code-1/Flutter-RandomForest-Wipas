// Five view states (loading, empty, error, offline, data) for the four core
// screens: Beranda, Prediksi, Manpower, Evaluasi.
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/data/providers.dart';
import 'package:wipas_app/core/widgets/widgets.dart';

import '../../firebase/seed/seed_data.dart';
import '../support/harness.dart';

const _screens = {
  '/beranda': ('Belum ada data batch', 'Tren inbound 14 hari'),
  '/prediksi': ('Belum ada prediksi', 'Riwayat prediksi'),
  '/manpower': ('Belum ada rekomendasi', 'Setujui rekomendasi'),
  '/evaluasi': ('Belum ada evaluasi model', 'Kesehatan model'),
};

void main() {
  _screens.forEach((path, texts) {
    group(path, () {
      testWidgets('loading shows skeleton', (tester) async {
        await pumpApp(tester, location: path, overrides: [latestPredictionProvider.overrideWith((ref) => neverStream())]);
        expect(find.byType(WipasSkeletonScreen), findsOneWidget);
        expect(find.text(texts.$2), findsNothing);
      });

      testWidgets('empty shows explanation', (tester) async {
        await pumpApp(tester, location: path, scenario: SeedScenario.empty);
        expect(find.text(texts.$1), findsOneWidget);
        expect(find.byType(WipasEmptyState), findsOneWidget);
      });

      testWidgets('error shows retry and IT Support after 3 failures', (tester) async {
        await pumpApp(tester,
            location: path,
            overrides: [latestPredictionProvider.overrideWith((ref) => Stream.error(StateError('server down')))]);
        expect(find.text(WipasErrorState.title), findsOneWidget);
        expect(find.text(WipasErrorState.itSupport), findsNothing);
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Coba lagi'));
          await settle(tester);
        }
        expect(find.text(WipasErrorState.title), findsOneWidget);
        expect(find.text(WipasErrorState.itSupport), findsOneWidget);
      });

      testWidgets('offline shows banner and cached data', (tester) async {
        await pumpApp(tester, location: path, online: false, size: tall);
        expect(find.text(WipasOfflineBanner.title), findsOneWidget);
        expect(find.textContaining('Terakhir disinkronkan'), findsOneWidget);
        expect(find.text(texts.$2), findsWidgets);
      });

      testWidgets('data renders', (tester) async {
        await pumpApp(tester, location: path, size: tall);
        expect(find.text(texts.$2), findsWidgets);
        expect(find.text(WipasOfflineBanner.title), findsNothing);
        expect(find.byType(WipasSkeletonScreen), findsNothing);
      });
    });
  });

  testWidgets('Prediksi H+2 without data shows empty state and "Kembali ke H+1"', (tester) async {
    await pumpApp(tester, location: '/prediksi');
    await tester.tap(find.text('H+2'));
    await settle(tester);
    expect(find.text('Belum ada prediksi untuk tanggal terpilih'), findsOneWidget);
    await tester.tap(find.text('Kembali ke H+1'));
    await settle(tester);
    expect(find.text('Target prediksi (H+1)'), findsOneWidget);
  });

  testWidgets('Beranda date strip switches the target date', (tester) async {
    await pumpApp(tester, size: tall);
    expect(find.textContaining('Jum, 9 Okt 2026 (H+1)'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Kam, 8 Okt 2026')));
    await settle(tester);
    expect(find.textContaining('Kam, 8 Okt 2026 (hari ini)'), findsWidgets);
    // 8 Okt has an actual → no deviation banner (6,2%).
    expect(find.text('Deviasi 15,8% melewati ambang 15%'), findsNothing);
  });

  testWidgets('Fallback H-2 shows the Data Incomplete warning', (tester) async {
    await pumpApp(tester, location: '/beranda', scenario: SeedScenario.fallback);
    expect(find.text('Fallback H-2 · Data Incomplete Warning'), findsOneWidget);
  });

  testWidgets('Model Degraded shows a danger banner on Beranda', (tester) async {
    await pumpApp(tester, scenario: SeedScenario.degraded, size: tall);
    expect(find.text('Model Degraded'), findsWidgets);
    expect(find.textContaining('melampaui ambang drift'), findsWidgets);
  });
}
