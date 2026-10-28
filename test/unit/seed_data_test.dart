import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/domain/calculators.dart';

import '../../firebase/seed/seed_data.dart';
import '../support/harness.dart';

Map<String, Object?> _doc(List<SeedDoc> docs, String path) => docs.firstWhere((d) => d.path == path).data;

void main() {
  test('normal scenario: H+1 matches the design example', () {
    final docs = buildSeed(today: testToday, uids: testUids);
    final h1 = _doc(docs, 'predictions/pred_WH-CKG-01_20261009');
    expect(h1['predicted'], 18420);
    expect(h1['projection'], 15900);
    expect(h1['deviation_pct'], 15.8);
    expect(h1['alert'], isTrue);
    expect(h1['actual_inbound'], isNull);
    final mp = h1['manpower'] as Map;
    expect([mp['rider'], mp['driver'], mp['op_inbound'], mp['op_outbound']], [37, 7, 37, 31]);
    expect(h1['data_status'], 'complete');
  });

  test('every seeded prediction stores manpower = formula(predicted)', () {
    final docs = buildSeed(today: testToday, uids: testUids);
    final preds = docs.where((d) => d.path.startsWith('predictions/'));
    expect(preds, hasLength(31));
    for (final d in preds) {
      final m = d.data['manpower'] as Map;
      final c = ManpowerCalculator.compute(d.data['predicted'] as int, CapacityConfig.defaults);
      expect([m['rider'], m['driver'], m['op_inbound'], m['op_outbound']], [c.rider, c.driver, c.opInbound, c.opOutbound]);
      final dev = DeviationCalculator.percent(d.data['predicted'] as int, d.data['projection'] as int);
      expect(d.data['alert'], DeviationCalculator.needsAttention(dev));
    }
  });

  test('normal scenario is healthy and rolling MAE matches the data', () {
    final docs = buildSeed(today: testToday, uids: testUids);
    final h = _doc(docs, 'model_health/WH-CKG-01');
    expect(h['status'], 'healthy');
    final errors = [
      for (var day = 2; day <= 8; day++)
        _doc(docs, 'predictions/pred_WH-CKG-01_202610${day.toString().padLeft(2, '0')}')['daily_error_pct'] as double,
    ];
    expect(h['rolling_mae_7d'] as double, closeTo(errors.reduce((a, b) => a + b) / 7, 0.02));
  });

  test('degraded scenario crosses the drift threshold', () {
    final docs = buildSeed(today: testToday, uids: testUids, scenario: SeedScenario.degraded);
    final h = _doc(docs, 'model_health/WH-CKG-01');
    expect(h['status'], 'degraded');
    expect(h['rolling_mae_7d'] as double, greaterThan(h['drift_threshold'] as double));
    expect(docs.any((d) => d.path == 'notifications/degraded_WH-CKG-01_20261008'), isTrue);
  });

  test('fallback scenario: today actual missing, H+1 uses H-2', () {
    final docs = buildSeed(today: testToday, uids: testUids, scenario: SeedScenario.fallback);
    expect(_doc(docs, 'predictions/pred_WH-CKG-01_20261008')['actual_inbound'], isNull);
    final h1 = _doc(docs, 'predictions/pred_WH-CKG-01_20261009');
    expect(h1['data_status'], 'incomplete_fallback_h2');
    expect(h1['source'], 'H-2');
    expect((h1['input_features'] as Map)['actual_inbound_h1'], isNull);
    expect(docs.any((d) => d.path.startsWith('notifications/incomplete_')), isTrue);
  });

  test('empty scenario has accounts and config only', () {
    final docs = buildSeed(today: testToday, uids: testUids, scenario: SeedScenario.empty);
    expect(docs.where((d) => d.path.startsWith('predictions/')), isEmpty);
    expect(docs.where((d) => d.path.startsWith('users/')), hasLength(4));
    expect(docs.any((d) => d.path == 'operational_configs/WH-CKG-01'), isTrue);
  });

  test('H+1 has no decision; adjusted decisions carry a reason', () {
    final docs = buildSeed(today: testToday, uids: testUids);
    final logs = docs.where((d) => d.path.startsWith('decision_logs/')).toList();
    expect(logs.where((d) => d.data['pred_id'] == 'pred_WH-CKG-01_20261009'), isEmpty);
    for (final d in logs.where((d) => d.data['decision'] == 'adjusted')) {
      expect((d.data['reason'] as String).isNotEmpty, isTrue);
    }
  });
}
