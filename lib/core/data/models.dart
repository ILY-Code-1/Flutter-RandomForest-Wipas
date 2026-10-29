import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/calculators.dart';
import '../domain/role.dart';
import '../format/formatters.dart';

// Converters for the Firestore contract `docs/firestore_schema.md` (v1.0,
// owned by wipas-research). Readers are null-tolerant: missing or mistyped
// fields become null instead of throwing, so the UI falls back to empty
// states.

int? _int(Object? v) => v is num ? v.round() : (v is String ? int.tryParse(v) : null);
double? _double(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
bool _bool(Object? v) => v == true || v == 1;
bool? _boolOrNull(Object? v) => v is bool ? v : (v is num ? v != 0 : null);
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<String> _strList(Object? v) => v is List ? v.whereType<String>().toList() : const [];

DateTime? _time(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime? _date(Object? v) {
  if (v is String) return Fmt.parseIsoDate(v);
  final t = _time(v);
  if (t == null) return null;
  final w = Fmt.toWib(t);
  return DateTime.utc(w.year, w.month, w.day);
}

Map<String, double> _doubleMap(Object? v) {
  final out = <String, double>{};
  _map(v).forEach((k, value) {
    final d = _double(value);
    if (d != null) out[k] = d;
  });
  return out;
}

ManpowerCounts? _counts(Object? raw) {
  final m = _map(raw);
  final rider = _int(m['rider']);
  final driver = _int(m['driver']);
  final opIn = _int(m['op_inbound']);
  final opOut = _int(m['op_outbound']);
  if (rider == null || driver == null || opIn == null || opOut == null) return null;
  return ManpowerCounts(rider: rider, driver: driver, opInbound: opIn, opOutbound: opOut);
}

/// `predictions.data_status` values.
class DataStatus {
  DataStatus._();
  static const complete = 'complete';
  static const fallbackH2 = 'incomplete_fallback_h2';
}

/// `predictions.status` values (written by the batch script).
class PredictionStatus {
  PredictionStatus._();
  static const normal = 'Normal';
  static const perluPerhatian = 'Perlu Perhatian';
}

/// `predictions.decision_status` / `decision_logs.decision_status` values.
class DecisionStatus {
  DecisionStatus._();
  static const approved = 'approved';
  static const adjusted = 'adjusted';
}

/// `predictions.input_features` — snapshot of the ten predictors.
/// Flags (`campaign`, `hari_libur`, `payday`) are stored as 0/1 ints.
class InputFeatures {
  const InputFeatures({
    this.hari,
    this.bulan,
    this.isCampaign,
    this.isHoliday,
    this.isPayday,
    this.pickupRequestH1,
    this.projectionInbound,
    this.backlogH1,
    this.actualInboundH2,
    this.actualInboundH1,
  });

  factory InputFeatures.fromMap(Map<String, dynamic> m) => InputFeatures(
        hari: _int(m['hari']),
        bulan: _int(m['bulan']),
        isCampaign: _boolOrNull(m['campaign']),
        isHoliday: _boolOrNull(m['hari_libur']),
        isPayday: _boolOrNull(m['payday']),
        pickupRequestH1: _int(m['pickup_request_h1']),
        projectionInbound: _int(m['projection_inbound']),
        backlogH1: _int(m['backlog_h1']),
        actualInboundH2: _int(m['actual_h2']),
        actualInboundH1: _int(m['actual_h1']),
      );

  /// Day of week, 0 = Senin … 6 = Minggu (pandas `dayofweek`).
  final int? hari;
  final int? bulan;
  final bool? isCampaign;
  final bool? isHoliday;
  final bool? isPayday;
  final int? pickupRequestH1;
  final int? projectionInbound;
  final int? backlogH1;
  final int? actualInboundH2;
  final int? actualInboundH1;
}

/// Display labels for feature keys (`input_features` / `feature_importance`).
const featureLabels = <String, String>{
  'actual_h1': 'Actual Inbound H-1',
  'pickup_request_h1': 'Pickup Request H-1',
  'backlog_h1': 'Backlog H-1',
  'actual_h2': 'Actual Inbound H-2',
  'projection_inbound': 'Projection Inbound',
  'campaign': 'Campaign',
  'payday': 'Payday',
  'hari_libur': 'Hari Libur',
  'hari': 'Hari',
  'bulan': 'Bulan',
};

/// `predictions.manpower` (recommendation computed by the script).
class ManpowerRecommendation {
  const ManpowerRecommendation({required this.counts, this.configSnapshot, this.snapshotSource});

  final ManpowerCounts counts;
  final CapacityConfig? configSnapshot;

  /// `"firestore"` (from operational_configs) or `"default"` (config.yaml).
  final String? snapshotSource;

  static ManpowerRecommendation? fromMap(Object? raw) {
    final counts = _counts(raw);
    if (counts == null) return null;
    final snap = _map(raw)['config_snapshot'];
    return ManpowerRecommendation(
      counts: counts,
      configSnapshot: snap is Map ? OperationalConfig.fromMap(_map(snap)).capacity : null,
      snapshotSource: snap is Map ? _str(snap['source']) : null,
    );
  }
}

/// `predictions/pred_{wh}_{YYYYMMDD}`
class Prediction {
  const Prediction({
    required this.id,
    required this.whId,
    required this.targetDate,
    this.predicted,
    this.projection,
    this.deviationPct,
    this.alert = false,
    this.status,
    this.dataStatus = DataStatus.complete,
    this.source,
    this.modelVersion,
    this.generatedAt,
    this.inputFeatures = const InputFeatures(),
    this.featureImportance = const {},
    this.manpower,
    this.isBackfill = false,
    this.isDummyData = false,
    this.notes = const [],
    this.evaluated = false,
    this.dailyErrorPct,
    this.evaluatedAt,
    this.actualInbound,
    this.actualNote,
    this.actualInputBy,
    this.actualInputAt,
    this.decisionStatus,
    this.decisionBy,
    this.decisionAt,
    this.decisionNote,
    this.decisionManpower,
  });

  static Prediction? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    final date = _date(m['target_date']);
    if (date == null) return null;
    return Prediction(
      id: id,
      whId: _str(m['wh_id']) ?? '',
      targetDate: date,
      predicted: _int(m['predicted']),
      projection: _int(m['projection']),
      deviationPct: _double(m['deviation_pct']),
      alert: _bool(m['alert']),
      status: _str(m['status']),
      dataStatus: _str(m['data_status']) ?? DataStatus.complete,
      source: _str(m['source']),
      modelVersion: _str(m['model_version']),
      generatedAt: _time(m['generated_at']),
      inputFeatures: InputFeatures.fromMap(_map(m['input_features'])),
      featureImportance: _doubleMap(m['feature_importance']),
      manpower: ManpowerRecommendation.fromMap(m['manpower']),
      isBackfill: _bool(m['is_backfill']),
      isDummyData: _bool(m['is_dummy_data']),
      notes: _strList(m['notes']),
      evaluated: _bool(m['evaluated']),
      dailyErrorPct: _double(m['daily_error_pct']),
      evaluatedAt: _time(m['evaluated_at']),
      actualInbound: _int(m['actual_inbound']),
      actualNote: _str(m['actual_note']),
      actualInputBy: _str(m['actual_input_by']),
      actualInputAt: _time(m['actual_input_at']),
      decisionStatus: _str(m['decision_status']),
      decisionBy: _str(m['decision_by']),
      decisionAt: _time(m['decision_at']),
      decisionNote: _str(m['decision_note']),
      decisionManpower: _counts(m['decision_manpower']),
    );
  }

  static String docId(String whId, DateTime date) => 'pred_${whId}_${Fmt.dateKey(date)}';

  final String id;
  final String whId;
  final DateTime targetDate;
  final int? predicted;
  final int? projection;
  final double? deviationPct;
  final bool alert;
  final String? status;
  final String dataStatus;
  final String? source;
  final String? modelVersion;
  final DateTime? generatedAt;
  final InputFeatures inputFeatures;
  final Map<String, double> featureImportance;
  final ManpowerRecommendation? manpower;
  final bool isBackfill;
  final bool isDummyData;
  final List<String> notes;
  final bool evaluated;
  final double? dailyErrorPct;
  final DateTime? evaluatedAt;
  // App-owned fields.
  final int? actualInbound;
  final String? actualNote;
  final String? actualInputBy;
  final DateTime? actualInputAt;
  final String? decisionStatus;
  final String? decisionBy;
  final DateTime? decisionAt;
  final String? decisionNote;
  final ManpowerCounts? decisionManpower;

  bool get isFallback => dataStatus != DataStatus.complete;

  /// Deviation in percent: stored value, else computed from the inputs.
  double? get deviation => deviationPct ?? DeviationCalculator.percent(predicted, projection);

  bool get needsAttention => alert || DeviationCalculator.needsAttention(deviation);

  /// Error vs actual: stored value from the script, else computed.
  double? get errorPct => dailyErrorPct ?? ErrorMetrics.dailyErrorPct(predicted, actualInbound);

  /// Source label ("H-1"/"H-2").
  String get sourceLabel => source ?? (isFallback ? 'H-2' : 'H-1');

  bool get isDecided => decisionStatus != null;
  bool get isAdjusted => decisionStatus == DecisionStatus.adjusted;
}

/// `operational_configs/{wh}`
class OperationalConfig {
  const OperationalConfig({required this.capacity, this.rounding, this.updatedBy, this.updatedAt});

  factory OperationalConfig.fromMap(Map<String, dynamic> m) {
    const d = CapacityConfig.defaults;
    return OperationalConfig(
      capacity: CapacityConfig(
        capacityRider: _double(m['capacity_rider']) ?? d.capacityRider,
        capacityDriver: _double(m['capacity_driver']) ?? d.capacityDriver,
        capacityOpInbound: _double(m['capacity_op_inbound']) ?? d.capacityOpInbound,
        capacityOpOutbound: _double(m['capacity_op_outbound']) ?? d.capacityOpOutbound,
        ratioRider: _double(m['ratio_rider']) ?? d.ratioRider,
        ratioDriver: _double(m['ratio_driver']) ?? d.ratioDriver,
      ),
      rounding: _str(m['rounding']),
      updatedBy: _str(m['updated_by']),
      updatedAt: _time(m['updated_at']),
    );
  }

  final CapacityConfig capacity;
  final String? rounding;

  /// uid, or `"wipas-research:seed-config"` when seeded by the script.
  final String? updatedBy;
  final DateTime? updatedAt;
}

/// `decision_logs/{auto}` (App-owned, append-only).
class DecisionLog {
  const DecisionLog({
    required this.id,
    required this.predId,
    required this.whId,
    required this.decidedBy,
    required this.decidedByName,
    required this.decision,
    required this.manpowerFinal,
    this.recommended,
    this.targetDate,
    this.reason,
    this.decidedAt,
  });

  static DecisionLog? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    final decision = _str(m['decision_status']);
    if (decision == null) return null;
    return DecisionLog(
      id: id,
      predId: _str(m['prediction_id']) ?? '',
      whId: _str(m['wh_id']) ?? '',
      targetDate: _date(m['target_date']),
      decidedBy: _str(m['decided_by']) ?? '',
      decidedByName: _str(m['decided_by_name']) ?? '',
      decision: decision,
      recommended: _counts(m['recommended']),
      manpowerFinal: _counts(m['final']),
      reason: _str(m['note']),
      decidedAt: _time(m['decided_at']),
    );
  }

  final String id;

  /// `prediction_id`
  final String predId;
  final String whId;
  final DateTime? targetDate;
  final String decidedBy;

  /// App extension (not in the contract's suggested list): rules only let a
  /// user read their own profile, so the name is copied at write time.
  final String decidedByName;

  /// `decision_status`: approved | adjusted
  final String decision;
  final ManpowerCounts? recommended;

  /// `final`
  final ManpowerCounts? manpowerFinal;

  /// `note`
  final String? reason;
  final DateTime? decidedAt;

  bool get isAdjusted => decision == DecisionStatus.adjusted;
}

/// `operational_configs/{wh}/history/{auto}` (App-owned): a copy of the
/// config fields plus `changed_by`, `changed_at`, `note`.
class ConfigHistoryEntry {
  const ConfigHistoryEntry({
    required this.id,
    required this.changedByName,
    this.changedBy,
    this.changedAt,
    this.note,
    this.values = const {},
  });

  factory ConfigHistoryEntry.fromDoc(String id, Map<String, dynamic> m) => ConfigHistoryEntry(
        id: id,
        changedBy: _str(m['changed_by']),
        changedByName: _str(m['changed_by_name']) ?? _str(m['changed_by']) ?? '',
        changedAt: _time(m['changed_at']),
        note: _str(m['note']),
        values: {
          for (final k in const [
            'capacity_rider',
            'capacity_driver',
            'capacity_op_inbound',
            'capacity_op_outbound',
            'ratio_rider',
            'ratio_driver',
          ])
            if (_double(m[k]) != null) k: _double(m[k])!,
        },
      );

  final String id;
  final String? changedBy;
  final String changedByName;
  final DateTime? changedAt;

  /// Human-readable change summary ("Capacity_Rider: 350 → 400; …").
  final String? note;

  /// Config values after the change.
  final Map<String, double> values;
}

/// `model_health/{wh}` (written by the script; app only reads).
class ModelHealth {
  const ModelHealth({
    required this.status,
    this.rollingMae7d,
    this.rollingWindowDays,
    this.nPoints,
    this.lastEvaluatedDate,
    this.baselineMae,
    this.driftThreshold,
    this.driftFactor,
    this.modelVersion,
    this.maeValidation,
    this.maeValidationPaket,
    this.rmse,
    this.rmsePaket,
    this.r2,
    this.featureImportance = const {},
    this.trainedAt,
    this.isDummyData = false,
    this.updatedAt,
  });

  static ModelHealth? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return ModelHealth(
      status: _str(m['status']) ?? 'healthy',
      rollingMae7d: _double(m['rolling_mae_7d']),
      rollingWindowDays: _int(m['rolling_window_days']),
      nPoints: _int(m['n_points']),
      lastEvaluatedDate: _date(m['last_evaluated_date']),
      baselineMae: _double(m['baseline_mae']),
      driftThreshold: _double(m['drift_threshold']),
      driftFactor: _double(m['drift_factor']),
      modelVersion: _str(m['model_version']),
      maeValidation: _double(m['mae_validation']),
      maeValidationPaket: _double(m['mae_validation_paket']),
      rmse: _double(m['rmse']),
      rmsePaket: _double(m['rmse_paket']),
      r2: _double(m['r2']),
      featureImportance: _doubleMap(m['feature_importance']),
      trainedAt: _time(m['trained_at']),
      isDummyData: _bool(m['is_dummy_data']),
      updatedAt: _time(m['updated_at']),
    );
  }

  final String status;
  final double? rollingMae7d;
  final int? rollingWindowDays;

  /// Days in the rolling window (status stays healthy while < 7).
  final int? nPoints;
  final DateTime? lastEvaluatedDate;
  final double? baselineMae;
  final double? driftThreshold;
  final double? driftFactor;
  final String? modelVersion;
  final double? maeValidation;
  final double? maeValidationPaket;
  final double? rmse;
  final double? rmsePaket;
  final double? r2;
  final Map<String, double> featureImportance;
  final DateTime? trainedAt;
  final bool isDummyData;
  final DateTime? updatedAt;

  bool get isDegraded => status == 'degraded';

  /// Threshold stored by the script, else drift_factor (1,15) × baseline.
  double? get threshold {
    if (driftThreshold != null) return driftThreshold;
    if (baselineMae == null) return null;
    return driftFactor == null ? ErrorMetrics.driftThreshold(baselineMae!) : baselineMae! * driftFactor!;
  }
}

/// `model_health_history/{wh}_{YYYYMMDD}`
class ModelHealthPoint {
  const ModelHealthPoint({required this.date, required this.rollingMae7d, this.baselineMae, this.driftThreshold});

  static ModelHealthPoint? fromMap(Map<String, dynamic> m) {
    final date = _date(m['date']);
    final mae = _double(m['rolling_mae_7d']);
    if (date == null || mae == null) return null;
    return ModelHealthPoint(
      date: date,
      rollingMae7d: mae,
      baselineMae: _double(m['baseline_mae']),
      driftThreshold: _double(m['drift_threshold']),
    );
  }

  final DateTime date;
  final double rollingMae7d;
  final double? baselineMae;
  final double? driftThreshold;
}

/// `batch_logs/{wh}_{YYYYMMDD}` (later runs: `_run2`, `_run3`, …)
class BatchLog {
  const BatchLog({
    required this.status,
    this.startedAt,
    this.durationSec,
    this.retryCount = 0,
    this.source,
    this.targetDate,
    this.message,
    this.error,
  });

  static const success = 'success';
  static const skipped = 'skipped';
  static const failed = 'failed';

  static BatchLog? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return BatchLog(
      status: _str(m['status']) ?? 'unknown',
      startedAt: _time(m['started_at']),
      durationSec: _int(m['duration_s']),
      retryCount: _int(m['retries']) ?? 0,
      source: _str(m['source']),
      targetDate: _date(m['target_date']),
      message: _str(m['message']),
      error: _str(m['error']),
    );
  }

  final String status;
  final DateTime? startedAt;

  /// `duration_s`, rounded to whole seconds.
  final int? durationSec;

  /// `retries`
  final int retryCount;
  final String? source;
  final DateTime? targetDate;
  final String? message;
  final String? error;

  /// "skipped" (prediction already existed) is not a failure.
  bool get isSuccess => status == success || status == skipped;
}

/// `dataset_status/{wh}`
class DatasetStatus {
  const DatasetStatus({
    this.lastImportAt,
    this.rangeStart,
    this.rangeEnd,
    this.rowCount,
    this.labeledCount,
    this.lastActualDate,
    this.sourceFile,
    this.isDummyData = false,
  });

  static DatasetStatus? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return DatasetStatus(
      lastImportAt: _time(m['last_import_at']),
      rangeStart: _date(m['range_start']),
      rangeEnd: _date(m['range_end']),
      rowCount: _int(m['row_count']),
      labeledCount: _int(m['labeled_count']),
      lastActualDate: _date(m['last_actual_date']),
      sourceFile: _str(m['source_file']),
      isDummyData: _bool(m['is_dummy_data']),
    );
  }

  final DateTime? lastImportAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int? rowCount;
  final int? labeledCount;
  final DateTime? lastActualDate;
  final String? sourceFile;
  final bool isDummyData;
}

/// Notification types.
class NotifType {
  NotifType._();
  static const deviation = 'deviation';
  static const degraded = 'degraded';
  static const incomplete = 'incomplete';
  static const batch = 'batch';
}

/// `notifications/{type}_{wh}_{YYYYMMDD}`
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.severity,
    this.whId,
    this.targetDate,
    this.createdAt,
    this.audienceRoles = const [],
    this.readBy = const [],
  });

  static AppNotification? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    return AppNotification(
      id: id,
      type: _str(m['type']) ?? NotifType.batch,
      title: _str(m['title']) ?? '',
      body: _str(m['body']) ?? '',
      severity: _str(m['severity']),
      whId: _str(m['wh_id']),
      targetDate: _date(m['target_date']),
      createdAt: _time(m['created_at']),
      audienceRoles: _strList(m['audience_roles']),
      readBy: _strList(m['read_by']),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;

  /// info | warning | error
  final String? severity;
  final String? whId;
  final DateTime? targetDate;
  final DateTime? createdAt;
  final List<String> audienceRoles;

  /// App-owned: uids that have read this notification.
  final List<String> readBy;

  bool isReadBy(String uid) => readBy.contains(uid);
}

/// `users/{uid}` — contract fields: `role`, `name`. Email comes from Firebase
/// Auth; the warehouse defaults to WH-CKG-01 when `wh_id` is absent.
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.email,
    required this.whId,
  });

  static AppUser? fromDoc(String uid, Map<String, dynamic>? m, {String? fallbackEmail}) {
    if (m == null) return null;
    final role = Role.tryParse(_str(m['role']));
    if (role == null) return null;
    return AppUser(
      uid: uid,
      role: role,
      displayName: _str(m['name']) ?? fallbackEmail ?? uid,
      email: fallbackEmail ?? _str(m['email']) ?? '',
      whId: _str(m['wh_id']) ?? 'WH-CKG-01',
    );
  }

  final String uid;
  final Role role;
  final String displayName;
  final String email;
  final String whId;

  /// "AW" from "Admin WIPAS · Shift Lead".
  String get initials {
    final words = displayName.split('·').first.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Label on the role chip (from the design).
  String get roleChipLabel => role.chipLabel;
}

/// `warehouses/{wh}` — `name`, `code`, `timezone`, `created_at`.
class Warehouse {
  const Warehouse({required this.id, required this.name, this.timezone});

  factory Warehouse.fromMap(String id, Map<String, dynamic>? m) =>
      Warehouse(id: _str(m?['code']) ?? id, name: _str(m?['name']) ?? id, timezone: _str(m?['timezone']));

  final String id;
  final String name;
  final String? timezone;
}
