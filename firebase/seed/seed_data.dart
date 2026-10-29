// Deterministic demo dataset for the Firebase Emulator (project demo-wipas).
//
// Pure Dart (no Flutter imports) so it can be used both by
// `firebase/seed/seed.dart` (writes to the emulator over REST) and by the
// widget tests (writes to FakeFirebaseFirestore).
//
// Every document follows the contract in `docs/firestore_schema.md` (v1.0,
// owned by wipas-research): field names, 0/1 flags, `hari` 0 = Senin,
// `YYYY-MM-DD` dates, deterministic IDs, notification audiences and the
// App-owned `actual_*` / `decision_*` / `read_by` fields.
//
// All numbers are SYNTHETIC demo values that mirror the design scenario
// (Predicted 18.420 vs Projection 15.900 → +15,85%). They are NOT model
// results. Metrics that depend on the data (daily error, rolling MAE) are
// computed from the seeded values so the dataset is internally consistent.

import 'package:wipas_app/core/domain/calculators.dart';

/// Seed scenarios.
enum SeedScenario {
  /// Healthy model, H+1 complete, deviation 15,85% on H+1.
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
  const DemoAccount(this.key, this.email, this.role, this.displayName);
  final String key;
  final String email;

  /// Contract role value: admin | manager | supervisor | viewer.
  final String role;
  final String displayName;
}

const demoPassword = 'wipas-demo-123';
const whId = 'WH-CKG-01';

const demoAccounts = [
  DemoAccount('admin', 'admin.shift@wipas.example', 'admin', 'Admin WIPAS · Shift Lead'),
  DemoAccount('manajer', 'manajer@wipas.example', 'manager', 'Budi Santoso'),
  DemoAccount('supervisor', 'supervisor@wipas.example', 'supervisor', 'Rina Putri'),
  DemoAccount('viewer', 'viewer@wipas.example', 'viewer', 'Dewi Lestari'),
];

/// Feature importance with the contract feature keys (sum = 1).
const featureImportance = {
  'actual_h1': 0.27,
  'pickup_request_h1': 0.21,
  'backlog_h1': 0.12,
  'actual_h2': 0.09,
  'projection_inbound': 0.08,
  'campaign': 0.07,
  'payday': 0.06,
  'hari_libur': 0.04,
  'hari': 0.03,
  'bulan': 0.03,
};

/// Notification audiences from the contract.
const audience = {
  'deviation': ['admin', 'manager', 'supervisor'],
  'degraded': ['admin', 'manager', 'viewer'],
  'incomplete': ['admin', 'supervisor'],
  'batch': ['admin'],
};

const _severity = {'deviation': 'warning', 'degraded': 'error', 'incomplete': 'warning', 'batch': 'info'};

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

double _round2(double v) => (v * 100).roundToDouble() / 100;
double _round4(double v) => (v * 10000).roundToDouble() / 10000;

/// 0/1 flag as stored by the script.
int _flag(bool v) => v ? 1 : 0;

Map<String, Object?> _configFields(CapacityConfig c, String updatedBy, DateTime updatedAt) => {
      'wh_id': whId,
      ...c.toMap(),
      'rounding': 'ceil',
      'updated_by': updatedBy,
      'updated_at': updatedAt,
    };

/// Builds all documents. [today] is the WIB calendar date (UTC midnight);
/// [uids] maps account key → Firebase uid.
List<SeedDoc> buildSeed({
  required DateTime today,
  required Map<String, String> uids,
  SeedScenario scenario = SeedScenario.normal,
}) {
  final docs = <SeedDoc>[];
  final h1 = today.add(const Duration(days: 1));
  final seededAt = wib(DateTime.utc(2026, 9, 1), 8, 0);

  // --- users (contract: role, name), warehouse, config (all scenarios)
  for (final a in demoAccounts) {
    docs.add(SeedDoc('users/${uids[a.key]}', {'role': a.role, 'name': a.displayName}));
  }
  docs.add(SeedDoc('warehouses/$whId', {
    'name': 'Hub Cakung',
    'code': whId,
    'timezone': 'Asia/Jakarta',
    'created_at': seededAt,
  }));

  const cfg = CapacityConfig.defaults;
  final lastChange = wib(today.subtract(const Duration(days: 6)), 14, 10);
  docs.add(SeedDoc('operational_configs/$whId', _configFields(cfg, uids['manajer']!, lastChange)));

  // History: a copy of the config after each change + changed_by/at + note.
  final adminName = demoAccounts[0].displayName;
  final manajerName = demoAccounts[1].displayName;
  const afterRider = CapacityConfig(
      capacityRider: 350, capacityDriver: 800, capacityOpInbound: 500, capacityOpOutbound: 580, ratioRider: 0.65, ratioDriver: 0.35);
  const afterRatio = CapacityConfig(
      capacityRider: 350, capacityDriver: 800, capacityOpInbound: 500, capacityOpOutbound: 580, ratioRider: 0.70, ratioDriver: 0.30);
  final history = [
    (lastChange, 'manajer', manajerName, cfg, 'Capacity_Op_Outbound: 580 → 600'),
    (wib(today.subtract(const Duration(days: 17)), 9, 30), 'admin', adminName, afterRatio,
        'Ratio_Rider: 0,65 → 0,70; Ratio_Driver: 0,35 → 0,30'),
    (wib(today.subtract(const Duration(days: 37)), 8, 5), 'admin', adminName, afterRider, 'Capacity_Rider: 330 → 350'),
  ];
  for (var i = 0; i < history.length; i++) {
    final h = history[i];
    docs.add(SeedDoc('operational_configs/$whId/history/seed_${i + 1}', {
      ..._configFields(h.$4, uids[h.$2]!, h.$1),
      'changed_by': uids[h.$2],
      'changed_by_name': h.$3,
      'changed_at': h.$1,
      'note': h.$5,
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

  // Decisions for the 8 days before H+1 (H+1 stays undecided).
  final decisions = <DateTime, (String, ManpowerCounts, String?)>{};
  for (var off = -8; off <= -1; off++) {
    final d = h1.add(Duration(days: off));
    final rec = ManpowerCalculator.compute(pred[d]!, cfg);
    decisions[d] = switch (off) {
      -3 => ('adjusted', rec.copyWith(rider: rec.rider + 2), 'tambahan rute padat'),
      -5 => ('adjusted', rec.copyWith(opInbound: rec.opInbound + 2), 'antrean bongkar muat'),
      _ => ('approved', rec, null),
    };
  }

  final errors = <DateTime, double>{};
  final excelRows = <DateTime>[];
  for (var off = -(days - 1); off <= 0; off++) {
    final d = h1.add(Duration(days: off));
    final a = actual[d];
    final dPrev = d.subtract(const Duration(days: 1));
    final dPrev2 = d.subtract(const Duration(days: 2));
    final isTarget = d == h1;
    final fallback = isTarget && scenario == SeedScenario.fallback;
    final dev = (pred[d]! - proj[d]!) / proj[d]! * 100;
    final alert = DeviationCalculator.needsAttention(dev);
    final counts = ManpowerCalculator.compute(pred[d]!, cfg);
    final err = ErrorMetrics.dailyErrorPct(pred[d], a);
    if (err != null) errors[d] = err;
    final campaign = _flag(d.day == 10 || d.day == 11);
    final payday = _flag(d.day >= 25 || d.day == 1 || isTarget);
    final pickup = isTarget ? 21300 : ((actual[dPrev] ?? 15000) * 1.21).round();
    final backlog = isTarget ? 640 : 300 + rng.range(0, 600);
    final features = <String, Object?>{
      'hari': d.weekday - 1, // 0 = Senin (pandas dayofweek)
      'bulan': d.month,
      'campaign': campaign,
      'hari_libur': 0,
      'payday': payday,
      'pickup_request_h1': pickup,
      'projection_inbound': proj[d],
      'backlog_h1': backlog,
      'actual_h2': actual[dPrev2] ?? (pred[dPrev2] ?? 15000),
      'actual_h1': fallback ? null : (actual[dPrev] ?? pred[dPrev]),
    };
    final evaluated = err != null;
    final dec = decisions[d];
    final fromApp = a != null && d.isAfter(today.subtract(const Duration(days: 3)));
    docs.add(SeedDoc('predictions/pred_${whId}_${key(d)}', {
      'wh_id': whId,
      'target_date': iso(d),
      'predicted': pred[d],
      'projection': proj[d],
      'deviation_pct': _round2(dev),
      'alert': alert,
      'status': alert ? 'Perlu Perhatian' : 'Normal',
      'data_status': fallback ? 'incomplete_fallback_h2' : 'complete',
      'source': fallback ? 'H-2' : 'H-1',
      'model_version': 'v1.0',
      'generated_at': wib(dPrev, 23, 0, 41),
      'input_features': features,
      'feature_importance': featureImportance,
      'manpower': {
        ...counts.toMap(),
        'config_snapshot': {...cfg.toMap(), 'rounding': 'ceil', 'source': 'firestore'},
      },
      'is_backfill': off < -13,
      'is_dummy_data': true,
      'notes': [
        if (fallback) 'Fallback H-2: actual ${iso(dPrev)} belum tersedia; actual_h1 tidak terisi.',
        if (off < -13) 'Backfill walk-forward (estimasi historis).',
      ],
      'evaluated': evaluated,
      'daily_error_pct': err == null ? null : _round2(err),
      'evaluated_at': evaluated ? wib(d, 23, 1) : null,
      'actual_inbound': a,
      'actual_note': null,
      'actual_input_by': a == null ? null : (fromApp ? uids[off.isEven ? 'supervisor' : 'admin'] : 'backfill:excel'),
      'actual_input_at': a == null ? null : wib(d, 21, 15),
      if (dec != null) ...{
        'decision_status': dec.$1,
        'decision_by': uids['manajer'],
        'decision_at': wib(d, 6, 40),
        'decision_note': dec.$3,
        'decision_manpower': dec.$2.toMap(),
      },
    }));
    docs.add(SeedDoc('daily_data/${whId}_${key(d)}', {
      'wh_id': whId,
      'date': iso(d),
      'campaign': campaign,
      'hari_libur': 0,
      'payday': payday,
      'pickup_request_h1': pickup,
      'projection_inbound': proj[d],
      'backlog_h1': backlog,
      'actual_inbound': a,
      if (a != null) 'actual_source': fromApp ? 'app' : 'excel',
      if (fromApp) 'actual_synced_at': wib(d, 23, 1),
      'row_hash': 'seed${key(d)}',
      'source_file': 'inbound_hub_cakung_DUMMY.xlsx',
      'imported_at': wib(today, 22, 30),
    }));
    excelRows.add(d);
  }

  // --- model health (rolling MAE computed from the seeded errors)
  const baseline = 6.2;
  const driftFactor = 1.15;
  final threshold = _round4(baseline * driftFactor);
  (double?, int) rollingAt(DateTime end) {
    final window = [
      for (var i = 6; i >= 0; i--)
        if (errors[end.subtract(Duration(days: i))] != null) errors[end.subtract(Duration(days: i))]!,
    ];
    return (ErrorMetrics.rollingMae(window), window.length);
  }

  final lastEvaluated = actual[today] != null ? today : today.subtract(const Duration(days: 1));
  final (rollingRaw, nPoints) = rollingAt(lastEvaluated);
  final rolling = _round4(rollingRaw!);
  final degraded = nPoints >= 7 && rolling > threshold;
  docs.add(SeedDoc('model_health/$whId', {
    'wh_id': whId,
    'status': degraded ? 'degraded' : 'healthy',
    'rolling_mae_7d': rolling,
    'rolling_window_days': 7,
    'n_points': nPoints,
    'last_evaluated_date': iso(lastEvaluated),
    'baseline_mae': baseline,
    'drift_threshold': threshold,
    'drift_factor': driftFactor,
    'model_version': 'v1.0',
    'mae_validation': 6.8,
    'mae_validation_paket': 1083.5,
    'rmse': 9.4,
    'rmse_paket': 1497.2,
    'r2': 0.89,
    'feature_importance': featureImportance,
    'trained_at': '2026-09-01T02:41:00+00:00',
    'is_dummy_data': true,
    'updated_at': wib(today, 23, 2),
  }));
  for (var i = 29; i >= 0; i--) {
    final d = lastEvaluated.subtract(Duration(days: i));
    final (r, n) = rollingAt(d);
    if (r == null) continue;
    docs.add(SeedDoc('model_health_history/${whId}_${key(d)}', {
      'wh_id': whId,
      'date': iso(d),
      'rolling_mae_7d': _round4(r),
      'status': (n >= 7 && r > threshold) ? 'degraded' : 'healthy',
      'baseline_mae': baseline,
      'drift_threshold': threshold,
      'n_points': n,
      'model_version': 'v1.0',
      'updated_at': wib(d, 23, 2),
    }));
  }

  // --- batch logs (one run per evening, ID = target date) and dataset status
  for (var i = 29; i >= 0; i--) {
    final run = today.subtract(Duration(days: i));
    final target = run.add(const Duration(days: 1));
    final retry = i == 7 ? 1 : 0;
    final isLast = i == 0;
    final src = (isLast && scenario == SeedScenario.fallback) ? 'H-2' : 'H-1';
    docs.add(SeedDoc('batch_logs/${whId}_${key(target)}', {
      'wh_id': whId,
      'target_date': iso(target),
      'started_at': wib(run, 23, 0),
      'finished_at': wib(run, 23, 2, 14 + retry * 420),
      'duration_s': 134.0 + retry * 420,
      'status': 'success',
      'message': retry > 0 ? 'Gagal sekali (timeout), berhasil pada retry ke-1.' : 'Prediksi ${iso(target)} ditulis.',
      'retries': retry,
      'source': src,
      'data_status': src == 'H-2' ? 'incomplete_fallback_h2' : 'complete',
      'model_version': 'v1.0',
      'predicted': pred[target],
      'evaluated_dates': [if (actual[run] != null) iso(run)],
      'error': null,
      'dry_run': false,
    }));
  }
  final rangeStart = DateTime.utc(2025, 1, 1);
  final lastActual = actual[today] == null ? today.subtract(const Duration(days: 1)) : today;
  final rows = h1.difference(rangeStart).inDays + 1;
  docs.add(SeedDoc('dataset_status/$whId', {
    'wh_id': whId,
    'last_import_at': wib(today, 22, 30),
    'range_start': iso(rangeStart),
    'range_end': iso(h1),
    'row_count': rows,
    'labeled_count': lastActual.difference(rangeStart).inDays + 1,
    'last_actual_date': iso(lastActual),
    'target_dates': [for (var d = lastActual.add(const Duration(days: 1)); !d.isAfter(h1); d = d.add(const Duration(days: 1))) iso(d)],
    'missing_dates': <String>[],
    'source_file': 'inbound_hub_cakung_DUMMY.xlsx',
    'is_dummy_data': true,
    'last_import_written_rows': excelRows.length,
    'last_batch_at': wib(today, 23, 2),
    'last_batch_status': 'success',
    'last_batch_target_date': iso(h1),
  }));

  // --- decision logs (App-owned; same decisions as on the predictions)
  for (final e in decisions.entries) {
    final d = e.key;
    docs.add(SeedDoc('decision_logs/seed_${key(d)}', {
      'wh_id': whId,
      'target_date': iso(d),
      'prediction_id': 'pred_${whId}_${key(d)}',
      'recommended': ManpowerCalculator.compute(pred[d]!, cfg).toMap(),
      'final': e.value.$2.toMap(),
      'decision_status': e.value.$1,
      'note': e.value.$3,
      'decided_by': uids['manajer'],
      'decided_by_name': manajerName,
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

  String pct(double v) => '${v >= 0 ? '+' : '−'}${_round2(v.abs()).toStringAsFixed(1).replaceAll('.', ',')}%';

  // (type, date in ID, created_at, title, body, already read by audience, extra fields)
  final notifs = <(String, DateTime, DateTime, String, String, bool, Map<String, Object?>)>[];
  final devH1 = (pred[h1]! - proj[h1]!) / proj[h1]! * 100;
  notifs.add(('deviation', h1, wib(today, 23, 2), 'Deviasi prediksi >15%',
      'Prediksi ${dm(h1)}: Predicted ${n(pred[h1]!)} vs Projection ${n(proj[h1]!)} (${pct(devH1)}). Perlu ditinjau.',
      false, {'deviation_pct': _round2(devH1)}));
  notifs.add(('batch', h1, wib(today, 23, 2), 'Batch prediksi selesai',
      'Batch ${dm(today)} 23:00 WIB berhasil dalam 2 mnt 14 dtk. Sumber data ${scenario == SeedScenario.fallback ? 'H-2' : 'H-1'}.',
      false, {'batch_status': 'success', 'batch_log_id': '${whId}_${key(h1)}', 'updated_at': wib(today, 23, 2)}));
  if (scenario == SeedScenario.fallback) {
    notifs.add(('incomplete', h1, wib(today, 23, 1), 'Data Incomplete Warning',
        'Actual ${iso(today)} belum diinput; prediksi ${iso(h1)} memakai fallback H-2. Input actual lalu jalankan ulang batch.',
        false, const {}));
  }
  if (degraded) {
    notifs.add(('degraded', lastEvaluated, wib(today, 23, 2), 'Model Degraded',
        'Rolling MAE 7 hari ${rolling.toStringAsFixed(1).replaceAll('.', ',')}% melampaui ambang drift '
            '${threshold.toStringAsFixed(1).replaceAll('.', ',')}%. Disarankan review & retraining manual.',
        false, {'rolling_mae_7d': rolling, 'drift_threshold': threshold}));
  }
  final d5 = h1.subtract(const Duration(days: 5));
  final dev5 = (pred[d5]! - proj[d5]!) / proj[d5]! * 100;
  notifs.add(('deviation', d5, wib(d5.subtract(const Duration(days: 1)), 23, 2), 'Deviasi prediksi >15%',
      'Prediksi ${dm(d5)}: Predicted ${n(pred[d5]!)} vs Projection ${n(proj[d5]!)} (${pct(dev5)}).',
      true, {'deviation_pct': _round2(dev5)}));
  final d7 = today.subtract(const Duration(days: 7));
  final t7 = d7.add(const Duration(days: 1));
  notifs.add(('batch', t7, wib(d7, 23, 9), 'Batch gagal, retry berhasil',
      'Batch ${dm(d7)} gagal sekali lalu berhasil pada retry ke-1.', true,
      {'batch_status': 'success', 'batch_log_id': '${whId}_${key(t7)}', 'updated_at': wib(d7, 23, 9)}));

  for (final x in notifs) {
    final roles = audience[x.$1]!;
    docs.add(SeedDoc('notifications/${x.$1}_${whId}_${key(x.$2)}', {
      'type': x.$1,
      'title': x.$4,
      'body': x.$5,
      'severity': _severity[x.$1],
      'wh_id': whId,
      'target_date': iso(x.$2),
      'created_at': x.$3,
      'audience_roles': roles,
      ...x.$7,
      // Older notifications are already read by every account in the audience.
      'read_by': [
        if (x.$6)
          for (final a in demoAccounts.where((a) => roles.contains(a.role))) uids[a.key],
      ],
    }));
  }
  return docs;
}
