import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Combines several async values: error if any failed without data, data when
/// all have data, otherwise loading.
AsyncValue<R> combineAsync<R>(List<AsyncValue<Object?>> values, R Function() build) {
  for (final v in values) {
    if (v.hasError && !v.hasValue) return AsyncError<R>(v.error!, v.stackTrace ?? StackTrace.empty);
  }
  if (values.every((v) => v.hasValue)) {
    try {
      return AsyncData<R>(build());
    } catch (e, st) {
      return AsyncError<R>(e, st);
    }
  }
  return AsyncLoading<R>();
}

/// "Hub Cakung · Admin WIPAS · Shift Lead"
final screenSubtitleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  final hub = ref.watch(warehouseNameProvider);
  return user == null ? hub : '$hub · ${user.displayName}';
});

/// Retries a screen: bumps its failure counter and re-subscribes providers.
void retryScreen(WidgetRef ref, String key, List<ProviderOrFamily> providers) {
  ref.read(retryCountProvider(key).notifier).state++;
  for (final p in providers) {
    ref.invalidate(p);
  }
}

/// 14-day trend: Projection dashed, Predicted thick teal, Actual navy with
/// markers. The selected date is marked with a dotted vertical line.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, required this.markDate, this.markLabel = 'H+1', this.height = 200});

  /// Oldest → newest.
  final List<Prediction> points;
  final DateTime markDate;
  final String markLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('Belum ada data tren', style: WipasText.bodySmall)));
    }
    final start = points.first.targetDate;
    double x(DateTime d) => d.difference(start).inDays.toDouble();
    final values = <int>[
      for (final p in points) ...[?p.predicted, ?p.projection, ?p.actualInbound],
    ];
    var minY = values.isEmpty ? 0.0 : values.reduce(math.min).toDouble();
    var maxY = values.isEmpty ? 1.0 : values.reduce(math.max).toDouble();
    const step = 2000.0;
    minY = (minY / step).floor() * step;
    maxY = (maxY / step).ceil() * step;
    if (maxY == minY) maxY = minY + step;
    final markX = x(markDate);
    final lastX = x(points.last.targetDate);

    List<FlSpot> spots(int? Function(Prediction) f) =>
        [for (final p in points) f(p) == null ? FlSpot.nullSpot : FlSpot(x(p.targetDate), f(p)!.toDouble())];

    final interval = math.max(1, (points.length / 4).ceil()).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.none(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => const FlLine(color: WipasColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: step,
                getTitlesWidget: (v, meta) => Text(Fmt.number(v), style: WipasText.caption),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final d = start.add(Duration(days: v.round()));
                  final isMark = d == markDate;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(Fmt.dayMonth(d),
                        style: WipasText.caption.copyWith(
                            color: isMark ? WipasColors.tealText : WipasColors.textSecondary,
                            fontWeight: isMark ? FontWeight.w700 : FontWeight.w500)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(verticalLines: [
            VerticalLine(
              x: markX,
              color: WipasColors.textSecondary,
              strokeWidth: 1,
              dashArray: [2, 3],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                style: WipasText.caption.copyWith(color: WipasColors.tealText, fontWeight: FontWeight.w700),
                labelResolver: (_) => markLabel,
              ),
            ),
          ]),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => WipasColors.textPrimary,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${['Projection', 'Predicted', 'Actual'][s.barIndex]} ${Fmt.number(s.y)}',
                    WipasText.caption.copyWith(color: Colors.white),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots((p) => p.projection),
              color: WipasColors.seriesProjection,
              barWidth: 2,
              dashArray: [6, 4],
              dotData: FlDotData(
                show: true,
                checkToShowDot: (s, _) => s.x == markX,
                getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                    radius: 4, color: Colors.white, strokeColor: WipasColors.seriesProjection, strokeWidth: 2),
              ),
            ),
            LineChartBarData(
              spots: spots((p) => p.predicted),
              color: WipasColors.teal,
              barWidth: 3.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (s, _) => s.x == markX,
                getDotPainter: (s, _, _, _) => FlDotCirclePainter(radius: 5, color: WipasColors.teal, strokeWidth: 0),
              ),
            ),
            LineChartBarData(
              spots: spots((p) => p.actualInbound),
              color: WipasColors.navy,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, _, _, _) => FlDotCirclePainter(radius: 2.5, color: WipasColors.navy, strokeWidth: 0),
              ),
            ),
          ],
        ),
        duration: WipasMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 250),
      ),
    );
  }
}

const trendLegend = [
  ChartLegendItem('Projection', WipasColors.seriesProjection, dashed: true),
  ChartLegendItem('Predicted', WipasColors.teal),
  ChartLegendItem('Actual', WipasColors.navy, marker: true),
];

/// Text summary of the trend chart (accessibility).
String trendSummary(List<Prediction> points) {
  if (points.isEmpty) return 'Tidak ada data tren.';
  final last = points.last;
  return 'Grafik tren ${points.length} hari, ${Fmt.range(points.first.targetDate, last.targetDate)}. '
      'Terakhir ${Fmt.date(last.targetDate)}: Predicted ${Fmt.number(last.predicted)}, '
      'Projection ${Fmt.number(last.projection)}, Actual ${last.actualInbound == null ? 'belum ada' : Fmt.number(last.actualInbound)}.';
}

/// Teal summary box under the trend chart for the marked date.
class TrendTooltipBox extends StatelessWidget {
  const TrendTooltipBox({super.key, required this.p, required this.label});
  final Prediction p;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(WipasSpace.md),
        decoration: BoxDecoration(
          color: WipasColors.successTint.withValues(alpha: 0.7),
          border: Border.all(color: WipasColors.successBorder),
          borderRadius: BorderRadius.circular(WipasRadius.control),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tooltip · $label', style: WipasText.bodySmall.copyWith(color: WipasColors.tealText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _kv('Predicted', Fmt.number(p.predicted))),
            Expanded(child: _kv('Projection', Fmt.number(p.projection))),
          ]),
          Row(children: [
            Expanded(
                child: p.actualInbound == null
                    ? Text('Actual belum ada', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary))
                    : _kv('Actual', Fmt.number(p.actualInbound))),
            Expanded(child: _kv('Deviasi', p.deviation == null ? '—' : Fmt.percent(p.deviation!.abs()))),
          ]),
        ]),
      );

  Widget _kv(String k, String v) => Text.rich(
        TextSpan(children: [TextSpan(text: '$k '), TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w700))]),
        style: WipasText.bodySmall,
      );
}

String _yesNo(bool? v) => v == null ? 'Belum diterima' : (v ? 'Ya' : 'Tidak');

/// Read-only predictor inputs ("Input model hari ini" / "Data fitur hari ini").
class InputFeaturesCard extends StatelessWidget {
  const InputFeaturesCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.features,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final InputFeatures features;

  /// Input Actual shows a shorter list (no actual/projection rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int? v, {bool divider = true}) => WipasDataRow(
          label: label,
          value: v == null ? 'Belum diterima' : Fmt.number(v),
          valueColor: v == null ? WipasColors.warningText : null,
          divider: divider,
        );
    Widget flag(String label, bool? v) =>
        WipasDataRow(label: label, value: _yesNo(v), valueColor: v == null ? WipasColors.warningText : null);
    final f = features;
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WipasCardHeader(title: title, subtitle: subtitle, trailing: const WipasReadOnlyChip(locked: true)),
        const SizedBox(height: WipasSpace.sm),
        row('Pickup Request H-1', f.pickupRequestH1),
        row('Backlog H-1', f.backlogH1),
        if (!compact) ...[
          row('Actual Inbound H-1', f.actualInboundH1),
          row('Actual Inbound H-2', f.actualInboundH2),
          row('Projection Inbound', f.projectionInbound),
        ],
        flag('Campaign', f.isCampaign),
        flag('Hari Libur', f.isHoliday),
        flag('Payday', f.isPayday),
        const SizedBox(height: WipasSpace.sm),
        const WipasInfoLine(
          icon: Icons.description_outlined,
          color: WipasColors.textSecondary,
          child: Text('Diimpor dari Excel · tidak dapat diubah di aplikasi'),
        ),
      ]),
    );
  }
}

/// Feature importance bars ("Faktor pendorong"). Hidden for Supervisor.
class FeatureDriversCard extends StatelessWidget {
  const FeatureDriversCard({super.key, required this.importance, this.cardKey});

  final Map<String, double> importance;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final entries = importance.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return WipasCard(
      key: cardKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WipasCardHeader(title: 'Faktor pendorong', subtitle: 'Feature importance model'),
        const SizedBox(height: WipasSpace.sm),
        if (entries.isEmpty)
          Text('Feature importance belum tersedia.', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary))
        else
          for (var i = 0; i < entries.length; i++)
            WipasFeatureBar(
              label: featureLabels[entries[i].key] ?? entries[i].key,
              fraction: entries[i].value,
              highlight: i < 2,
            ),
        if (entries.length >= 2) ...[
          const SizedBox(height: WipasSpace.sm),
          WipasAlertBanner(
            kind: AlertKind.info,
            body: '${featureLabels[entries[0].key] ?? entries[0].key} & '
                '${featureLabels[entries[1].key] ?? entries[1].key} paling berpengaruh',
          ),
        ],
      ]),
    );
  }
}
