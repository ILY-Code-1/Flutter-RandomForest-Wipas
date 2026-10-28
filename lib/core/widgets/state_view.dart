import 'package:flutter/material.dart';

import '../state/view_state.dart';
import '../theme/tokens.dart';
import 'banners.dart';
import 'feedback.dart';

/// Renders a [ViewState]: skeleton, empty, error (with retry counter),
/// offline banner + cached data, or data. Content is laid out in a padded
/// scrollable column.
class WipasStateView<T> extends StatelessWidget {
  const WipasStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.empty,
    required this.onRetry,
    this.attempts = 0,
    this.header,
    this.skeletonCards = 3,
  });

  final ViewState<T> state;

  /// Builds the content. `offline` is true when write actions must be disabled.
  final List<Widget> Function(BuildContext context, T data, bool offline) builder;
  final Widget empty;
  final VoidCallback onRetry;
  final int attempts;

  /// Pinned widget above the scroll content (e.g. the "Hanya baca" strip).
  final Widget? header;
  final int skeletonCards;

  @override
  Widget build(BuildContext context) {
    final children = switch (state) {
      ViewLoading() => [WipasSkeletonScreen(cards: skeletonCards)],
      ViewEmpty() => [empty],
      ViewError() => [WipasErrorState(onRetry: onRetry, attempts: attempts)],
      ViewOffline(:final data, :final lastSync) => [
          WipasOfflineBanner(lastSync: lastSync),
          const SizedBox(height: WipasSpace.md),
          ...builder(context, data, true),
        ],
      ViewData(:final data) => builder(context, data, false),
    };
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.lg, WipasSpace.lg, WipasSpace.xl),
      children: children,
    );
    if (header == null) return list;
    return Column(children: [header!, Expanded(child: list)]);
  }
}

/// Vertical gap between cards.
const cardGap = SizedBox(height: WipasSpace.md);
