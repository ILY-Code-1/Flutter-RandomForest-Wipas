// Guards the Firestore contract (docs/firestore_schema.md v1.0, owned by
// wipas-research): every seeded document may only use fields listed in the
// contract, and must contain the required ones. The seed feeds the emulator
// and every widget test, so this keeps the app's view of the data honest.
import 'package:flutter_test/flutter_test.dart';

import '../../firebase/seed/seed_data.dart';
import '../support/harness.dart';

/// (allowed fields, required fields) per collection path pattern.
/// Fields marked `[App ext]` are App-owned extensions documented in
/// docs/SYNC_REPORT.md (contract lists them as "saran" or omits display names).
final _contract = <RegExp, (Set<String>, Set<String>)>{
  RegExp(r'^warehouses/[^/]+$'): (
    {'name', 'code', 'timezone', 'created_at'},
    {'name', 'code', 'timezone', 'created_at'},
  ),
  RegExp(r'^daily_data/[^/]+$'): (
    {
      'wh_id', 'date', 'campaign', 'hari_libur', 'payday', 'pickup_request_h1', 'projection_inbound', 'backlog_h1',
      'actual_inbound', 'actual_source', 'actual_synced_at', 'row_hash', 'source_file', 'imported_at',
    },
    {'wh_id', 'date', 'campaign', 'hari_libur', 'payday', 'pickup_request_h1', 'projection_inbound', 'backlog_h1', 'actual_inbound'},
  ),
  RegExp(r'^predictions/[^/]+$'): (
    {
      'wh_id', 'target_date', 'predicted', 'projection', 'deviation_pct', 'alert', 'status', 'data_status', 'source',
      'model_version', 'generated_at', 'input_features', 'feature_importance', 'manpower', 'is_backfill',
      'is_dummy_data', 'notes', 'evaluated', 'daily_error_pct', 'evaluated_at', 'actual_inbound', 'actual_note',
      'actual_input_by', 'actual_input_at', 'decision_status', 'decision_by', 'decision_at', 'decision_note',
      'decision_manpower',
    },
    {
      'wh_id', 'target_date', 'predicted', 'projection', 'deviation_pct', 'alert', 'status', 'data_status', 'source',
      'model_version', 'generated_at', 'input_features', 'feature_importance', 'manpower', 'is_backfill',
      'is_dummy_data', 'notes', 'evaluated',
    },
  ),
  RegExp(r'^operational_configs/[^/]+$'): (
    {
      'wh_id', 'capacity_rider', 'capacity_driver', 'capacity_op_inbound', 'capacity_op_outbound', 'ratio_rider',
      'ratio_driver', 'rounding', 'updated_by', 'updated_at',
    },
    {
      'wh_id', 'capacity_rider', 'capacity_driver', 'capacity_op_inbound', 'capacity_op_outbound', 'ratio_rider',
      'ratio_driver', 'rounding', 'updated_by', 'updated_at',
    },
  ),
  RegExp(r'^operational_configs/[^/]+/history/[^/]+$'): (
    {
      'wh_id', 'capacity_rider', 'capacity_driver', 'capacity_op_inbound', 'capacity_op_outbound', 'ratio_rider',
      'ratio_driver', 'rounding', 'updated_by', 'updated_at', 'changed_by', 'changed_at', 'note',
      'changed_by_name', // [App ext]
    },
    {'changed_by', 'changed_at', 'note', 'capacity_rider', 'ratio_rider', 'ratio_driver'},
  ),
  RegExp(r'^model_health/[^/]+$'): (
    {
      'wh_id', 'status', 'rolling_mae_7d', 'rolling_window_days', 'n_points', 'last_evaluated_date', 'baseline_mae',
      'drift_threshold', 'drift_factor', 'model_version', 'mae_validation', 'mae_validation_paket', 'rmse',
      'rmse_paket', 'r2', 'feature_importance', 'trained_at', 'is_dummy_data', 'updated_at',
    },
    {
      'wh_id', 'status', 'rolling_mae_7d', 'rolling_window_days', 'n_points', 'last_evaluated_date', 'baseline_mae',
      'drift_threshold', 'drift_factor', 'model_version', 'mae_validation', 'mae_validation_paket', 'rmse',
      'rmse_paket', 'r2', 'feature_importance', 'trained_at', 'is_dummy_data', 'updated_at',
    },
  ),
  RegExp(r'^model_health_history/[^/]+$'): (
    {'wh_id', 'date', 'rolling_mae_7d', 'status', 'baseline_mae', 'drift_threshold', 'n_points', 'model_version', 'updated_at'},
    {'wh_id', 'date', 'rolling_mae_7d', 'status', 'baseline_mae', 'drift_threshold', 'n_points', 'model_version', 'updated_at'},
  ),
  RegExp(r'^batch_logs/[^/]+$'): (
    {
      'wh_id', 'target_date', 'started_at', 'finished_at', 'duration_s', 'status', 'message', 'retries', 'source',
      'data_status', 'model_version', 'predicted', 'evaluated_dates', 'error', 'dry_run',
    },
    {
      'wh_id', 'target_date', 'started_at', 'finished_at', 'duration_s', 'status', 'message', 'retries', 'source',
      'data_status', 'model_version', 'predicted', 'evaluated_dates', 'error', 'dry_run',
    },
  ),
  RegExp(r'^dataset_status/[^/]+$'): (
    {
      'wh_id', 'last_import_at', 'range_start', 'range_end', 'row_count', 'labeled_count', 'last_actual_date',
      'target_dates', 'missing_dates', 'source_file', 'is_dummy_data', 'last_import_written_rows', 'last_batch_at',
      'last_batch_status', 'last_batch_target_date',
    },
    {
      'wh_id', 'last_import_at', 'range_start', 'range_end', 'row_count', 'labeled_count', 'last_actual_date',
      'target_dates', 'missing_dates', 'source_file', 'is_dummy_data', 'last_import_written_rows',
    },
  ),
  RegExp(r'^notifications/[^/]+$'): (
    {
      'type', 'title', 'body', 'severity', 'wh_id', 'target_date', 'created_at', 'audience_roles', 'updated_at',
      'batch_status', 'batch_log_id', 'deviation_pct', 'rolling_mae_7d', 'drift_threshold', 'read_by',
    },
    {'type', 'title', 'body', 'severity', 'wh_id', 'target_date', 'created_at', 'audience_roles'},
  ),
  RegExp(r'^decision_logs/[^/]+$'): (
    {
      'wh_id', 'target_date', 'prediction_id', 'recommended', 'final', 'decision_status', 'note', 'decided_by',
      'decided_at',
      'decided_by_name', // [App ext]
    },
    {'wh_id', 'target_date', 'prediction_id', 'final', 'decision_status', 'decided_by', 'decided_at'},
  ),
  RegExp(r'^users/[^/]+$'): ({'role', 'name'}, {'role', 'name'}),
};

const _features = {
  'hari', 'bulan', 'campaign', 'hari_libur', 'payday', 'pickup_request_h1', 'projection_inbound', 'backlog_h1',
  'actual_h2', 'actual_h1',
};
const _roles = {'admin', 'manager', 'supervisor', 'viewer'};
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

void main() {
  for (final scenario in SeedScenario.values) {
    group('seed (${scenario.name}) follows the contract', () {
      final docs = buildSeed(today: testToday, uids: testUids, scenario: scenario);

      test('every document matches a contract collection with allowed + required fields', () {
        for (final d in docs) {
          final entry = _contract.entries.where((e) => e.key.hasMatch(d.path)).toList();
          expect(entry, hasLength(1), reason: 'no contract entry for ${d.path}');
          final (allowed, required) = entry.single.value;
          final keys = d.data.keys.toSet();
          expect(keys.difference(allowed), isEmpty, reason: 'fields outside contract in ${d.path}');
          expect(required.difference(keys), isEmpty, reason: 'missing required fields in ${d.path}');
        }
      });

      test('nested maps, enums, dates and IDs follow the contract', () {
        for (final d in docs) {
          final m = d.data;
          if (d.path.startsWith('predictions/')) {
            expect((m['input_features'] as Map).keys.toSet(), _features, reason: d.path);
            expect((m['feature_importance'] as Map).keys.toSet(), _features, reason: d.path);
            final f = m['input_features'] as Map;
            expect(f['hari'], inInclusiveRange(0, 6), reason: '${d.path}: hari 0 = Senin');
            for (final k in ['campaign', 'hari_libur', 'payday']) {
              expect(f[k], anyOf(0, 1), reason: '${d.path}.$k must be 0/1');
            }
            final mp = m['manpower'] as Map;
            expect(mp.keys.toSet(), {'rider', 'driver', 'op_inbound', 'op_outbound', 'config_snapshot'});
            expect((mp['config_snapshot'] as Map).keys.toSet(), {
              'capacity_rider', 'capacity_driver', 'capacity_op_inbound', 'capacity_op_outbound', 'ratio_rider',
              'ratio_driver', 'rounding', 'source',
            });
            expect(m['status'], anyOf('Normal', 'Perlu Perhatian'));
            expect(m['data_status'], anyOf('complete', 'incomplete_fallback_h2'));
            expect(m['target_date'], matches(_isoDate));
            expect(d.path, 'predictions/pred_WH-CKG-01_${(m['target_date'] as String).replaceAll('-', '')}');
            final dev = m['deviation_pct'] as double;
            expect((dev * 100).roundToDouble() / 100, dev, reason: 'deviation_pct has 2 decimals');
            if (m['decision_status'] != null) {
              expect(m['decision_status'], anyOf('approved', 'adjusted'));
              expect((m['decision_manpower'] as Map).keys.toSet(), {'rider', 'driver', 'op_inbound', 'op_outbound'});
            }
          }
          if (d.path.startsWith('daily_data/')) {
            for (final k in ['campaign', 'hari_libur', 'payday']) {
              expect(m[k], anyOf(0, 1), reason: '${d.path}.$k');
            }
            expect(m['date'], matches(_isoDate));
          }
          if (d.path.startsWith('notifications/')) {
            final type = m['type'] as String;
            expect(m['audience_roles'], audience[type], reason: '${d.path} audience');
            expect(m['severity'], anyOf('info', 'warning', 'error'));
            expect(d.path, startsWith('notifications/${type}_WH-CKG-01_'));
          }
          if (d.path.startsWith('batch_logs/')) {
            expect(m['status'], anyOf('success', 'skipped', 'failed'));
            expect(m['duration_s'], isA<double>());
            expect(d.path, 'batch_logs/WH-CKG-01_${(m['target_date'] as String).replaceAll('-', '')}');
          }
          if (d.path.startsWith('users/')) {
            expect(_roles, contains(m['role']));
          }
        }
      });
    });
  }
}
