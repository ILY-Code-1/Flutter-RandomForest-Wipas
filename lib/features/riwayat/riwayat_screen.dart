import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/calculators.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/role.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';
import '../manpower/manpower_screen.dart';
import 'csv_export.dart';

final csvSaverProvider = Provider<CsvSaver>((ref) => const CsvSaver());

/// Selected range: end date (null = latest batch) and number of days.
final riwayatRangeProvider = StateProvider.autoDispose<({DateTime? end, int days})>((ref) => (end: null, days: 7));

class RiwayatData {
  const RiwayatData({required this.rows, required this.decisions, required this.end, required this.days});
  final List<Prediction> rows; // newest first
  final Map<String, DecisionLog> decisions;
  final DateTime end;
  final int days;
  DateTime get start => end.subtract(Duration(days: days - 1));
}

final riwayatDataProvider = Provider.autoDispose<AsyncValue<RiwayatData>>((ref) {
  final role = ref.watch(currentUserProvider)?.role ?? Role.viewer;
  final range = ref.watch(riwayatRangeProvider);
  final latest = ref.watch(latestPredictionProvider);
  if (!latest.hasValue) {
    return latest.hasError ? AsyncError(latest.error!, latest.stackTrace ?? StackTrace.empty) : const AsyncLoading();
  }
  final DateTime today = ref.watch(todayProvider);
  final DateTime end = range.end ?? latest.requireValue?.targetDate ?? today;
  final rows = ref.watch(predictionsInRangeProvider((end: end, days: range.days)));
  // Viewers may not read decision_logs (security rules); never query them.
  final decisions = AccessMatrix.canSeeDecisions(role)
      ? ref.watch(recentDecisionsProvider)
      : const AsyncData<List<DecisionLog>>([]);
  return combineAsync([rows, decisions], () {
    final latestByPred = <String, DecisionLog>{};
    for (final d in decisions.requireValue) {
      latestByPred.putIfAbsent(d.predId, () => d); // list is newest first
    }
    final list = [...rows.requireValue]..sort((a, b) => b.targetDate.compareTo(a.targetDate));
    return RiwayatData(rows: list, decisions: latestByPred, end: end, days: range.days);
  });
});

enum ExportStatus { idle, preparing, success, failed }

class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  ExportStatus _export = ExportStatus.idle;
  String? _fileName;
  int _fileRows = 0;
  File? _file;

  Future<void> _runExport(RiwayatData d) async {
    setState(() => _export = ExportStatus.preparing);
    try {
      final csv = CsvExport.build(d.rows, d.decisions);
      final name = CsvExport.fileName(d.start, d.end);
      final saver = ref.read(csvSaverProvider);
      final file = await saver.write(name, csv);
      if (!mounted) return;
      setState(() {
        _export = ExportStatus.success;
        _fileName = name;
        _fileRows = d.rows.length;
        _file = file;
      });
      await saver.share(file);
    } catch (_) {
      if (mounted) setState(() => _export = ExportStatus.failed);
    }
  }

  Future<void> _pickRange(RiwayatData d) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: d.end.subtract(const Duration(days: 730)),
      lastDate: d.end,
      initialDateRange: DateTimeRange(start: d.start, end: d.end),
      locale: const Locale('id', 'ID'),
    );
    if (picked == null) return;
    final end = DateTime.utc(picked.end.year, picked.end.month, picked.end.day);
    final start = DateTime.utc(picked.start.year, picked.start.month, picked.start.day);
    // Bounded read: at most 31 days per query.
    final days = (end.difference(start).inDays + 1).clamp(1, 31);
    ref.read(riwayatRangeProvider.notifier).state = (end: end, days: days);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<RiwayatData>(ref.watch(riwayatDataProvider),
        offline: offline, lastSync: ref.watch(syncClockProvider));

    return Scaffold(
      appBar: WipasAppBarSub(
        title: AccessMatrix.canExportCsv(user.role) ? 'Riwayat & Export' : 'Riwayat',
        subtitle: ref.watch(screenSubtitleProvider),
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.lainnya),
      ),
      body: WipasStateView<RiwayatData>(
        state: state,
        attempts: ref.watch(retryCountProvider('riwayat')),
        onRetry: () => retryScreen(ref, 'riwayat', [latestPredictionProvider, predictionsInRangeProvider, recentDecisionsProvider]),
        empty: const SizedBox.shrink(),
        builder: (context, d, offline) => _content(d, offline, user.role),
      ),
    );
  }

  List<Widget> _content(RiwayatData d, bool offline, Role role) {
    final showDecisions = AccessMatrix.canSeeDecisions(role);
    final days = ref.watch(riwayatRangeProvider).days;
    return [
      WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Rentang tanggal', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary, fontSize: 14)),
          const SizedBox(height: WipasSpace.sm),
          InkWell(
            onTap: () => _pickRange(d),
            borderRadius: BorderRadius.circular(WipasRadius.control),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
              decoration: BoxDecoration(
                border: Border.all(color: WipasColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(WipasRadius.control),
              ),
              child: Row(children: [
                Expanded(child: Text(Fmt.range(d.start, d.end), style: WipasText.heading)),
                const Icon(Icons.calendar_today_outlined, color: WipasColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: WipasSpace.xs),
          Wrap(spacing: WipasSpace.sm, children: [
            for (final n in const [7, 14])
              WipasFilterChip(
                label: '$n hari',
                selected: days == n,
                showCheck: true,
                onTap: () => ref.read(riwayatRangeProvider.notifier).state = (end: null, days: n),
              ),
          ]),
        ]),
      ),
      cardGap,
      if (AccessMatrix.canExportCsv(role)) ...[
        _exportCard(d, offline),
        cardGap,
      ],
      WipasCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(WipasSpace.lg),
            child: WipasCardHeader(
              title: showDecisions ? 'Prediksi, actual & keputusan' : 'Prediksi & actual',
              subtitle: 'Data aktif dikueri 2 tahun; data lebih lama diarsipkan.',
            ),
          ),
          if (d.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(WipasSpace.lg, 0, WipasSpace.lg, WipasSpace.lg),
              child: Text('Tidak ada data pada rentang ini.', style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
            ),
          for (final p in d.rows) _HistoryRow(p: p, decision: d.decisions[p.id], showDecision: showDecisions),
        ]),
      ),
    ];
  }

  Widget _exportCard(RiwayatData d, bool offline) {
    final busy = _export == ExportStatus.preparing;
    Widget? status;
    switch (_export) {
      case ExportStatus.success:
        status = WipasAlertBanner(
          kind: AlertKind.success,
          title: 'File siap diunduh',
          body: '$_fileName · $_fileRows baris',
          action: _file == null
              ? null
              : WipasTextButton(
                  label: 'Bagikan',
                  icon: Icons.share_outlined,
                  onPressed: () => ref.read(csvSaverProvider).share(_file!),
                ),
        );
      case ExportStatus.failed:
        status = const WipasAlertBanner(
          kind: AlertKind.danger,
          icon: Icons.error_outline,
          title: 'Export gagal',
          body: 'Tidak dapat menyiapkan file. Periksa koneksi lalu coba lagi.',
        );
      case ExportStatus.preparing:
        status = const WipasAlertBanner(
          kind: AlertKind.info,
          icon: Icons.hourglass_top,
          title: 'Menyiapkan file…',
          body: 'Mengumpulkan prediksi, actual, deviasi, dan keputusan.',
        );
      case ExportStatus.idle:
        status = null;
    }
    final label = switch (_export) {
      ExportStatus.success => 'Export lagi',
      ExportStatus.failed => 'Coba lagi',
      _ => 'Export CSV',
    };
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WipasCardHeader(title: 'Export CSV'),
        const SizedBox(height: WipasSpace.sm),
        if (status == null)
          Text('${d.rows.length} baris: tanggal, Predicted, Actual, keputusan alokasi.',
              style: WipasText.body.copyWith(color: WipasColors.textSecondary))
        else
          status,
        const SizedBox(height: WipasSpace.md),
        WipasPrimaryButton(
          key: const Key('btn-export'),
          label: label,
          icon: Icons.download,
          loading: busy,
          disabledReason: offline ? offlineActionHint : null,
          onPressed: d.rows.isEmpty ? null : () => _runExport(d),
        ),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.p, required this.decision, required this.showDecision});
  final Prediction p;
  final DecisionLog? decision;
  final bool showDecision;

  @override
  Widget build(BuildContext context) {
    final dev = p.deviation;
    final rec = p.manpower?.counts;
    return Container(
      padding: const EdgeInsets.all(WipasSpace.lg),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: WipasColors.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(Fmt.dateNoYear(p.targetDate), style: WipasText.heading)),
          if (p.needsAttention && dev != null)
            WipasStatusBadge(StatusKind.perluPerhatian, label: 'Perlu Perhatian ${Fmt.signedPercent(dev)}'),
        ]),
        const SizedBox(height: WipasSpace.sm),
        Row(children: [
          Expanded(child: _kv('Predicted', Fmt.number(p.predicted), WipasColors.tealText)),
          Expanded(child: _kv('Actual', p.actualInbound == null ? '—' : Fmt.number(p.actualInbound), WipasColors.navy)),
        ]),
        if (showDecision) ...[
          const SizedBox(height: WipasSpace.sm),
          if (decision == null)
            const WipasInlineStatus(StatusKind.menunggu)
          else if (decision!.isAdjusted) ...[
            const WipasInlineStatus(StatusKind.disesuaikan),
            Text(
              '${adjustmentSummary(decision!.manpowerFinal ?? rec ?? const ManpowerCounts(rider: 0, driver: 0, opInbound: 0, opOutbound: 0), rec)}'
              '${(decision!.reason ?? '').isEmpty ? '' : ' · alasan: ${decision!.reason}'}',
              style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
            ),
          ] else
            const WipasInlineStatus(StatusKind.disetujui),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        Text(v, style: WipasText.heading.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
      ]);
}
