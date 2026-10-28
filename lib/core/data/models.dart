import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/calculators.dart';
import '../domain/role.dart';
import '../format/formatters.dart';

// Null-tolerant readers: missing or mistyped fields become null instead of
// throwing, so the UI can fall back to empty states.

int? _int(Object? v) => v is num ? v.round() : (v is String ? int.tryParse(v) : null);
double? _double(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
bool _bool(Object? v) => v == true || v == 1;
bool? _boolOrNull(Object? v) => v is bool ? v : (v is num ? v != 0 : null);
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};

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

/// Data status values written by the batch script.
class DataStatus {
  DataStatus._();
  static const complete = 'complete';
  static const fallbackH2 = 'incomplete_fallback_h2';
}

/// Ten predictor features (`input_features`). Values may be missing
/// ("Belum diterima") when the H-1 data has not arrived.
class InputFeatures {
  const InputFeatures({
    this.dayOfWeek,
    this.month,
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
        dayOfWeek: _int(m['day_of_week']),
        month: _int(m['month']),
        isCampaign: _boolOrNull(m['is_campaign']),
        isHoliday: _boolOrNull(m['is_holiday']),
        isPayday: _boolOrNull(m['is_payday']),
        pickupRequestH1: _int(m['pickup_request_h1']),
        projectionInbound: _int(m['projection_inbound']),
        backlogH1: _int(m['backlog_h1']),
        actualInboundH2: _int(m['actual_inbound_h2']),
        actualInboundH1: _int(m['actual_inbound_h1']),
      );

  final int? dayOfWeek;
  final int? month;
  final bool? isCampaign;
  final bool? isHoliday;
  final bool? isPayday;
  final int? pickupRequestH1;
  final int? projectionInbound;
  final int? backlogH1;
  final int? actualInboundH2;
  final int? actualInboundH1;
}

/// Display labels for feature keys (used by feature importance bars).
const featureLabels = <String, String>{
  'actual_inbound_h1': 'Actual Inbound H-1',
  'pickup_request_h1': 'Pickup Request H-1',
  'backlog_h1': 'Backlog H-1',
  'actual_inbound_h2': 'Actual Inbound H-2',
  'projection_inbound': 'Projection Inbound',
  'is_campaign': 'Campaign',
  'is_payday': 'Payday',
  'is_holiday': 'Hari Libur',
  'day_of_week': 'Hari',
  'month': 'Bulan',
};

class ManpowerRecommendation {
  const ManpowerRecommendation({required this.counts, this.configSnapshot});

  final ManpowerCounts counts;
  final CapacityConfig? configSnapshot;

  static ManpowerRecommendation? fromMap(Object? raw) {
    final m = _map(raw);
    final rider = _int(m['rider']);
    final driver = _int(m['driver']);
    final opIn = _int(m['op_inbound']);
    final opOut = _int(m['op_outbound']);
    if (rider == null || driver == null || opIn == null || opOut == null) return null;
    final snap = m['config_snapshot'];
    return ManpowerRecommendation(
      counts: ManpowerCounts(rider: rider, driver: driver, opInbound: opIn, opOutbound: opOut),
      configSnapshot: snap is Map ? OperationalConfig.fromMap(_map(snap)).capacity : null,
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
    this.actualInbound,
    this.actualNote,
    this.actualInputBy,
    this.actualInputAt,
    this.dailyErrorPct,
    this.evaluated = false,
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
      actualInbound: _int(m['actual_inbound']),
      actualNote: _str(m['actual_note']),
      actualInputBy: _str(m['actual_input_by']),
      actualInputAt: _time(m['actual_input_at']),
      dailyErrorPct: _double(m['daily_error_pct']),
      evaluated: _bool(m['evaluated']),
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
  final int? actualInbound;
  final String? actualNote;
  final String? actualInputBy;
  final DateTime? actualInputAt;
  final double? dailyErrorPct;
  final bool evaluated;

  bool get isFallback => dataStatus != DataStatus.complete;

  /// Deviation in percent: stored value, else computed from the inputs.
  double? get deviation => deviationPct ?? DeviationCalculator.percent(predicted, projection);

  bool get needsAttention => alert || DeviationCalculator.needsAttention(deviation);

  /// Error vs actual: stored value from the script, else computed.
  double? get errorPct => dailyErrorPct ?? ErrorMetrics.dailyErrorPct(predicted, actualInbound);

  /// Source label ("H-1"/"H-2").
  String get sourceLabel => source ?? (isFallback ? 'H-2' : 'H-1');
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
  final String? updatedBy;
  final DateTime? updatedAt;
}

/// `decision_logs/{auto}` (append-only)
class DecisionLog {
  const DecisionLog({
    required this.id,
    required this.predId,
    required this.whId,
    required this.decidedBy,
    required this.decidedByName,
    required this.decision,
    required this.manpowerFinal,
    this.reason,
    this.decidedAt,
  });

  static const approved = 'approved';
  static const adjusted = 'adjusted';

  static DecisionLog? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    final decision = _str(m['decision']);
    if (decision == null) return null;
    final mp = ManpowerRecommendation.fromMap(m['manpower_final']);
    return DecisionLog(
      id: id,
      predId: _str(m['pred_id']) ?? '',
      whId: _str(m['wh_id']) ?? '',
      decidedBy: _str(m['decided_by']) ?? '',
      decidedByName: _str(m['decided_by_name']) ?? '',
      decision: decision,
      manpowerFinal: mp?.counts,
      reason: _str(m['reason']),
      decidedAt: _time(m['decided_at']),
    );
  }

  final String id;
  final String predId;
  final String whId;
  final String decidedBy;
  final String decidedByName;
  final String decision;
  final ManpowerCounts? manpowerFinal;
  final String? reason;
  final DateTime? decidedAt;

  bool get isAdjusted => decision == adjusted;
}

/// `config_history/{auto}` (append-only)
class ConfigHistoryEntry {
  const ConfigHistoryEntry({
    required this.id,
    required this.changedByName,
    this.changedAt,
    this.oldValues = const {},
    this.newValues = const {},
  });

  factory ConfigHistoryEntry.fromDoc(String id, Map<String, dynamic> m) => ConfigHistoryEntry(
        id: id,
        changedByName: _str(m['changed_by_name']) ?? '',
        changedAt: _time(m['changed_at']),
        oldValues: _doubleMap(m['old_values']),
        newValues: _doubleMap(m['new_values']),
      );

  final String id;
  final String changedByName;
  final DateTime? changedAt;
  final Map<String, double> oldValues;
  final Map<String, double> newValues;
}

/// `model_health/{wh}` (written by the script; app only reads).
class ModelHealth {
  const ModelHealth({
    required this.status,
    this.rollingMae7d,
    this.baselineMae,
    this.driftThreshold,
    this.modelVersion,
    this.maeValidation,
    this.rmse,
    this.r2,
    this.featureImportance = const {},
    this.updatedAt,
  });

  static ModelHealth? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return ModelHealth(
      status: _str(m['status']) ?? 'healthy',
      rollingMae7d: _double(m['rolling_mae_7d']),
      baselineMae: _double(m['baseline_mae']),
      driftThreshold: _double(m['drift_threshold']),
      modelVersion: _str(m['model_version']),
      maeValidation: _double(m['mae_validation']),
      rmse: _double(m['rmse']),
      r2: _double(m['r2']),
      featureImportance: _doubleMap(m['feature_importance']),
      updatedAt: _time(m['updated_at']),
    );
  }

  final String status;
  final double? rollingMae7d;
  final double? baselineMae;
  final double? driftThreshold;
  final String? modelVersion;
  final double? maeValidation;
  final double? rmse;
  final double? r2;
  final Map<String, double> featureImportance;
  final DateTime? updatedAt;

  bool get isDegraded => status == 'degraded';

  /// Threshold stored by the script, else 1.15 × baseline.
  double? get threshold =>
      driftThreshold ?? (baselineMae == null ? null : ErrorMetrics.driftThreshold(baselineMae!));
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

/// `batch_logs/{wh}_{YYYYMMDD}`
class BatchLog {
  const BatchLog({
    required this.status,
    this.startedAt,
    this.durationSec,
    this.retryCount = 0,
    this.source,
    this.targetDate,
    this.message,
  });

  static BatchLog? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return BatchLog(
      status: _str(m['status']) ?? 'unknown',
      startedAt: _time(m['started_at']),
      durationSec: _int(m['duration_sec']),
      retryCount: _int(m['retry_count']) ?? 0,
      source: _str(m['source']),
      targetDate: _date(m['target_date']),
      message: _str(m['message']),
    );
  }

  final String status;
  final DateTime? startedAt;
  final int? durationSec;
  final int retryCount;
  final String? source;
  final DateTime? targetDate;
  final String? message;

  bool get isSuccess => status == 'success';
}

/// `dataset_status/{wh}`
class DatasetStatus {
  const DatasetStatus({this.lastImportAt, this.rangeStart, this.rangeEnd, this.rowCount, this.sourceFile});

  static DatasetStatus? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return DatasetStatus(
      lastImportAt: _time(m['last_import_at']),
      rangeStart: _date(m['range_start']),
      rangeEnd: _date(m['range_end']),
      rowCount: _int(m['row_count']),
      sourceFile: _str(m['source_file']),
    );
  }

  final DateTime? lastImportAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int? rowCount;
  final String? sourceFile;
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
    this.whId,
    this.targetDate,
    this.createdAt,
    this.audienceRoles = const [],
  });

  static AppNotification? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    return AppNotification(
      id: id,
      type: _str(m['type']) ?? NotifType.batch,
      title: _str(m['title']) ?? '',
      body: _str(m['body']) ?? '',
      whId: _str(m['wh_id']),
      targetDate: _date(m['target_date']),
      createdAt: _time(m['created_at']),
      audienceRoles: (m['audience_roles'] is List)
          ? (m['audience_roles'] as List).whereType<String>().toList()
          : const [],
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final String? whId;
  final DateTime? targetDate;
  final DateTime? createdAt;
  final List<String> audienceRoles;
}

/// `users/{uid}`
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.email,
    required this.whId,
    this.jobTitle,
  });

  static AppUser? fromDoc(String uid, Map<String, dynamic>? m, {String? fallbackEmail}) {
    if (m == null) return null;
    final role = Role.tryParse(_str(m['role']));
    if (role == null) return null;
    return AppUser(
      uid: uid,
      role: role,
      displayName: _str(m['display_name']) ?? fallbackEmail ?? uid,
      email: _str(m['email']) ?? fallbackEmail ?? '',
      whId: _str(m['wh_id']) ?? 'WH-CKG-01',
      jobTitle: _str(m['job_title']),
    );
  }

  final String uid;
  final Role role;
  final String displayName;
  final String email;
  final String whId;
  final String? jobTitle;

  /// "AW" from "Admin WIPAS · Shift Lead".
  String get initials {
    final words = displayName.split('·').first.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Label on the role chip (e.g. "Manajer Warehouse").
  String get roleChipLabel => jobTitle ?? role.label;
}

/// `warehouses/{wh}`
class Warehouse {
  const Warehouse({required this.id, required this.name});

  factory Warehouse.fromMap(String id, Map<String, dynamic>? m) =>
      Warehouse(id: id, name: _str(m?['name']) ?? id);

  final String id;
  final String name;
}
