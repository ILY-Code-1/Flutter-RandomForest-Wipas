import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../beranda/beranda_screen.dart';
import '../common/common.dart';

enum PrediksiView { tabel, grafik }

/// Horizon relative to the latest batch: H+1 (latest) or H+2 (next day).
final prediksiHorizonProvider = StateProvider<int>((ref) => 1);
final prediksiViewProvider = StateProvider<PrediksiView>((ref) => PrediksiView.tabel);
final prediksiChartDaysProvider = StateProvider<int>((ref) => 14);

/// Read-only for every role; Supervisor does not see "Faktor pendorong".
class PrediksiScreen extends ConsumerWidget {
  const PrediksiScreen({super.key});

  static const retryKey = 'prediksi';
  static const tableDays = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final data = ref.watch(dashboardProvider);
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<DashboardData>(data,
        offline: offline, lastSync: ref.watch(syncClockProvider), isEmpty: (d) => d.anchor == null);

    return Scaffold(
      appBar: WipasAppBarTop(title: 'Prediksi', subtitle: ref.watch(screenSubtitleProvider)),
      body: WipasStateView<DashboardData>(
        state: state,
        header: Container(
          width: double.infinity,
          color: WipasColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: WipasSpace.sm),
          child: const Align(alignment: Alignment.centerLeft, child: WipasReadOnlyChip()),
        ),
        attempts: ref.watch(retryCountProvider(retryKey)),
        onRetry: () => retryScreen(ref, retryKey, dashboardProviders),
        empty: Column(children: [
          if (offline) ...[WipasOfflineBanner(lastSync: ref.watch(syncClockProvider)), cardGap],
          const WipasEmptyState(
            icon: Icons.insights_outlined,
            title: 'Belum ada prediksi',
            message: 'Prediksi muncul setelah script batch harian dijalankan.',
          ),
        ]),
        builder: (context, d, offline) => _content(context, ref, d, AccessMatrix.canSeeFeatureDrivers(user.role)),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, DashboardData d, bool showDrivers) {
    final horizon = ref.watch(prediksiHorizonProvider);
    final view = ref.watch(prediksiViewProvider);
    final anchor = d.anchor!;
    final targetDate = anchor.targetDate.add(Duration(days: horizon - 1));
    final p = horizon == 1 ? anchor : d.byDate(targetDate);
    final hLabel = 'H+$horizon';

    final horizonControl = WipasSegmentedControl<int>(
      options: const [SegmentOption(1, 'H+1'), SegmentOption(2, 'H+2')],
      selected: horizon,
      onChanged: (v) => ref.read(prediksiHorizonProvider.notifier).state = v,
    );

    if (p == null) {
      return [
        horizonControl,
        cardGap,
        WipasEmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Belum ada prediksi untuk tanggal terpilih',
          message: 'Prediksi ${Fmt.date(targetDate)} ($hLabel) belum dihitung oleh batch.',
          action: WipasSecondaryButton(
            label: 'Kembali ke H+1',
            onPressed: () => ref.read(prediksiHorizonProvider.notifier).state = 1,
          ),
        ),
      ];
    }

    return [
      horizonControl,
      cardGap,
      _TargetCard(p: p, hLabel: hLabel),
      cardGap,
      WipasSegmentedControl<PrediksiView>(
        options: const [
          SegmentOption(PrediksiView.tabel, 'Tabel', icon: Icons.table_chart_outlined),
          SegmentOption(PrediksiView.grafik, 'Grafik', icon: Icons.trending_up),
        ],
        selected: view,
        onChanged: (v) => ref.read(prediksiViewProvider.notifier).state = v,
      ),
      cardGap,
      if (view == PrediksiView.tabel) _HistoryTable(rows: d.window(p.targetDate, tableDays).reversed.toList(), target: p)
      else _ChartCard(d: d, p: p, hLabel: hLabel),
      cardGap,
      InputFeaturesCard(
        title: 'Input model hari ini',
        subtitle: 'Dipakai untuk prediksi ${Fmt.dayMonthYear(p.targetDate)}',
        features: p.inputFeatures,
      ),
      if (showDrivers) ...[
        cardGap,
        FeatureDriversCard(
          cardKey: const Key('faktor-pendorong'),
          importance: p.featureImportance.isNotEmpty ? p.featureImportance : (d.health?.featureImportance ?? const {}),
        ),
      ],
    ];
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.p, required this.hLabel});
  final Prediction p;
  final String hLabel;

  @override
  Widget build(BuildContext context) {
    final dev = p.deviation;
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Target prediksi ($hLabel)', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
              Text(Fmt.date(p.targetDate), style: WipasText.heading.copyWith(fontSize: 18)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.number(p.predicted), style: WipasText.kpi.copyWith(fontSize: 30)),
            Text('paket (Predicted)', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
          ]),
        ]),
        const SizedBox(height: WipasSpace.md),
        if (p.isFallback) ...[
          const WipasStatusBadge(StatusKind.incomplete, label: 'Fallback H-2 · Data Incomplete Warning'),
          const SizedBox(height: WipasSpace.sm),
          Text(
            'Data H-1 terlambat. Model memakai Actual H-2'
            '${p.inputFeatures.actualInboundH2 == null ? '' : ' (${Fmt.number(p.inputFeatures.actualInboundH2)})'} sebagai pengganti.',
            style: WipasText.bodySmall.copyWith(color: WipasColors.warningText),
          ),
        ] else
          const WipasStatusBadge(StatusKind.sehat, label: 'Data H-1 lengkap'),
        const SizedBox(height: WipasSpace.md),
        Text(
          'Dihitung ${p.generatedAt == null ? '—' : Fmt.dateTimeWib(p.generatedAt!)} · Model ${p.modelVersion ?? '—'} · '
          'Sumber: Data ${p.sourceLabel}',
          style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
        ),
        const SizedBox(height: WipasSpace.md),
        WipasStatusBadge(p.needsAttention ? StatusKind.perluPerhatian : StatusKind.normal,
            label: p.needsAttention ? 'Perlu Perhatian' : 'Deviasi normal'),
        const SizedBox(height: WipasSpace.sm),
        Text(
          'Deviasi ${dev == null ? '—' : Fmt.signedPercent(dev)} vs Projection ${Fmt.number(p.projection)}',
          style: WipasText.body,
        ),
      ]),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.rows, required this.target});
  final List<Prediction> rows;
  final Prediction target;

  @override
  Widget build(BuildContext context) {
    final head = WipasText.caption.copyWith(color: WipasColors.textSecondary);
    final num = WipasText.bodySmall.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return WipasCard(
      padding: const EdgeInsets.symmetric(vertical: WipasSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
          child: WipasCardHeader(
            title: 'Riwayat prediksi',
            subtitle: rows.isEmpty ? null : 'Paket per hari · ${Fmt.range(rows.last.targetDate, rows.first.targetDate)}',
          ),
        ),
        const SizedBox(height: WipasSpace.sm),
        Container(
          color: WipasColors.background,
          padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: WipasSpace.sm),
          child: Row(children: [
            Expanded(flex: 13, child: Text('Tanggal', style: head)),
            Expanded(flex: 15, child: Text('Projection', style: head, textAlign: TextAlign.right)),
            Expanded(flex: 15, child: Text('Predicted', style: head, textAlign: TextAlign.right)),
            Expanded(flex: 13, child: Text('Actual', style: head, textAlign: TextAlign.right)),
            Expanded(flex: 13, child: Text('Deviasi', style: head, textAlign: TextAlign.right)),
          ]),
        ),
        for (final r in rows)
          Semantics(
            label: '${Fmt.date(r.targetDate)}: Projection ${Fmt.number(r.projection)}, Predicted ${Fmt.number(r.predicted)}, '
                'Actual ${r.actualInbound == null ? 'belum ada' : Fmt.number(r.actualInbound)}, '
                'Deviasi ${r.deviation == null ? '—' : Fmt.signedPercent(r.deviation!)}'
                '${r.needsAttention ? ', Perlu Perhatian' : ''}',
            excludeSemantics: true,
            child: Container(
              color: r.needsAttention ? WipasColors.warningTint.withValues(alpha: 0.7) : null,
              padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: WipasSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      flex: 13,
                      child: Text(Fmt.dayMonth(r.targetDate), style: WipasText.bodySmall.copyWith(fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 15,
                      child: Text(Fmt.number(r.projection),
                          textAlign: TextAlign.right, style: num.copyWith(color: WipasColors.textSecondary))),
                  Expanded(
                      flex: 15,
                      child: Text(Fmt.number(r.predicted),
                          textAlign: TextAlign.right,
                          style: num.copyWith(color: WipasColors.tealText, fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 13,
                      child: Text(r.actualInbound == null ? '—' : Fmt.number(r.actualInbound),
                          textAlign: TextAlign.right, style: num.copyWith(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 13,
                      child: Text(r.deviation == null ? '—' : Fmt.signedPercent(r.deviation!),
                          textAlign: TextAlign.right,
                          style: num.copyWith(
                              fontWeight: FontWeight.w600,
                              color: r.needsAttention ? WipasColors.warningText : WipasColors.textPrimary))),
                ]),
                if (r.needsAttention) ...[
                  const SizedBox(height: WipasSpace.xs),
                  const WipasStatusBadge(StatusKind.perluPerhatian),
                ] else if (r.actualInbound == null && r.targetDate.isBefore(target.targetDate)) ...[
                  const SizedBox(height: WipasSpace.xs),
                  const WipasStatusBadge(StatusKind.menunggu, label: 'Predicted & Deviasi belum final'),
                ],
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.sm, WipasSpace.lg, 0),
          child: Text(
            'Deviasi = (Predicted − Projection) ÷ Projection. Lebih dari 15% diberi label Perlu Perhatian. '
            'Actual belum ada ditandai (—).',
            style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
          ),
        ),
      ]),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.d, required this.p, required this.hLabel});
  final DashboardData d;
  final Prediction p;
  final String hLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(prediksiChartDaysProvider);
    final points = d.window(p.targetDate, days);
    return WipasChartCard(
      title: 'Projection vs Predicted vs Actual',
      subtitle: points.isEmpty
          ? null
          : 'Paket per hari · $days hari terakhir (${Fmt.range(points.first.targetDate, points.last.targetDate)})',
      chart: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: WipasSpace.sm, children: [
          for (final n in const [7, 14, 30])
            WipasFilterChip(
              label: '$n hari',
              selected: n == days,
              showCheck: true,
              onTap: () => ref.read(prediksiChartDaysProvider.notifier).state = n,
            ),
        ]),
        const SizedBox(height: WipasSpace.md),
        TrendChart(points: points, markDate: p.targetDate, markLabel: hLabel),
      ]),
      legend: const [
        ChartLegendItem('Projection (putus-putus)', WipasColors.seriesProjection, dashed: true),
        ChartLegendItem('Predicted (tebal)', WipasColors.teal),
        ChartLegendItem('Actual (titik)', WipasColors.navy, marker: true),
      ],
      summary: trendSummary(points),
      footer: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(WipasSpace.md),
        decoration: BoxDecoration(
          color: WipasColors.background,
          border: Border.all(color: WipasColors.border),
          borderRadius: BorderRadius.circular(WipasRadius.control),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${Fmt.date(p.targetDate)} ($hLabel)', style: WipasText.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          WipasDataRow(label: 'Projection', value: Fmt.number(p.projection), divider: false),
          WipasDataRow(label: 'Predicted', value: Fmt.number(p.predicted), valueColor: WipasColors.tealText, divider: false),
          WipasDataRow(
              label: 'Actual',
              value: p.actualInbound == null ? '— belum ada' : Fmt.number(p.actualInbound),
              divider: false),
        ]),
      ),
    );
  }
}
