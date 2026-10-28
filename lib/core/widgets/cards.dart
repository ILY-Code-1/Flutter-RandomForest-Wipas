import 'package:flutter/material.dart';

import '../format/formatters.dart';
import '../theme/tokens.dart';
import 'badges.dart';

/// White card, radius 12, border + subtle elevation.
class WipasCard extends StatelessWidget {
  const WipasCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WipasSpace.lg),
    this.borderColor = WipasColors.border,
    this.color = WipasColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(WipasRadius.card),
        border: Border.all(color: borderColor),
        boxShadow: WipasElevation.card,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(borderRadius: BorderRadius.circular(WipasRadius.card), onTap: onTap, child: content),
            ),
    );
  }
}

/// Card title + optional subtitle + trailing widget.
class WipasCardHeader extends StatelessWidget {
  const WipasCardHeader({super.key, required this.title, this.subtitle, this.trailing, this.leading});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: WipasSpace.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: WipasText.heading.copyWith(fontSize: 18, height: 26 / 18))),
                if (subtitle != null) Text(subtitle!, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: WipasSpace.sm), trailing!],
        ],
      );
}

enum KpiVariant { predicted, projection, actual, deviation }

/// KPI tile: dot + label, big tabular number, unit, delta line.
class WipasKpiCard extends StatelessWidget {
  const WipasKpiCard({
    super.key,
    required this.variant,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaIcon,
    this.deltaColor,
    this.highlight = false,
    this.onTap,
  });

  final KpiVariant variant;
  final String label;
  final String value;
  final String? unit;
  final String? delta;
  final IconData? deltaIcon;
  final Color? deltaColor;

  /// Warning border (deviation above threshold).
  final bool highlight;
  final VoidCallback? onTap;

  Color get _dot => switch (variant) {
        KpiVariant.predicted => WipasColors.teal,
        KpiVariant.projection => WipasColors.seriesProjection,
        KpiVariant.actual => WipasColors.navy,
        KpiVariant.deviation => WipasColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value ${unit ?? ''}. ${delta ?? ''}',
      excludeSemantics: true,
      child: WipasCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        borderColor: highlight ? WipasColors.warning : WipasColors.border,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _dot, shape: BoxShape.circle)),
              const SizedBox(width: WipasSpace.sm),
              Expanded(child: Text(label, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary))),
            ]),
            const SizedBox(height: WipasSpace.xs),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: WipasText.kpi)),
            if (unit != null) Text(unit!, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            if (delta != null) ...[
              const SizedBox(height: WipasSpace.xs),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (deltaIcon != null) ...[
                  Icon(deltaIcon, size: 16, color: deltaColor ?? WipasColors.textSecondary),
                  const SizedBox(width: WipasSpace.xs),
                ],
                Expanded(
                  child: Text(delta!,
                      style: WipasText.bodySmall
                          .copyWith(color: deltaColor ?? WipasColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Legend entry for charts.
class ChartLegendItem {
  const ChartLegendItem(this.label, this.color, {this.dashed = false, this.dotted = false, this.marker = false, this.area = false});
  final String label;
  final Color color;
  final bool dashed;
  final bool dotted;
  final bool marker;
  final bool area;
}

/// Card holding a chart, legend and a mandatory text summary (a11y).
class WipasChartCard extends StatelessWidget {
  const WipasChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    required this.legend,
    required this.summary,
    this.footer,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget chart;
  final List<ChartLegendItem> legend;

  /// Plain-text description of the chart for screen readers.
  final String summary;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => WipasCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WipasCardHeader(title: title, subtitle: subtitle, trailing: trailing),
            const SizedBox(height: WipasSpace.md),
            Semantics(label: summary, excludeSemantics: true, child: chart),
            const SizedBox(height: WipasSpace.md),
            Wrap(
              spacing: WipasSpace.lg,
              runSpacing: WipasSpace.xs,
              children: [for (final l in legend) _LegendEntry(l)],
            ),
            if (footer != null) ...[const SizedBox(height: WipasSpace.md), footer!],
          ],
        ),
      );
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry(this.item);
  final ChartLegendItem item;

  @override
  Widget build(BuildContext context) {
    Widget swatch;
    if (item.area) {
      swatch = Container(width: 16, height: 12, color: item.color.withValues(alpha: 0.25));
    } else {
      swatch = SizedBox(
        width: 26,
        height: 12,
        child: CustomPaint(painter: _LinePainter(item.color, dashed: item.dashed, dotted: item.dotted, marker: item.marker)),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      swatch,
      const SizedBox(width: 6),
      Text(item.label, style: WipasText.bodySmall),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.color, {this.dashed = false, this.dotted = false, this.marker = false});
  final Color color;
  final bool dashed;
  final bool dotted;
  final bool marker;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = dashed || dotted ? 2 : 3;
    final y = size.height / 2;
    if (dashed || dotted) {
      final dash = dotted ? 2.0 : 5.0;
      final gap = dotted ? 3.0 : 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), p);
        x += dash + gap;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    if (marker) canvas.drawCircle(Offset(size.width / 2, y), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.color != color;
}

/// Horizontal feature-importance bar with percentage.
class WipasFeatureBar extends StatelessWidget {
  const WipasFeatureBar({super.key, required this.label, required this.fraction, this.highlight = false});

  final String label;

  /// 0..1
  final double fraction;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final pct = Fmt.percent(fraction * 100, digits: 0);
    return Semantics(
      label: '$label $pct',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: WipasText.bodySmall)),
          const SizedBox(width: WipasSpace.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WipasRadius.pill),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1) / _maxScale,
                minHeight: 10,
                backgroundColor: WipasColors.divider,
                color: highlight ? WipasColors.teal : WipasColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(width: WipasSpace.sm),
          SizedBox(width: 40, child: Text(pct, textAlign: TextAlign.right, style: WipasText.bodySmall)),
        ]),
      ),
    );
  }

  // Bars are scaled so that ~30% fills the track (as in the design).
  static const _maxScale = 0.3;
}

/// Label left, tabular value right, divider below.
class WipasDataRow extends StatelessWidget {
  const WipasDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
    this.divider = true,
    this.labelSuffix,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;
  final bool divider;
  final String? labelSuffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: WipasSize.touch),
      decoration: divider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: WipasColors.divider)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: label),
              if (labelSuffix != null)
                TextSpan(text: ' $labelSuffix', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            ]), style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          ),
          const SizedBox(width: WipasSpace.md),
          Flexible(
            child: valueWidget ??
                Text(value,
                    textAlign: TextAlign.right,
                    style: WipasText.bodyStrong.copyWith(color: valueColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Menu row: round icon + title + subtitle + optional badge + chevron.
class WipasListTile extends StatelessWidget {
  const WipasListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badgeCount = 0,
    this.onTap,
    this.divider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int badgeCount;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: WipasSpace.md),
            decoration: divider
                ? const BoxDecoration(border: Border(bottom: BorderSide(color: WipasColors.divider)))
                : null,
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: WipasColors.chipFill,
                child: Icon(icon, color: WipasColors.navy, size: WipasSize.iconLarge),
              ),
              const SizedBox(width: WipasSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: WipasText.heading),
                  if (subtitle != null) Text(subtitle!, style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
                ]),
              ),
              if (badgeCount > 0) ...[WipasCountBadge(badgeCount), const SizedBox(width: WipasSpace.sm)],
              const Icon(Icons.chevron_right, color: WipasColors.textSecondary),
            ]),
          ),
        ),
      );
}

/// Notification row: type icon + type label + title + body + time.
class WipasNotificationTile extends StatelessWidget {
  const WipasNotificationTile({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.typeLabel,
    required this.typeColor,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String typeLabel;
  final Color typeColor;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${unread ? 'Belum dibaca. ' : ''}$typeLabel. $title. $body. $time',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            color: unread ? WipasColors.infoTint.withValues(alpha: 0.6) : WipasColors.surface,
            padding: const EdgeInsets.all(WipasSpace.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 20, backgroundColor: iconBg, child: Icon(icon, color: iconColor)),
              const SizedBox(width: WipasSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(typeLabel,
                            style: WipasText.bodySmall.copyWith(color: typeColor, fontWeight: FontWeight.w600))),
                    if (unread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: WipasColors.navy, borderRadius: BorderRadius.circular(WipasRadius.pill)),
                        child: Text('• Baru',
                            style: WipasText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(title, style: WipasText.body.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
                  Text(body, style: WipasText.body),
                  const SizedBox(height: 2),
                  Text(time, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// Decision log entry: status + actor + time + reason (if adjusted).
class WipasDecisionLogItem extends StatelessWidget {
  const WipasDecisionLogItem({
    super.key,
    required this.adjusted,
    required this.actor,
    required this.time,
    this.detail,
    this.reason,
  });

  final bool adjusted;
  final String actor;
  final String time;
  final String? detail;
  final String? reason;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: WipasSpace.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            WipasStatusBadge(adjusted ? StatusKind.disesuaikan : StatusKind.disetujui),
            const SizedBox(width: WipasSpace.sm),
            Expanded(child: Text('$actor · $time', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary))),
          ]),
          if (detail != null) ...[const SizedBox(height: WipasSpace.xs), Text(detail!, style: WipasText.bodySmall)],
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Alasan: $reason', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
          ],
        ]),
      );
}
