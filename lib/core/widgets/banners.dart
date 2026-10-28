import 'package:flutter/material.dart';

import '../format/formatters.dart';
import '../theme/tokens.dart';

enum AlertKind { info, warning, danger, success }

/// Banner with icon + title + optional body, extra content and action.
/// Danger banners cannot be dismissed.
class WipasAlertBanner extends StatelessWidget {
  const WipasAlertBanner({
    super.key,
    required this.kind,
    this.title,
    this.body,
    this.icon,
    this.child,
    this.action,
    this.compact = false,
  });

  final AlertKind kind;
  final String? title;
  final String? body;
  final IconData? icon;
  final Widget? child;
  final Widget? action;

  /// Single-line info note without border (e.g. "Prediksi dihitung ...").
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, iconColor, defaultIcon) = switch (kind) {
      AlertKind.info => (WipasColors.infoTint, WipasColors.infoBorder, WipasColors.infoText, WipasColors.info, Icons.info_outline),
      AlertKind.warning => (
          WipasColors.warningTint,
          WipasColors.warning,
          WipasColors.warningText,
          WipasColors.warningText,
          Icons.warning_amber_rounded
        ),
      AlertKind.danger => (
          WipasColors.dangerTint,
          WipasColors.dangerBorder,
          WipasColors.dangerText,
          WipasColors.danger,
          Icons.warning_amber_rounded
        ),
      AlertKind.success => (
          WipasColors.successTint,
          WipasColors.successBorder,
          WipasColors.successText,
          WipasColors.success,
          Icons.check_circle_outline
        ),
    };
    return Semantics(
      container: true,
      liveRegion: kind == AlertKind.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(WipasSpace.lg),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(WipasRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: iconColor, size: WipasSize.iconLarge),
            const SizedBox(width: WipasSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: WipasText.heading.copyWith(color: fg)),
                  if (body != null) ...[
                    if (title != null) const SizedBox(height: 2),
                    Text(body!, style: WipasText.body.copyWith(color: fg)),
                  ],
                  if (child != null) ...[const SizedBox(height: WipasSpace.sm), child!],
                  if (action != null) ...[const SizedBox(height: WipasSpace.md), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact info line with an icon (no box).
class WipasInfoLine extends StatelessWidget {
  const WipasInfoLine({super.key, required this.child, this.icon = Icons.info_outline, this.color = WipasColors.info});

  final Widget child;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: WipasSpace.sm),
          Expanded(child: DefaultTextStyle.merge(style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary), child: child)),
        ],
      );
}

/// Shown automatically while offline.
class WipasOfflineBanner extends StatelessWidget {
  const WipasOfflineBanner({super.key, this.lastSync});

  final DateTime? lastSync;

  static const title = 'Mode offline · menampilkan data tersimpan';

  @override
  Widget build(BuildContext context) => WipasAlertBanner(
        kind: AlertKind.warning,
        icon: Icons.wifi_off_rounded,
        title: title,
        body: 'Terakhir disinkronkan: ${lastSync == null ? 'belum pernah' : Fmt.dateTimeWib(lastSync!)}',
      );
}
