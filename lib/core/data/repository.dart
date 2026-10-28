import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/calculators.dart';
import '../format/formatters.dart';
import 'models.dart';

/// Collection names (see `docs/firestore_schema.md`).
class Col {
  Col._();
  static const predictions = 'predictions';
  static const dailyData = 'daily_data';
  static const operationalConfigs = 'operational_configs';
  static const modelHealth = 'model_health';
  static const modelHealthHistory = 'model_health_history';
  static const batchLogs = 'batch_logs';
  static const datasetStatus = 'dataset_status';
  static const notifications = 'notifications';
  static const users = 'users';
  static const notificationReads = 'notification_reads';
  static const configHistory = 'config_history';
  static const decisionLogs = 'decision_logs';
  static const warehouses = 'warehouses';
}

/// A value plus whether it was served from the local cache.
class Snap<T> {
  const Snap(this.data, {this.fromCache = false});
  final T data;
  final bool fromCache;
}

/// Thrown when a write is attempted on data that does not exist yet.
class MissingDocumentException implements Exception {
  const MissingDocumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firestore access for one warehouse. All list reads are bounded by a date
/// range and/or a `limit` to stay within the Spark free read quota.
class WipasRepository {
  WipasRepository(this.db, this.whId);

  final FirebaseFirestore db;
  final String whId;

  static const _meta = true; // includeMetadataChanges

  CollectionReference<Map<String, dynamic>> _c(String name) => db.collection(name);

  // ---------------------------------------------------------------- reads

  /// Predictions with `target_date` in [start, end], newest first.
  Stream<Snap<List<Prediction>>> watchPredictions(DateTime start, DateTime end, {int limit = 31}) {
    return _c(Col.predictions)
        .where('wh_id', isEqualTo: whId)
        .where('target_date', isGreaterThanOrEqualTo: Fmt.isoDate(start))
        .where('target_date', isLessThanOrEqualTo: Fmt.isoDate(end))
        .orderBy('target_date', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: _meta)
        .map((s) => Snap(
              s.docs.map((d) => Prediction.fromDoc(d.id, d.data())).whereType<Prediction>().toList(),
              fromCache: s.metadata.isFromCache,
            ));
  }

  /// The newest prediction (the batch's H+1 target), or null.
  Stream<Snap<Prediction?>> watchLatestPrediction() {
    return _c(Col.predictions)
        .where('wh_id', isEqualTo: whId)
        .orderBy('target_date', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: _meta)
        .map((s) => Snap(
              s.docs.isEmpty ? null : Prediction.fromDoc(s.docs.first.id, s.docs.first.data()),
              fromCache: s.metadata.isFromCache,
            ));
  }

  Stream<Snap<OperationalConfig?>> watchConfig() => _c(Col.operationalConfigs)
      .doc(whId)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(s.data() == null ? null : OperationalConfig.fromMap(s.data()!),
          fromCache: s.metadata.isFromCache));

  Stream<Snap<ModelHealth?>> watchModelHealth() => _c(Col.modelHealth)
      .doc(whId)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(ModelHealth.fromMap(s.data()), fromCache: s.metadata.isFromCache));

  /// Rolling-MAE history (oldest → newest) for the last [days] days up to [end].
  Stream<Snap<List<ModelHealthPoint>>> watchModelHealthHistory(DateTime end, {int days = 30}) {
    final start = end.subtract(Duration(days: days - 1));
    return _c(Col.modelHealthHistory)
        .where('wh_id', isEqualTo: whId)
        .where('date', isGreaterThanOrEqualTo: Fmt.isoDate(start))
        .where('date', isLessThanOrEqualTo: Fmt.isoDate(end))
        .orderBy('date')
        .limit(days)
        .snapshots(includeMetadataChanges: _meta)
        .map((s) => Snap(
              s.docs.map((d) => ModelHealthPoint.fromMap(d.data())).whereType<ModelHealthPoint>().toList(),
              fromCache: s.metadata.isFromCache,
            ));
  }

  Stream<Snap<BatchLog?>> watchLatestBatch() => _c(Col.batchLogs)
      .where('wh_id', isEqualTo: whId)
      .orderBy('started_at', descending: true)
      .limit(1)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(s.docs.isEmpty ? null : BatchLog.fromMap(s.docs.first.data()),
          fromCache: s.metadata.isFromCache));

  Stream<Snap<DatasetStatus?>> watchDatasetStatus() => _c(Col.datasetStatus)
      .doc(whId)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(DatasetStatus.fromMap(s.data()), fromCache: s.metadata.isFromCache));

  /// Decisions for one prediction, newest first.
  Stream<Snap<List<DecisionLog>>> watchDecisionsFor(String predId) => _c(Col.decisionLogs)
      .where('pred_id', isEqualTo: predId)
      .orderBy('decided_at', descending: true)
      .limit(20)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(
            s.docs.map((d) => DecisionLog.fromDoc(d.id, d.data())).whereType<DecisionLog>().toList(),
            fromCache: s.metadata.isFromCache,
          ));

  /// Recent decisions of this warehouse, newest first.
  Stream<Snap<List<DecisionLog>>> watchRecentDecisions({int limit = 60}) => _c(Col.decisionLogs)
      .where('wh_id', isEqualTo: whId)
      .orderBy('decided_at', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(
            s.docs.map((d) => DecisionLog.fromDoc(d.id, d.data())).whereType<DecisionLog>().toList(),
            fromCache: s.metadata.isFromCache,
          ));

  Stream<Snap<List<ConfigHistoryEntry>>> watchConfigHistory({int limit = 10}) => _c(Col.configHistory)
      .where('wh_id', isEqualTo: whId)
      .orderBy('changed_at', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(
            s.docs.map((d) => ConfigHistoryEntry.fromDoc(d.id, d.data())).toList(),
            fromCache: s.metadata.isFromCache,
          ));

  /// Notifications visible to [roleId], newest first.
  Stream<Snap<List<AppNotification>>> watchNotifications(String roleId, {int limit = 30}) => _c(Col.notifications)
      .where('audience_roles', arrayContains: roleId)
      .orderBy('created_at', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: _meta)
      .map((s) => Snap(
            s.docs
                .map((d) => AppNotification.fromDoc(d.id, d.data()))
                .whereType<AppNotification>()
                .where((n) => n.whId == null || n.whId == whId)
                .toList(),
            fromCache: s.metadata.isFromCache,
          ));

  /// IDs of notifications already read by [uid].
  Stream<Set<String>> watchReadIds(String uid) => _c(Col.users)
      .doc(uid)
      .collection(Col.notificationReads)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  Stream<Warehouse> watchWarehouse() =>
      _c(Col.warehouses).doc(whId).snapshots().map((s) => Warehouse.fromMap(whId, s.data()));

  // --------------------------------------------------------------- writes

  /// Writes only the app-owned `actual_*` fields of an existing prediction.
  Future<void> saveActual({
    required DateTime targetDate,
    required int actual,
    String? note,
    required String uid,
  }) async {
    final ref = _c(Col.predictions).doc(Prediction.docId(whId, targetDate));
    final snap = await ref.get();
    if (!snap.exists) {
      throw MissingDocumentException(
          'Belum ada dokumen prediksi untuk ${Fmt.date(targetDate)}. Jalankan batch prediksi lebih dulu.');
    }
    await ref.update({
      'actual_inbound': actual,
      'actual_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      'actual_input_by': uid,
      'actual_input_at': FieldValue.serverTimestamp(),
    });
  }

  /// Appends a manpower decision (append-only log).
  Future<void> addDecision({
    required String predId,
    required String uid,
    required String name,
    required String decision,
    required ManpowerCounts manpowerFinal,
    String? reason,
  }) {
    return _c(Col.decisionLogs).add({
      'pred_id': predId,
      'wh_id': whId,
      'decided_by': uid,
      'decided_by_name': name,
      'decision': decision,
      'manpower_final': manpowerFinal.toMap(),
      'reason': reason,
      'decided_at': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the capacity config and appends `config_history` atomically.
  Future<void> saveConfig({
    required CapacityConfig newValues,
    required String uid,
    required String name,
  }) {
    final cfgRef = _c(Col.operationalConfigs).doc(whId);
    final histRef = _c(Col.configHistory).doc();
    return db.runTransaction((tx) async {
      final current = await tx.get(cfgRef);
      final old = current.data() == null
          ? CapacityConfig.defaults
          : OperationalConfig.fromMap(current.data()!).capacity;
      final data = {
        ...newValues.toMap(),
        'rounding': 'ceil',
        'updated_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (current.exists) {
        tx.update(cfgRef, data);
      } else {
        tx.set(cfgRef, data);
      }
      tx.set(histRef, {
        'wh_id': whId,
        'changed_by': uid,
        'changed_by_name': name,
        'changed_at': FieldValue.serverTimestamp(),
        'old_values': old.toMap(),
        'new_values': newValues.toMap(),
      });
    });
  }

  /// Marks notifications as read for [uid].
  Future<void> markRead(String uid, Iterable<String> notifIds) async {
    final batch = db.batch();
    final reads = _c(Col.users).doc(uid).collection(Col.notificationReads);
    for (final id in notifIds) {
      batch.set(reads.doc(id), {'read_at': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }
}
