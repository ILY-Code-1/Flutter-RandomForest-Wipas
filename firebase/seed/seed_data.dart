// Deterministic demo dataset for the Firebase Emulator (project demo-wipas).
//
// Pure Dart (no Flutter imports) so it can be used both by
// `firebase/seed/seed.dart` (writes to the emulator over REST) and by the
// widget tests (writes to FakeFirebaseFirestore).
//
// All numbers are SYNTHETIC demo values that mirror the design scenario
// (Predicted 18.420 vs Projection 15.900 → +15,8%). They are NOT model
// results. Metrics that depend on the data (daily error, rolling MAE) are
// computed from the seeded values so the dataset is internally consistent.

import 'package:wipas_app/core/domain/calculators.dart';

/// Seed scenarios.
enum SeedScenario {
  /// Healthy model, H+1 complete, deviation 15,8% on H+1.
  normal,

  /// Rolling MAE above the drift threshold (Model Degraded).
  degraded,

  /// Today's actual missing → H+1 uses fallback H-2 (Data Incomplete).
  fallback,

  /// Only users, warehouse and default config (empty states).
  empty,
}

/// One document to write: slash-separated path + data. Timestamps are
/// [DateTime] values in UTC.
class SeedDoc {
  const SeedDoc(this.path, this.data);
  final String path;
  final Map<String, Object?> data;
}

/// Demo account definition.
class DemoAccount {
  const DemoAccount(this.key, this.email, this.role, this.displayName, this.jobTitle);
  final String key;
  final String email;
  final String role;
  final String displayName;
  final String? jobTitle;
}

const demoPassword = 'wipas-demo-123';
const whId = 'WH-CKG-01';

const demoAccounts = [
  DemoAccount('admin', 'admin.shift@wipas.example', 'admin', 'Admin WIPAS · Shift Lead', null),
  DemoAccount('manajer', 'manajer@wipas.example', 'manajer', 'Budi Santoso', 'Manajer Warehouse'),
  DemoAccount('supervisor', 'supervisor@wipas.example', 'supervisor', 'Rina Putri', 'Supervisor Operasional'),
  DemoAccount('viewer', 'viewer@wipas.example', 'viewer', 'Dewi Lestari', 'Viewer · Tim DI'),
];

const featureImportance = {
  'actual_inbound_h1': 0.27,
  'pickup_request_h1': 0.21,
  'backlog_h1': 0.12,
  'actual_inbound_h2': 0.09,
  'projection_inbound': 0.08,
  'is_campaign': 0.07,
  'is_payday': 0.06,
  'is_holiday': 0.04,
  'day_of_week': 0.03,
  'month': 0.03,
};

/// Design scenario rows, keyed by offset from H+1: (projection, predicted, actual).
const _designRows = <int, (int, int, int?)>{
  0: (15900, 18420, null),
  -1: (16200, 17200, 17560),
  -2: (16100, 16900, 16980),
  -3: (15400, 16000, 16200),
  -4: (15700, 16300, 16600),
  -5: (12100, 14200, 13900),
  -6: (15100, 15800, 15500),
  -7: (16500, 17000, 16800),
};

String _two(int v) => v.toString().padLeft(2, '0');
String iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String key(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

/// WIB wall-clock time on calendar date [d] → UTC instant.
DateTime wib(DateTime d, int hour, int minute, [int second = 0]) =>
    DateTime.utc(d.year, d.month, d.day, hour, minute, second).subtract(const Duration(hours: 7));

/// Small deterministic PRNG (LCG) so the seed is reproducible.
class _Rng {
  _Rng(this._s);
  int _s;
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  int range(int lo, int hi) => lo + (next() * (hi - lo + 1)).floor();
}

double _round1(double v) => (v * 10).roundToDouble() / 10;
double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Builds all documents. [today] is the WIB calendar date (UTC midnight);
/// [uids] maps account key → Firebase uid.
List<SeedDoc> buildSeed({
  required DateTime today,
  required Map<String, String> uids,
  SeedScenario scenario = SeedScenario.normal,
}) {
  final docs = <SeedDoc>[];
  final h1 = today.add(const Duration(days: 1));

  // --- users & warehouse & config (all scenarios)
  for (final a in demoAccounts) {
    final uid = uids[a.key]!;
    docs.add(SeedDoc('users/$uid', {
      'display_name': a.displayName,
      'email': a.email,
      'role': a.role,
      'wh_id': whId,
      'job_title': a.jobTitle,
    }));
  }
  docs.add(const SeedDoc('warehouses/$whId', {'name': 'Hub Cakung', 'city': 'Jakarta Timur'}));
  final cfg = CapacityConfig.defaults;
  docs.add(SeedDoc('operational_configs/$whId', {
    ...cfg.toMap(),
    'rounding': 'ceil',
    'updated_by': uids['manajer'],
    'updated_at': wib(today.subtract(const Duration(days: 6)), 14, 10),
  }));

  final adminName = demoAccounts[0].displayName;
  final manajerName = demoAccounts[1].displayName;
  final history = [
    (today.subtract(const Duration(days: 6)), 14, 10, 'manajer', manajerName,
        {'capacity_op_outbound': 580}, {'capacity_op_outbound': 600}),
    (today.subtract(const Duration(days: 17)), 9, 30, 'admin', adminName,
        {'ratio_rider': 0.65, 'ratio_driver': 0.35}, {'ratio_rider': 0.70, 'ratio_driver': 0.30}),
    (today.subtract(const Duration(days: 37)), 8, 5, 'admin', adminName,
        {'capacity_rider': 330}, {'capacity_rider': 350}),
  ];
  for (var i = 0; i < history.length; i++) {
    final h = history[i];
    final before = {...cfg.toMap(), ...h.$6};
    // Old values for the fields changed afterwards reflect the time of change.
    docs.add(SeedDoc('config_history/seed_${i + 1}', {
      'wh_id': whId,
      'changed_by': uids[h.$4],
      'changed_by_name': h.$5,
      'changed_at': wib(h.$1, h.$2, h.$3),
      'old_values': before,
      'new_values': {...before, ...h.$7},
    }));
  }

  if (scenario == SeedScenario.empty) return docs;

  // --- predictions & daily data for H+1 and the 30 days before it
  final rng = _Rng(20261008);
  const days = 31;
  final proj = <DateTime, int>{};
  final pred = <DateTime, int>{};
  final actual = <DateTime, int?>{};
  for (var off = -(days - 1); off <= 0; off++) {
    final d = h1.add(Duration(days: off));
    final design = _designRows[off];
    if (design != null) {
      proj[d] = design.$1;
      pred[d] = design.$2;
      actual[d] = design.$3;
    } else {
      // Weekly pattern: lower on Sunday, higher mid-week.
      final base = 15800 + (d.weekday == DateTime.sunday ? -2600 : (d.weekday <= 3 ? 600 : 0));
      final a = base + rng.range(-900, 900);
      actual[d] = a;
      proj[d] = (a * (0.9 + rng.next() * 0.12)).round();
      pred[d] = (a * (0.95 + rng.next() * 0.1)).round();
    }
  }

  if (scenario == SeedScenario.fallback) actual[today] = null;
  if (scenario == SeedScenario.degraded) {
    // Last 6 evaluated days drift away from the predictions (~9–11% error).
    for (var off = -6; off <= -1; off++) {
      final d = h1.add(Duration(days: off));
      final f = 1 + (0.09 + (off.abs() % 3) * 0.01) * (off.isEven ? 1 : -1);
      actual[d] = (pred[d]! * f).round();
    }
  }

  final errors = <DateTime, double>{};
  for (var off = -(days - 1); off <= 0; off++) {
    final d = h1.add(Duration(days: off));
    final a = actual[d];
    final dPrev = d.subtract(const Duration(days: 1));
    final dPrev2 = d.subtract(const Duration(days: 2));
    final isTarget = d == h1;
    final fallback = isTarget && scenario == SeedScenario.fallback;
    final dev = (pred[d]! - proj[d]!) / proj[d]! * 100;
    final counts = ManpowerCalculator.compute(pred[d]!, cfg);
    final err = ErrorMetrics.dailyErrorPct(pred[d], a);
    if (err != null) errors[d] = err;
    final features = {
      'day_of_week': d.weekday,
      'month': d.month,
      'is_campaign': d.day == 10 || d.day == 11,
      'is_holiday': false,
      'is_payday': d.day >= 25 || d.day == 1 || isTarget,
      'pickup_request_h1': fallback ? null : (isTarget ? 21300 : ((actual[dPrev] ?? 15000) * 1.21).round()),
      'projection_inbound': proj[d],
      'backlog_h1': fallback ? null : (isTarget ? 640 : 300 + rng.range(0, 600)),
      'actual_inbound_h2': actual[dPrev2] ?? (pred[dPrev2] ?? 15000),
      'actual_inbound_h1': fallback ? null : (actual[dPrev] ?? pred[dPrev]),
    };
    docs.add(SeedDoc('predictions/pred_${whId}_${key(d)}', {
      'wh_id': whId,
      'target_date': iso(d),
      'predicted': pred[d],
      'projection': proj[d],
      'deviation_pct': _round1(dev),
      'alert': DeviationCalculator.needsAttention(dev),
      'status': DeviationCalculator.needsAttention(dev) ? 'perlu_perhatian' : 'normal',
      'data_status': fallback ? 'incomplete_fallback_h2' : 'complete',
      'source': fallback ? 'H-2' : 'H-1',
      'model_version': 'v1.0',
      'generated_at': wib(dPrev, 23, 0, 41),
      'input_features': features,
      'feature_importance': featureImportance,
      'manpower': {...counts.toMap(), 'config_snapshot': cfg.toMap()},
      'is_backfill': off < -13,
      'actual_inbound': a,
      'actual_note': null,
      'actual_input_by': a == null ? null : uids[off.isEven ? 'supervisor' : 'admin'],
      'actual_input_at': a == null ? null : wib(d, 21, 15),
      'daily_error_pct': err == null ? null : _round2(err),
      'evaluated': err != null,
    }));
    docs.add(SeedDoc('daily_data/${whId}_${key(d)}', {
      'wh_id': whId,
      'date': iso(d),
      ...features,
      'actual_inbound': a,
      'source_file': 'inbound_hub_cakung.xlsx',
    }));
  }

  // --- model health (rolling MAE computed from the seeded errors)
  const baseline = 6.2;
  final threshold = _round2(ErrorMetrics.driftThreshold(baseline));
  double? rollingAt(DateTime end) {
    final window = [
      for (var i = 6; i >= 0; i--)
        if (errors[end.subtract(Duration(days: i))] != null) errors[end.subtract(Duration(days: i))]!,
    ];
    return ErrorMetrics.rollingMae(window);
  }

  final lastEvaluated = actual[today] != null ? today : today.subtract(const Duration(days: 1));
  final rolling = _round2(rollingAt(lastEvaluated)!);
  final degraded = rolling > threshold;
  docs.add(SeedDoc('model_health/$whId', {
    'status': degraded ? 'degraded' : 'healthy',
    'rolling_mae_7d': rolling,
    'baseline_mae': baseline,
    'drift_threshold': threshold,
    'model_version': 'v1.0',
    'mae_validation': 6.8,
    'rmse': 9.4,
    'r2': 0.89,
    'feature_importance': featureImportance,
    'updated_at': wib(today, 23, 2),
  }));
  for (var i = 29; i >= 0; i--) {
    final d = lastEvaluated.subtract(Duration(days: i));
    final r = rollingAt(d);
    if (r == null) continue;
    docs.add(SeedDoc('model_health_history/${whId}_${key(d)}', {
      'wh_id': whId,
      'date': iso(d),
      'rolling_mae_7d': _round2(r),
      'baseline_mae': baseline,
      'drift_threshold': threshold,
      'status': r > threshold ? 'degraded' : 'healthy',
    }));
  }

  // --- batch logs (one run per evening) and dataset status
  for (var i = 29; i >= 0; i--) {
    final run = today.subtract(Duration(days: i));
    final retry = i == 7 ? 1 : 0;
    docs.add(SeedDoc('batch_logs/${whId}_${key(run)}', {
      'wh_id': whId,
      'run_date': iso(run),
      'target_date': iso(run.add(const Duration(days: 1))),
      'started_at': wib(run, 23, 0),
      'finished_at': wib(run, 23, 2, 14 + retry * 420),
      'duration_sec': 134 + retry * 420,
      'status': 'success',
      'retry_count': retry,
      'source': (i == 0 && scenario == SeedScenario.fallback) ? 'H-2' : 'H-1',
      'message': retry > 0 ? 'Gagal sekali (timeout), berhasil pada retry ke-1.' : null,
    }));
  }
  final rangeStart = DateTime.utc(2025, 1, 1);
  docs.add(SeedDoc('dataset_status/$whId', {
    'wh_id': whId,
    'last_import_at': wib(today, 22, 30),
    'range_start': iso(rangeStart),
    'range_end': iso(actual[today] == null ? today.subtract(const Duration(days: 1)) : today),
    'row_count': today.difference(rangeStart).inDays + (actual[today] == null ? 0 : 1),
    'source_file': 'inbound_hub_cakung.xlsx',
  }));

  // --- decisions for the 8 days before H+1 (H+1 stays "Menunggu")
  for (var off = -8; off <= -1; off++) {
    final d = h1.add(Duration(days: off));
    final rec = ManpowerCalculator.compute(pred[d]!, cfg);
    final adjusted = off == -3 || off == -5;
    final finalCounts = off == -3
        ? rec.copyWith(rider: rec.rider + 2)
        : (off == -5 ? rec.copyWith(opInbound: rec.opInbound + 2) : rec);
    docs.add(SeedDoc('decision_logs/seed_${key(d)}', {
      'pred_id': 'pred_${whId}_${key(d)}',
      'wh_id': whId,
      'decided_by': uids['manajer'],
      'decided_by_name': manajerName,
      'decision': adjusted ? 'adjusted' : 'approved',
      'manpower_final': finalCounts.toMap(),
      'reason': off == -3 ? 'tambahan rute padat' : (off == -5 ? 'antrean bongkar muat' : null),
      'decided_at': wib(d, 6, 40),
    }));
  }

  // --- notifications
  String day(DateTime d) => const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][d.weekday - 1];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  String dm(DateTime d) => '${day(d)}, ${d.day} ${months[d.month - 1]}';
  String n(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  String pct(double v) => '${v >= 0 ? '+' : '−'}${_round1(v.abs()).toStringAsFixed(1).replaceAll('.', ',')}%';

  final notifs = <(String, DateTime, DateTime, String, String, List<String>, bool)>[];
  final devH1 = (pred[h1]! - proj[h1]!) / proj[h1]! * 100;
  notifs.add(('deviation', h1, wib(today, 23, 2), 'Deviasi prediksi >15%',
      'Prediksi ${dm(h1)}: Predicted ${n(pred[h1]!)} vs Projection ${n(proj[h1]!)} (${pct(devH1)}). Perlu ditinjau.',
      ['admin', 'manajer', 'supervisor', 'viewer'], false));
  notifs.add(('batch', h1, wib(today, 23, 2), 'Batch prediksi selesai',
      'Batch ${dm(today)} 23:00 WIB berhasil dalam 2 mnt 14 dtk. Sumber data ${scenario == SeedScenario.fallback ? 'H-2' : 'H-1'}.',
      ['admin', 'manajer'], false));
  if (scenario == SeedScenario.fallback) {
    notifs.add(('incomplete', h1, wib(today, 23, 1), 'Data Incomplete Warning',
        'Data H-1 untuk prediksi ${dm(h1)} terlambat. Fallback H-2 dipakai.',
        ['admin', 'manajer', 'supervisor', 'viewer'], false));
  }
  if (degraded) {
    notifs.add(('degraded', today, wib(today, 23, 2), 'Model Degraded',
        'Rolling MAE 7 hari ${rolling.toStringAsFixed(1).replaceAll('.', ',')}% melampaui ambang drift '
            '${threshold.toStringAsFixed(1).replaceAll('.', ',')}%. Disarankan review & retraining manual.',
        ['admin', 'manajer', 'viewer'], false));
  }
  final d5 = h1.subtract(const Duration(days: 5));
  final dev5 = (pred[d5]! - proj[d5]!) / proj[d5]! * 100;
  notifs.add(('deviation', d5, wib(d5.subtract(const Duration(days: 1)), 23, 2), 'Deviasi prediksi >15%',
      'Prediksi ${dm(d5)}: Predicted ${n(pred[d5]!)} vs Projection ${n(proj[d5]!)} (${pct(dev5)}).',
      ['admin', 'manajer', 'supervisor', 'viewer'], true));
  final d7 = today.subtract(const Duration(days: 7));
  notifs.add(('batch', d7.add(const Duration(days: 1)), wib(d7, 23, 9), 'Batch gagal, retry berhasil',
      'Batch ${dm(d7)} gagal sekali lalu berhasil pada retry ke-1.', ['admin', 'manajer'], true));

  for (final x in notifs) {
    final id = '${x.$1}_${whId}_${key(x.$2)}';
    docs.add(SeedDoc('notifications/$id', {
      'type': x.$1,
      'title': x.$4,
      'body': x.$5,
      'wh_id': whId,
      'target_date': iso(x.$2),
      'created_at': x.$3,
      'audience_roles': x.$6,
    }));
    if (x.$7) {
      // Older notifications are already read by every account in its audience.
      for (final a in demoAccounts.where((a) => x.$6.contains(a.role))) {
        docs.add(SeedDoc('users/${uids[a.key]}/notification_reads/$id', {'read_at': x.$3}));
      }
    }
  }
  return docs;
}
