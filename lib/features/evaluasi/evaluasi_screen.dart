import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/role.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../beranda/beranda_screen.dart';
import '../common/common.dart';
import '../prediksi/prediksi_screen.dart';

class EvaluasiData {
  const EvaluasiData({
    required this.health,
    required this.history,
    required this.predictions,
    required this.batch,
    required this.dataset,
  });

  final ModelHealth? health;
  final List<ModelHealthPoint> history;
  final List<Prediction> predictions;
  final BatchLog? batch;
  final DatasetStatus? dataset;
}

final evaluasiDataProvider = Provider.autoDispose<AsyncValue<EvaluasiData>>((ref) {
  final dash = ref.watch(dashboardProvider);
  final DateTime today = ref.watch(todayProvider);
  final end = dash.valueOrNull?.anchor?.targetDate ?? today;
  final history = ref.watch(modelHealthHistoryProvider(end));
  final batch = ref.watch(latestBatchProvider);
  final dataset = ref.watch(datasetStatusProvider);
  return combineAsync([dash, history, batch, dataset], () {
    final d = dash.requireValue;
    return EvaluasiData(
      health: d.health,
      history: history.requireValue,
      predictions: d.history,
      batch: batch.requireValue,
      dataset: dataset.requireValue,
    );
  });
});

/// Target thresholds for validation metrics (thesis targets).
class MetricTargets {
  MetricTargets._();
  static const maxMae = 10.0;
  static const maxRmse = 15.0;
  static const minR2 = 0.85;
}

/// Weekly comparison of Projection vs Predicted error against Actual.
class WeekRow {
  const WeekRow(this.start, this.end, this.projMape, this.predMape, this.daysOver, this.days);
  final DateTime start;
  final DateTime end;
  final double projMape;
  final double predMape;
  final int daysOver;
  final int days;
}

/// Groups evaluated predictions (with actual) into Monday-based weeks.
List<WeekRow> weeklyProjectionEval(List<Prediction> predictions) {
  final evaluated = predictions.where((p) => p.actualInbound != null && p.actualInbound! > 0 && p.predicted != null && p.projection != null).toList()
    ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  final groups = <DateTime, List<Prediction>>{};
  for (final p in evaluated) {
    final monday = p.targetDate.subtract(Duration(days: p.targetDate.weekday - 1));
    groups.putIfAbsent(monday, () => []).add(p);
  }
  return [
    for (final e in groups.entries)
      WeekRow(
        e.value.first.targetDate,
        e.value.last.targetDate,
        _mean(e.value.map((p) => (p.projection! - p.actualInbound!).abs() / p.actualInbound! * 100)),
        _mean(e.value.map((p) => (p.predicted! - p.actualInbound!).abs() / p.actualInbound! * 100)),
        e.value.where((p) => p.needsAttention).length,
        e.value.length,
      ),
  ];
}

double _mean(Iterable<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

class EvaluasiScreen extends ConsumerWidget {
  const EvaluasiScreen({super.key});

  static const retryKey = 'evaluasi';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<EvaluasiData>(ref.watch(evaluasiDataProvider),
        offline: offline, lastSync: ref.watch(syncClockProvider), isEmpty: (d) => d.health == null);
    final readOnly = AccessMatrix.isReadOnly(user.role, Routes.evaluasi);

    return Scaffold(
      appBar: WipasAppBarTop(title: 'Evaluasi', subtitle: ref.watch(screenSubtitleProvider)),
      body: WipasStateView<EvaluasiData>(
        state: state,
        header: readOnly
            ? Container(
                width: double.infinity,
                color: WipasColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: WipasSpace.sm),
                child: const Align(alignment: Alignment.centerLeft, child: WipasReadOnlyChip()),
              )
            : null,
        attempts: ref.watch(retryCountProvider(retryKey)),
        onRetry: () => retryScreen(ref, retryKey,
            [...dashboardProviders, modelHealthHistoryProvider, latestBatchProvider, datasetStatusProvider]),
        empty: Column(children: [
          if (offline) ...[WipasOfflineBanner(lastSync: ref.watch(syncClockProvider)), cardGap],
          const WipasEmptyState(
            icon: Icons.analytics_outlined,
            title: 'Belum ada evaluasi model',
            message: 'Kesehatan model muncul setelah model dilatih dan batch evaluasi pertama berjalan.',
          ),
        ]),
        builder: (context, d, offline) => _content(context, ref, d, user.role),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, EvaluasiData d, Role role) {
    final h = d.health!;
    return [
      _HealthCard(
        health: h,
        onFeatureImportance: () {
          ref.read(prediksiViewProvider.notifier).state = PrediksiView.tabel;
          context.go(Routes.prediksi);
        },
      ),
      cardGap,
      _RollingMaeCard(history: d.history, health: h),
      cardGap,
      _ValidationCard(health: h),
      cardGap,
      _ProjectionEvalCard(weeks: weeklyProjectionEval(d.predictions)),
      cardGap,
      _BatchCard(batch: d.batch),
      cardGap,
      _DatasetCard(dataset: d.dataset),
    ];
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health, required this.onFeatureImportance});
  final ModelHealth health;
  final VoidCallback onFeatureImportance;

  @override
  Widget build(BuildContext context) {
    final h = health;
    final degraded = h.isDegraded;
    Widget stat(String k, String v, {Color? color, bool big = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            Text(v, style: (big ? WipasText.kpi : WipasText.kpi.copyWith(fontSize: 20, height: 1.3)).copyWith(color: color)),
          ],
        );
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Status model · ${h.modelVersion ?? '—'}', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
              Text('Kesehatan model', style: WipasText.heading.copyWith(fontSize: 18)),
            ]),
          ),
          WipasStatusBadge(degraded ? StatusKind.degraded : StatusKind.sehat),
        ]),
        const SizedBox(height: WipasSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: stat('Rolling MAE 7 hari', Fmt.percent(h.rollingMae7d),
                  color: degraded ? WipasColors.danger : WipasColors.textPrimary, big: true)),
          Expanded(child: stat('Baseline', Fmt.percent(h.baselineMae))),
          Expanded(child: stat('Ambang drift', Fmt.percent(h.threshold))),
        ]),
        const SizedBox(height: WipasSpace.md),
        Text(
          degraded
              ? 'Rolling MAE 7 hari ${Fmt.percent(h.rollingMae7d)} melampaui ambang drift ${Fmt.percent(h.threshold)}. '
                  'Prediksi tetap tampil sebagai rekomendasi; keputusan akhir tetap pada manusia.'
              : 'Rolling MAE 7 hari ${Fmt.percent(h.rollingMae7d)} masih di bawah ambang drift ${Fmt.percent(h.threshold)}.',
          style: WipasText.body,
        ),
        const SizedBox(height: WipasSpace.sm),
        Text(
          'Aturan: Model Degraded muncul bila Rolling MAE 7 hari lebih dari 1,15 × baseline '
          '(${Fmt.percent(h.baselineMae)} × 1,15 ≈ ${Fmt.percent(h.threshold)}).',
          style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
        ),
        if (degraded) ...[
          const SizedBox(height: WipasSpace.md),
          WipasAlertBanner(
            kind: AlertKind.danger,
            title: 'Rolling MAE melampaui ambang. Disarankan review & retraining manual',
            body: 'Retraining tidak berjalan otomatis. Tim memutuskan setelah meninjau penyebab drift.',
            action: OutlinedButton.icon(
              onPressed: onFeatureImportance,
              style: OutlinedButton.styleFrom(
                foregroundColor: WipasColors.dangerText,
                side: const BorderSide(color: WipasColors.danger, width: 1.5),
                backgroundColor: WipasColors.surface,
              ),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Lihat feature importance'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _RollingMaeCard extends StatelessWidget {
  const _RollingMaeCard({required this.history, required this.health});
  final List<ModelHealthPoint> history;
  final ModelHealth health;

  @override
  Widget build(BuildContext context) {
    final base = health.baselineMae;
    final thr = health.threshold;
    final last = history.isEmpty ? null : history.last;
    final values = [for (final p in history) p.rollingMae7d, ?base, ?thr];
    final minY = values.isEmpty ? 0.0 : (values.reduce(math.min) - 1).floorToDouble();
    final maxY = values.isEmpty ? 10.0 : (values.reduce(math.max) + 1).ceilToDouble();
    final start = history.isEmpty ? DateTime.utc(2000) : history.first.date;
    double x(DateTime d) => d.difference(start).inDays.toDouble();
    final maxX = history.isEmpty ? 1.0 : x(history.last.date);

    final summary = last == null
        ? 'Belum ada riwayat Rolling MAE.'
        : 'Grafik Rolling MAE 7 hari, ${history.length} titik. Terakhir ${Fmt.date(last.date)} '
            '${Fmt.percent(last.rollingMae7d)}; baseline ${Fmt.percent(base)}; ambang drift ${Fmt.percent(thr)}.';

    return WipasChartCard(
      title: 'Rolling MAE 7 hari',
      subtitle: history.isEmpty ? null : '30 hari terakhir · ${Fmt.range(history.first.date, history.last.date)}',
      chart: history.isEmpty
          ? const SizedBox(height: 120, child: Center(child: Text('Belum ada riwayat.', style: WipasText.bodySmall)))
          : SizedBox(
              height: 190,
              child: Padding(
                // Right padding keeps the baseline/threshold labels outside
                // the plot so lines never cover them.
                padding: const EdgeInsets.only(right: 64),
                child: LineChart(LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.none(),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => const FlLine(color: WipasColors.divider, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 1,
                        getTitlesWidget: (v, _) => Text(Fmt.percent(v, digits: 0), style: WipasText.caption),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: math.max(1, (maxX / 3).ceilToDouble()),
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(Fmt.dayMonth(start.add(Duration(days: v.round()))), style: WipasText.caption),
                        ),
                      ),
                    ),
                  ),
                  rangeAnnotations: thr == null
                      ? const RangeAnnotations()
                      : RangeAnnotations(horizontalRangeAnnotations: [
                          if (maxY > thr)
                            HorizontalRangeAnnotation(y1: thr, y2: maxY, color: WipasColors.dangerTint.withValues(alpha: 0.6)),
                        ]),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (base != null)
                      HorizontalLine(
                        y: base,
                        color: WipasColors.textSecondary,
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(left: 6),
                          style: WipasText.caption.copyWith(color: WipasColors.textSecondary),
                          labelResolver: (_) => 'Baseline\n${Fmt.percent(base)}',
                        ),
                      ),
                    if (thr != null)
                      HorizontalLine(
                        y: thr,
                        color: WipasColors.danger,
                        strokeWidth: 1.5,
                        dashArray: [2, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(left: 6),
                          style: WipasText.caption.copyWith(color: WipasColors.dangerText),
                          labelResolver: (_) => 'Ambang\ndrift ${Fmt.percent(thr)}',
                        ),
                      ),
                  ]),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final p in history) FlSpot(x(p.date), p.rollingMae7d)],
                      color: WipasColors.primaryLight,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (s, _) => s.x == maxX,
                        getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: (thr != null && s.y > thr) ? WipasColors.danger : WipasColors.primaryLight,
                            strokeWidth: 0),
                      ),
                    ),
                  ],
                )),
              ),
            ),
      legend: const [
        ChartLegendItem('Rolling MAE', WipasColors.primaryLight),
        ChartLegendItem('Baseline', WipasColors.textSecondary, dashed: true),
        ChartLegendItem('Ambang drift', WipasColors.danger, dotted: true),
        ChartLegendItem('Area di atas ambang', WipasColors.danger, area: true),
      ],
      summary: summary,
      footer: last == null
          ? null
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(WipasSpace.md),
              decoration: BoxDecoration(
                color: WipasColors.background,
                border: Border.all(color: WipasColors.border),
                borderRadius: BorderRadius.circular(WipasRadius.control),
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${Fmt.date(last.date)}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: 'Rolling MAE ${Fmt.percent(last.rollingMae7d)}'
                        '${thr == null ? '' : ' · ${Fmt.decimal((last.rollingMae7d - thr).abs())} poin '
                            '${last.rollingMae7d > thr ? 'di atas' : 'di bawah'} ambang'}',
                  ),
                ]),
                style: WipasText.bodySmall,
              ),
            ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.health});
  final ModelHealth health;

  @override
  Widget build(BuildContext context) {
    Widget metric(String label, double? value, String display, double target, String targetLabel, bool lowerIsBetter,
        double scaleMax) {
      final ok = value != null && (lowerIsBetter ? value <= target : value >= target);
      return Padding(
        padding: const EdgeInsets.only(bottom: WipasSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: WipasText.body.copyWith(color: WipasColors.textSecondary))),
            Text(display, style: WipasText.kpi.copyWith(fontSize: 22, height: 1.3)),
          ]),
          const SizedBox(height: WipasSpace.xs),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 18,
              child: Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(WipasRadius.pill),
                    child: LinearProgressIndicator(
                      value: value == null ? 0 : (value / scaleMax).clamp(0, 1),
                      minHeight: 10,
                      color: WipasColors.primaryLight,
                      backgroundColor: WipasColors.divider,
                    ),
                  ),
                ),
                Positioned(left: (target / scaleMax * w).clamp(0, w - 2), top: 0, child: Container(width: 2, height: 18, color: WipasColors.textPrimary)),
              ]),
            );
          }),
          const SizedBox(height: WipasSpace.xs),
          Row(children: [
            Expanded(child: Text(targetLabel, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary))),
            WipasInlineStatus(ok ? StatusKind.berhasil : StatusKind.gagal,
                label: ok ? 'Memenuhi target' : 'Belum memenuhi target'),
          ]),
        ]),
      );
    }

    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WipasCardHeader(title: 'Metrik validasi', subtitle: 'Garis tegak pada bar menandai target'),
        const SizedBox(height: WipasSpace.md),
        metric('MAE validasi', health.maeValidation, Fmt.percent(health.maeValidation), MetricTargets.maxMae,
            'Target MAE ≤ ${Fmt.percent(MetricTargets.maxMae, digits: 0)}', true, 15),
        metric('RMSE', health.rmse, Fmt.percent(health.rmse), MetricTargets.maxRmse,
            'Target RMSE ≤ ${Fmt.percent(MetricTargets.maxRmse, digits: 0)}', true, 20),
        metric('R²', health.r2, health.r2 == null ? '—' : Fmt.decimal(health.r2!, digits: 2), MetricTargets.minR2,
            'Target R² ≥ ${Fmt.decimal(MetricTargets.minR2, digits: 2)}', false, 1),
      ]),
    );
  }
}

class _ProjectionEvalCard extends StatelessWidget {
  const _ProjectionEvalCard({required this.weeks});
  final List<WeekRow> weeks;

  @override
  Widget build(BuildContext context) {
    final head = WipasText.caption.copyWith(color: WipasColors.textSecondary);
    final num = WipasText.bodySmall.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final totalDays = weeks.fold<int>(0, (a, w) => a + w.days);
    double weighted(double Function(WeekRow) f) =>
        totalDays == 0 ? 0 : weeks.fold<double>(0, (a, w) => a + f(w) * w.days) / totalDays;
    final projAll = weighted((w) => w.projMape);
    final predAll = weighted((w) => w.predMape);
    final overAll = weeks.fold<int>(0, (a, w) => a + w.daysOver);

    Widget row(String label, String proj, String pred, String over, {bool bold = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WipasColors.divider))),
          child: Row(children: [
            Expanded(flex: 3, child: Text(label, style: num.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
            Expanded(flex: 2, child: Text(proj, textAlign: TextAlign.right, style: num.copyWith(color: WipasColors.textSecondary, fontWeight: bold ? FontWeight.w700 : null))),
            Expanded(flex: 2, child: Text(pred, textAlign: TextAlign.right, style: num.copyWith(color: WipasColors.tealText, fontWeight: bold ? FontWeight.w700 : null))),
            Expanded(flex: 2, child: Text(over, textAlign: TextAlign.right, style: num.copyWith(fontWeight: bold ? FontWeight.w700 : null))),
          ]),
        );

    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WipasCardHeader(
          title: 'Evaluasi Projection Tim DI',
          subtitle: weeks.isEmpty
              ? 'Projection vs Predicted terhadap Actual'
              : 'Projection vs Predicted terhadap Actual · error rata-rata (MAPE) · '
                  '${Fmt.range(weeks.first.start, weeks.last.end)}',
        ),
        const SizedBox(height: WipasSpace.sm),
        if (weeks.isEmpty)
          Text('Belum ada hari dengan Actual untuk dievaluasi.', style: WipasText.body.copyWith(color: WipasColors.textSecondary))
        else ...[
          Row(children: [
            Expanded(flex: 3, child: Text('Minggu', style: head)),
            Expanded(flex: 2, child: Text('Projection', style: head, textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Predicted', style: head, textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Hari >15%', style: head, textAlign: TextAlign.right)),
          ]),
          for (final w in weeks)
            row(
              w.start.month == w.end.month
                  ? '${w.start.day} – ${Fmt.dayMonth(w.end)}'
                  : '${Fmt.dayMonth(w.start)} – ${Fmt.dayMonth(w.end)}',
              Fmt.percent(w.projMape),
              Fmt.percent(w.predMape),
              '${w.daysOver}',
            ),
          row('Total $totalDays hari', Fmt.percent(projAll), Fmt.percent(predAll), '$overAll hari', bold: true),
          const SizedBox(height: WipasSpace.md),
          WipasAlertBanner(
            kind: AlertKind.info,
            body: predAll <= projAll
                ? 'Predicted rata-rata ${Fmt.decimal(projAll - predAll)} poin lebih dekat ke Actual daripada Projection. '
                    'Hari >15% = deviasi Predicted vs Projection lebih dari 15% (Perlu Perhatian).'
                : 'Projection rata-rata ${Fmt.decimal(predAll - projAll)} poin lebih dekat ke Actual daripada Predicted. '
                    'Hari >15% = deviasi Predicted vs Projection lebih dari 15% (Perlu Perhatian).',
          ),
        ],
      ]),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch});
  final BatchLog? batch;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WipasCardHeader(title: 'Status Batch Terakhir'),
        const SizedBox(height: WipasSpace.sm),
        if (b == null)
          Text('Belum ada log batch.', style: WipasText.body.copyWith(color: WipasColors.textSecondary))
        else ...[
          WipasDataRow(label: 'Waktu eksekusi', value: b.startedAt == null ? '—' : Fmt.dateTimeWib(b.startedAt!)),
          WipasDataRow(
            label: 'Status',
            value: '',
            valueWidget: Align(
              alignment: Alignment.centerRight,
              child: WipasInlineStatus(
                b.isSuccess ? StatusKind.berhasil : StatusKind.gagal,
                label: switch (b.status) {
                  'success' => 'Berhasil',
                  'failed' => 'Gagal',
                  _ => b.status,
                },
              ),
            ),
          ),
          WipasDataRow(label: 'Jumlah retry', value: '${b.retryCount}'),
          WipasDataRow(label: 'Durasi', value: b.durationSec == null ? '—' : Fmt.duration(b.durationSec!)),
          WipasDataRow(label: 'Sumber data', value: b.source ?? '—', divider: false),
          if (b.message != null && b.message!.isNotEmpty)
            Text(b.message!, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _DatasetCard extends StatelessWidget {
  const _DatasetCard({required this.dataset});
  final DatasetStatus? dataset;

  @override
  Widget build(BuildContext context) {
    final d = dataset;
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WipasCardHeader(title: 'Status Dataset'),
        const SizedBox(height: WipasSpace.sm),
        if (d == null)
          Text('Belum ada impor dataset.', style: WipasText.body.copyWith(color: WipasColors.textSecondary))
        else ...[
          WipasDataRow(label: 'Impor Excel terakhir', value: d.lastImportAt == null ? '—' : Fmt.dateTimeWib(d.lastImportAt!)),
          WipasDataRow(
            label: 'Rentang data',
            value: (d.rangeStart == null || d.rangeEnd == null)
                ? '—'
                : '${Fmt.dayMonthYear(d.rangeStart!)} – ${Fmt.dayMonthYear(d.rangeEnd!)}',
          ),
          WipasDataRow(label: 'Jumlah baris', value: Fmt.number(d.rowCount), divider: d.sourceFile != null),
          if (d.sourceFile != null) WipasDataRow(label: 'Berkas sumber', value: d.sourceFile!, divider: false),
        ],
      ]),
    );
  }
}
