import 'package:flutter/material.dart';

import '../domain/role.dart';
import '../theme/tokens.dart';

/// Status variants; color is never the only signal (always icon + text).
enum StatusKind {
  sehat,
  perluPerhatian,
  degraded,
  incomplete,
  disetujui,
  disesuaikan,
  menunggu,
  belum,
  normal,
  berhasil,
  gagal,
  info,
}

class _StatusStyle {
  const _StatusStyle(this.bg, this.border, this.fg, this.icon, this.label);
  final Color bg;
  final Color border;
  final Color fg;
  final IconData icon;
  final String label;
}

const _styles = <StatusKind, _StatusStyle>{
  StatusKind.sehat: _StatusStyle(
      WipasColors.successTint, WipasColors.successBorder, WipasColors.successText, Icons.check_circle_outline, 'Sehat'),
  StatusKind.perluPerhatian: _StatusStyle(WipasColors.warningTint, WipasColors.warning, WipasColors.warningText,
      Icons.warning_amber_rounded, 'Perlu Perhatian'),
  StatusKind.degraded: _StatusStyle(WipasColors.dangerTint, WipasColors.dangerBorder, WipasColors.dangerText,
      Icons.warning_amber_rounded, 'Model Degraded'),
  StatusKind.incomplete: _StatusStyle(WipasColors.warningTint, WipasColors.warning, WipasColors.warningText,
      Icons.warning_amber_rounded, 'Data Incomplete'),
  StatusKind.disetujui: _StatusStyle(
      WipasColors.successTint, WipasColors.successBorder, WipasColors.successText, Icons.check_circle_outline, 'Disetujui'),
  StatusKind.disesuaikan:
      _StatusStyle(WipasColors.infoTint, WipasColors.infoBorder, WipasColors.infoText, Icons.edit_outlined, 'Disesuaikan'),
  StatusKind.menunggu: _StatusStyle(WipasColors.warningTint, WipasColors.warning, WipasColors.warningText,
      Icons.schedule, 'Menunggu keputusan'),
  StatusKind.belum: _StatusStyle(
      WipasColors.surface, WipasColors.textSecondary, WipasColors.textPrimary, Icons.hourglass_empty, 'Belum'),
  StatusKind.normal: _StatusStyle(
      WipasColors.successTint, WipasColors.successBorder, WipasColors.successText, Icons.check_circle_outline, 'Normal'),
  StatusKind.berhasil: _StatusStyle(
      WipasColors.successTint, WipasColors.successBorder, WipasColors.successText, Icons.check_circle_outline, 'Berhasil'),
  StatusKind.gagal:
      _StatusStyle(WipasColors.dangerTint, WipasColors.dangerBorder, WipasColors.dangerText, Icons.error_outline, 'Gagal'),
  StatusKind.info:
      _StatusStyle(WipasColors.infoTint, WipasColors.infoBorder, WipasColors.infoText, Icons.info_outline, 'Info'),
};

/// Pill badge (height 28) with icon + text.
class WipasStatusBadge extends StatelessWidget {
  const WipasStatusBadge(this.kind, {super.key, this.label, this.icon});

  final StatusKind kind;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = _styles[kind]!;
    final text = label ?? s.label;
    return Semantics(
      label: 'Status: $text',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: WipasSize.badge),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: s.bg,
          border: Border.all(color: s.border),
          borderRadius: BorderRadius.circular(WipasRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? s.icon, size: 16, color: s.fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: WipasText.caption.copyWith(color: s.fg, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline status (icon + colored text) used in history rows.
class WipasInlineStatus extends StatelessWidget {
  const WipasInlineStatus(this.kind, {super.key, this.label});

  final StatusKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = _styles[kind]!;
    final color = switch (kind) {
      StatusKind.disetujui || StatusKind.sehat || StatusKind.berhasil || StatusKind.normal => WipasColors.successText,
      StatusKind.disesuaikan => WipasColors.infoText,
      StatusKind.degraded || StatusKind.gagal => WipasColors.dangerText,
      _ => WipasColors.warningText,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(s.icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label ?? s.label, style: WipasText.body.copyWith(color: color, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// Role pill in the Beranda header.
class WipasRoleChip extends StatelessWidget {
  const WipasRoleChip({super.key, required this.role, required this.label});

  final Role role;
  final String label;

  IconData get _icon => switch (role) {
        Role.admin => Icons.shield_outlined,
        Role.manajer => Icons.person_outline,
        Role.supervisor => Icons.list,
        Role.viewer => Icons.visibility_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (role) {
      Role.admin => (Colors.transparent, Colors.white, Colors.white70),
      Role.manajer => (WipasColors.navyTint, WipasColors.navy, WipasColors.navyTint),
      Role.supervisor => (WipasColors.successTint, WipasColors.tealText, WipasColors.successTint),
      Role.viewer => (WipasColors.surface, WipasColors.textPrimary, WipasColors.surface),
    };
    return Semantics(
      label: 'Role: $label',
      excludeSemantics: true,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(WipasRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: WipasText.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Hanya baca" pill. [locked] uses a lock icon (cards) instead of an eye.
class WipasReadOnlyChip extends StatelessWidget {
  const WipasReadOnlyChip({super.key, this.locked = false});

  final bool locked;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Hanya baca',
        excludeSemantics: true,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: WipasColors.surface,
            border: Border.all(color: WipasColors.textSecondary),
            borderRadius: BorderRadius.circular(WipasRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(locked ? Icons.lock_outline : Icons.visibility_outlined, size: 16, color: WipasColors.textPrimary),
              const SizedBox(width: 6),
              Text('Hanya baca', style: WipasText.caption.copyWith(color: WipasColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

/// Red count bubble (bell, tabs, menu rows).
class WipasCountBadge extends StatelessWidget {
  const WipasCountBadge(this.count, {super.key, this.outline});

  final int count;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WipasColors.danger,
        borderRadius: BorderRadius.circular(WipasRadius.pill),
        border: outline == null ? null : Border.all(color: outline!, width: 1.5),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: WipasText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.1)),
    );
  }
}

/// Small rounded tag for parameter values ("Rider 350").
class WipasTag extends StatelessWidget {
  const WipasTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: WipasColors.chipFill, borderRadius: BorderRadius.circular(WipasRadius.pill)),
        child: Text(label, style: WipasText.bodySmall.copyWith(color: WipasColors.navy, fontWeight: FontWeight.w600)),
      );
}
