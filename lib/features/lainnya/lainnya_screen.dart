import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

/// Menu per role: Konfigurasi (Admin, Manajer), Riwayat, Notifikasi, Profil.
class LainnyaScreen extends ConsumerWidget {
  const LainnyaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final hub = ref.watch(warehouseNameProvider);
    final repo = ref.watch(repositoryProvider);
    final unread = ref.watch(unreadCountProvider);
    final modelVersion = ref.watch(modelHealthProvider).valueOrNull?.modelVersion;
    final role = user.role;
    final items = [
      if (AccessMatrix.canEditConfig(role))
        (Icons.settings_outlined, 'Konfigurasi kapasitas', 'Kapasitas & rasio manpower', Routes.konfigurasi, 0),
      (
        Icons.history,
        AccessMatrix.canExportCsv(role) ? 'Riwayat & export' : 'Riwayat',
        AccessMatrix.canExportCsv(role)
            ? 'Prediksi, actual, keputusan · Export CSV'
            : (AccessMatrix.canSeeDecisions(role) ? 'Prediksi, actual, keputusan' : 'Prediksi & actual'),
        Routes.riwayat,
        0,
      ),
      (Icons.notifications_none_rounded, 'Notifikasi', 'Deviasi, model, data, batch', Routes.notifikasi, unread),
      (Icons.person_outline, 'Profil & pengaturan', 'Akun, keluar, versi aplikasi', Routes.profil, 0),
    ];

    return Scaffold(
      appBar: WipasAppBarTop(title: 'Lainnya', subtitle: ref.watch(screenSubtitleProvider)),
      body: ListView(
        padding: const EdgeInsets.all(WipasSpace.lg),
        children: [
          WipasCard(
            onTap: () => context.push(Routes.profil),
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: WipasColors.navy,
                child: Text(user.initials, style: WipasText.heading.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: WipasSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName, style: WipasText.heading),
                  Text('${role.label} · $hub', style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: WipasColors.textSecondary),
            ]),
          ),
          cardGap,
          WipasCard(
            padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
            child: Column(children: [
              for (var i = 0; i < items.length; i++)
                WipasListTile(
                  icon: items[i].$1,
                  title: items[i].$2,
                  subtitle: items[i].$3,
                  badgeCount: items[i].$5,
                  divider: i < items.length - 1,
                  onTap: () => context.push(items[i].$4),
                ),
            ]),
          ),
          const SizedBox(height: WipasSpace.md),
          Text(
            'WIPAS ${AppConfig.appVersion.substring(0, 3)} · Model ${modelVersion ?? '—'} · $hub (${repo.whId})',
            textAlign: TextAlign.center,
            style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
