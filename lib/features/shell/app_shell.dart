import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/widgets/widgets.dart';
import '../../core/data/models.dart';

/// Branch order in the router's StatefulShellRoute.
const shellBranches = [Routes.beranda, Routes.prediksi, Routes.manpower, Routes.evaluasi, Routes.lainnya];

const _tabMeta = <String, (String, IconData, IconData)>{
  Routes.beranda: ('Beranda', Icons.home_outlined, Icons.home_rounded),
  Routes.prediksi: ('Prediksi', Icons.trending_up, Icons.trending_up),
  Routes.manpower: ('Manpower', Icons.groups_outlined, Icons.groups),
  Routes.evaluasi: ('Evaluasi', Icons.bar_chart, Icons.bar_chart),
  Routes.lainnya: ('Lainnya', Icons.more_horiz, Icons.more_horiz),
};

/// Badge on the Prediksi tab: 1 when the latest H+1 needs attention.
final prediksiBadgeProvider = Provider.autoDispose<int>((ref) {
  final Prediction? p = ref.watch(latestPredictionProvider).valueOrNull;
  return (p != null && p.needsAttention) ? 1 : 0;
});

/// Main scaffold with the role-filtered bottom navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final visible = AccessMatrix.tabsFor(user.role);
    final badge = ref.watch(prediksiBadgeProvider);
    final current = shellBranches[shell.currentIndex];
    final tabs = [
      for (final path in visible)
        NavTab(
          path: path,
          label: _tabMeta[path]!.$1,
          icon: _tabMeta[path]!.$2,
          activeIcon: _tabMeta[path]!.$3,
          badge: path == Routes.prediksi ? badge : 0,
        ),
    ];
    final index = visible.indexOf(current).clamp(0, visible.length - 1);
    return Scaffold(
      body: shell,
      bottomNavigationBar: WipasBottomNav(
        tabs: tabs,
        currentIndex: index,
        onTap: (i) {
          final branch = shellBranches.indexOf(visible[i]);
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
      ),
    );
  }
}
