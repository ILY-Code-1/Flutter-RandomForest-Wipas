import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Text shown under write actions while offline.
const offlineActionHint = 'Tidak tersedia saat offline';

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

Widget _label(String label, IconData? icon, bool loading, Color color) {
  if (loading) return _Spinner(color: color);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: WipasSize.icon), const SizedBox(width: WipasSpace.sm)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}

/// Disabled buttons stay visible and explain why below.
Widget _withReason(Widget button, String? reason) {
  if (reason == null) return button;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      button,
      const SizedBox(height: WipasSpace.xs),
      Text(reason, textAlign: TextAlign.center, style: WipasText.caption),
    ],
  );
}

/// Filled navy button, height 48, radius 10.
class WipasPrimaryButton extends StatelessWidget {
  const WipasPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.disabledReason,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  /// When set the button is disabled and this text is shown below it.
  final String? disabledReason;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && disabledReason == null && !loading;
    final button = FilledButton(
      onPressed: enabled ? onPressed : (loading ? () {} : null),
      style: expand ? null : FilledButton.styleFrom(minimumSize: const Size(WipasSize.touch * 2, WipasSize.touch)),
      child: _label(label, icon, loading, Colors.white),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, memproses' : null,
      child: _withReason(button, disabledReason),
    );
  }
}

/// Outlined navy button (border 1.5).
class WipasSecondaryButton extends StatelessWidget {
  const WipasSecondaryButton({super.key, required this.label, this.icon, this.onPressed, this.disabledReason});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && disabledReason == null;
    return _withReason(
      OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: enabled
            ? null
            : OutlinedButton.styleFrom(side: const BorderSide(color: WipasColors.border, width: 1.5)),
        child: _label(label, icon, false, WipasColors.navy),
      ),
      disabledReason,
    );
  }
}

/// Danger filled button; always used behind a [showWipasConfirmDialog].
class WipasDestructiveButton extends StatelessWidget {
  const WipasDestructiveButton({super.key, required this.label, this.icon, this.onPressed, this.loading = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? () {} : onPressed,
        style: FilledButton.styleFrom(backgroundColor: WipasColors.danger),
        child: _label(label, icon, loading, Colors.white),
      );
}

/// Link-colored text button with a 48dp touch area.
class WipasTextButton extends StatelessWidget {
  const WipasTextButton({super.key, required this.label, this.icon, this.onPressed, this.trailingIcon});

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: WipasSize.icon), const SizedBox(width: WipasSpace.xs)],
            Flexible(child: Text(label)),
            if (trailingIcon != null) ...[
              const SizedBox(width: WipasSpace.xs),
              Icon(trailingIcon, size: WipasSize.icon),
            ],
          ],
        ),
      );
}
