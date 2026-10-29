import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

enum NotifFilter { semua, belumDibaca, deviasi, model, data, batch }

final notifFilterProvider = StateProvider.autoDispose<NotifFilter>((ref) => NotifFilter.semua);

class _TypeStyle {
  const _TypeStyle(this.label, this.icon, this.bg, this.fg);
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

_TypeStyle _style(String type) => switch (type) {
      NotifType.deviation => const _TypeStyle('Deviasi >15%', Icons.warning_amber_rounded, WipasColors.warningTint, WipasColors.warningText),
      NotifType.degraded => const _TypeStyle('Model Degraded', Icons.report_gmailerrorred, WipasColors.dangerTint, WipasColors.dangerText),
      NotifType.incomplete => const _TypeStyle('Data Incomplete Warning', Icons.description_outlined, WipasColors.warningTint, WipasColors.warningText),
      _ => const _TypeStyle('Batch', Icons.check_circle_outline, WipasColors.successTint, WipasColors.successText),
    };

bool matchesFilter(AppNotification n, NotifFilter f, String uid) => switch (f) {
      NotifFilter.semua => true,
      NotifFilter.belumDibaca => !n.isReadBy(uid),
      NotifFilter.deviasi => n.type == NotifType.deviation,
      NotifFilter.model => n.type == NotifType.degraded,
      NotifFilter.data => n.type == NotifType.incomplete,
      NotifFilter.batch => n.type == NotifType.batch,
    };

class NotifData {
  const NotifData(this.items, this.uid);
  final List<AppNotification> items;
  final String uid;

  bool isRead(AppNotification n) => n.isReadBy(uid);
}

final notifDataProvider = Provider.autoDispose<AsyncValue<NotifData>>((ref) {
  final items = ref.watch(notificationsProvider);
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  return combineAsync([items], () => NotifData(items.requireValue, uid));
});

class NotifikasiScreen extends ConsumerWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<NotifData>(ref.watch(notifDataProvider), offline: offline, lastSync: ref.watch(syncClockProvider));
    final filter = ref.watch(notifFilterProvider);

    return Scaffold(
      appBar: WipasAppBarSub(
        title: 'Notifikasi',
        subtitle: ref.watch(screenSubtitleProvider),
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.beranda),
      ),
      body: switch (state) {
        ViewData(:final data) => _list(context, ref, data, filter, user, false),
        ViewOffline(:final data) => _list(context, ref, data, filter, user, true),
        _ => WipasStateView<NotifData>(
            state: state,
            attempts: ref.watch(retryCountProvider('notifikasi')),
            onRetry: () => retryScreen(ref, 'notifikasi', [notificationsProvider]),
            empty: const SizedBox.shrink(),
            builder: (_, _, _) => const [],
          ),
      },
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, NotifData d, NotifFilter filter, AppUser user, bool offline) {
    final unread = d.items.where((n) => !d.isRead(n)).length;
    final shown = d.items.where((n) => matchesFilter(n, filter, d.uid)).toList();
    final repo = ref.read(repositoryProvider);
    final labels = {
      NotifFilter.semua: 'Semua',
      NotifFilter.belumDibaca: 'Belum dibaca ($unread)',
      NotifFilter.deviasi: 'Deviasi',
      NotifFilter.model: 'Model',
      NotifFilter.data: 'Data',
      NotifFilter.batch: 'Batch',
    };

    void open(AppNotification n) {
      if (!d.isRead(n)) repo.markRead(user.uid, [n.id]);
      final role = user.role;
      final target = switch (n.type) {
        NotifType.degraded || NotifType.batch => AccessMatrix.canSeeEvaluasi(role) ? Routes.evaluasi : Routes.prediksi,
        _ => Routes.prediksi,
      };
      context.go(target);
    }

    return Column(children: [
      if (offline)
        Padding(
          padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.lg, WipasSpace.lg, 0),
          child: WipasOfflineBanner(lastSync: ref.watch(syncClockProvider)),
        ),
      const SizedBox(height: WipasSpace.sm),
      WipasFilterChipBar(children: [
        for (final f in NotifFilter.values)
          WipasFilterChip(
            label: labels[f]!,
            selected: f == filter,
            onTap: () => ref.read(notifFilterProvider.notifier).state = f,
          ),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
        child: Row(children: [
          Expanded(
            child: Text('$unread belum dibaca · ${d.items.length} total',
                style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
          ),
          if (unread > 0)
            WipasTextButton(
              label: 'Tandai semua dibaca',
              onPressed: () => repo.markRead(user.uid, d.items.where((n) => !d.isRead(n)).map((n) => n.id)),
            ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.sm, WipasSpace.lg, WipasSpace.xl),
          children: [
            if (d.items.isEmpty)
              const WipasEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Belum ada notifikasi',
                message: 'Notifikasi deviasi, kesehatan model, data, dan batch akan muncul di sini.',
              )
            else if (shown.isEmpty)
              const WipasEmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'Tidak ada notifikasi',
                message: 'Tidak ada notifikasi untuk filter ini.',
              )
            else
              WipasCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(WipasRadius.card),
                  child: Column(children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(),
                      Builder(builder: (_) {
                        final n = shown[i];
                        final s = _style(n.type);
                        return WipasNotificationTile(
                          icon: s.icon,
                          iconBg: s.bg,
                          iconColor: s.fg,
                          typeLabel: s.label,
                          typeColor: s.fg,
                          title: n.title,
                          body: n.body,
                          time: n.createdAt == null ? '' : Fmt.dateTime(n.createdAt!),
                          unread: !d.isRead(n),
                          onTap: () => open(n),
                        );
                      }),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}
