import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'buttons.dart';
import 'cards.dart';

/// Bottom sheet: radius 16 top, 32×4 handle, 40% scrim.
Future<T?> showWipasBottomSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(WipasSpace.lg, 0, WipasSpace.lg, WipasSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(title, style: WipasText.title.copyWith(fontSize: 22))),
              const SizedBox(height: WipasSpace.lg),
              builder(ctx),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Confirm dialog (width 312, radius 16, padding 24): Batal left, action
/// right. Returns true when confirmed.
Future<bool> showWipasConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
  Widget? content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 312),
        child: Padding(
          padding: const EdgeInsets.all(WipasSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text(title, style: WipasText.title)),
            const SizedBox(height: WipasSpace.sm),
            Text(body, style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
            if (content != null) ...[const SizedBox(height: WipasSpace.md), content],
            const SizedBox(height: WipasSpace.xl),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  autofocus: destructive,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: WipasSpace.md),
              Expanded(
                child: destructive
                    ? WipasDestructiveButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true))
                    : FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// One snackbar at a time, 4 s, optional "Urungkan"-style action.
void showWipasSnackBar(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle, color: Color(0xFF81C784), size: 20),
      const SizedBox(width: WipasSpace.sm),
      Expanded(child: Text(message)),
    ]),
    duration: const Duration(seconds: 4),
    action: actionLabel == null
        ? null
        : SnackBarAction(label: actionLabel, textColor: const Color(0xFF90CAF9), onPressed: onAction ?? () {}),
  ));
}

/// Grey block with a 1.4 s shimmer; static when reduced motion is on.
class WipasSkeletonLoader extends StatefulWidget {
  const WipasSkeletonLoader({super.key, this.width, this.height = 16, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<WipasSkeletonLoader> createState() => _WipasSkeletonLoaderState();
}

class _WipasSkeletonLoaderState extends State<WipasSkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: WipasMotion.skeleton);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WipasMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * t - 0.6, 0),
                end: Alignment(-1 + 2 * t + 0.6, 0),
                colors: const [WipasColors.divider, Color(0xFFF7F9FC), WipasColors.divider],
              ),
            ),
          );
        },
      );
}

/// Skeleton shaped like the real screen's cards.
class WipasSkeletonScreen extends StatelessWidget {
  const WipasSkeletonScreen({super.key, this.cards = 3});
  final int cards;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Memuat data',
        child: Column(children: [
          for (var i = 0; i < cards; i++) ...[
            WipasCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const WipasSkeletonLoader(width: 140, height: 14),
                const SizedBox(height: WipasSpace.md),
                const WipasSkeletonLoader(width: 200, height: 28),
                const SizedBox(height: WipasSpace.md),
                WipasSkeletonLoader(width: i.isEven ? 260 : 180, height: 12),
                const SizedBox(height: WipasSpace.sm),
                const WipasSkeletonLoader(height: 12),
              ]),
            ),
            const SizedBox(height: WipasSpace.md),
          ],
        ]),
      );
}

/// Empty state: 48 icon + title + explanation + optional action.
class WipasEmptyState extends StatelessWidget {
  const WipasEmptyState({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => WipasCard(
        padding: const EdgeInsets.symmetric(horizontal: WipasSpace.xl, vertical: WipasSpace.xxl),
        child: Column(children: [
          CircleAvatar(radius: 28, backgroundColor: WipasColors.chipFill, child: Icon(icon, size: 32, color: WipasColors.navy)),
          const SizedBox(height: WipasSpace.lg),
          Text(title, textAlign: TextAlign.center, style: WipasText.heading),
          const SizedBox(height: WipasSpace.sm),
          Text(message, textAlign: TextAlign.center, style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: WipasSpace.lg), action!],
        ]),
      );
}

/// Error state: danger icon + "Gagal memuat data" + Coba lagi; after 3
/// failures suggests contacting IT Support.
class WipasErrorState extends StatelessWidget {
  const WipasErrorState({super.key, required this.onRetry, this.attempts = 0});

  static const title = 'Gagal memuat data';
  static const message = 'Koneksi terputus atau server tidak merespons. Data belum diperbarui.';
  static const itSupport = 'Masih gagal setelah 3 kali. Hubungi IT Support dan sebutkan waktu kejadian.';

  final VoidCallback onRetry;
  final int attempts;

  @override
  Widget build(BuildContext context) => WipasCard(
        padding: const EdgeInsets.symmetric(horizontal: WipasSpace.xl, vertical: WipasSpace.xxl),
        child: Column(children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: WipasColors.dangerTint,
            child: Icon(Icons.error_outline, size: 32, color: WipasColors.danger),
          ),
          const SizedBox(height: WipasSpace.lg),
          const Text(title, textAlign: TextAlign.center, style: WipasText.heading),
          const SizedBox(height: WipasSpace.sm),
          Text(message, textAlign: TextAlign.center, style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          const SizedBox(height: WipasSpace.lg),
          WipasPrimaryButton(label: 'Coba lagi', icon: Icons.refresh, onPressed: onRetry, expand: false),
          if (attempts >= 3) ...[
            const SizedBox(height: WipasSpace.md),
            Text(itSupport, textAlign: TextAlign.center, style: WipasText.bodySmall.copyWith(color: WipasColors.dangerText)),
          ],
        ]),
      );
}
