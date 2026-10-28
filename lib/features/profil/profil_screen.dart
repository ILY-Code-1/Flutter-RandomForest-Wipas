import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_controller.dart';
import '../common/common.dart';

/// Local preference: show in-app notification badges (no push in this release).
final notifPrefProvider = StateNotifierProvider<_BoolPref, bool>(
    (ref) => _BoolPref(ref, 'pref_in_app_notifications', defaultValue: true));

class _BoolPref extends StateNotifier<bool> {
  _BoolPref(this._ref, this._key, {required bool defaultValue})
      : super(_ref.read(sharedPrefsProvider).getBool(_key) ?? defaultValue);
  final Ref _ref;
  final String _key;

  void set(bool v) {
    state = v;
    _ref.read(sharedPrefsProvider).setBool(_key, v);
  }
}

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final hub = ref.watch(warehouseNameProvider);
    final repo = ref.watch(repositoryProvider);
    final notifOn = ref.watch(notifPrefProvider);
    final modelVersion = ref.watch(modelHealthProvider).valueOrNull?.modelVersion;

    Future<void> logout() async {
      final ok = await showWipasConfirmDialog(
        context,
        title: 'Keluar dari WIPAS?',
        body: 'Anda perlu masuk kembali dengan email dan password untuk membuka aplikasi.',
        confirmLabel: 'Keluar',
        destructive: true,
      );
      if (!ok) return;
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.go(Routes.login);
    }

    return Scaffold(
      appBar: WipasAppBarSub(
        title: 'Profil & Pengaturan',
        subtitle: ref.watch(screenSubtitleProvider),
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.lainnya),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WipasSpace.lg),
        children: [
          WipasCard(
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: WipasColors.navy,
                child: Text(user.initials, style: WipasText.title.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: WipasSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName, style: WipasText.heading.copyWith(fontSize: 18)),
                  Text(user.email, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                  const SizedBox(height: WipasSpace.xs),
                  WipasTag(user.role.label),
                ]),
              ),
            ]),
          ),
          cardGap,
          WipasCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const WipasCardHeader(title: 'Info akun'),
              WipasDataRow(label: 'Hub', value: '$hub (${repo.whId})'),
              WipasDataRow(label: 'Role', value: user.roleChipLabel),
              WipasDataRow(label: 'Email', value: user.email),
              const SizedBox(height: WipasSpace.sm),
              Text('Akun dibuat dan dikelola oleh administrator.',
                  style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            ]),
          ),
          cardGap,
          WipasCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const WipasCardHeader(title: 'Pengaturan'),
              WipasSwitch(
                label: 'Notifikasi di perangkat',
                subtitle: notifOn ? 'Aktif' : 'Nonaktif',
                value: notifOn,
                onChanged: (v) {
                  ref.read(notifPrefProvider.notifier).set(v);
                  showWipasSnackBar(context, v ? 'Notifikasi diaktifkan.' : 'Notifikasi dinonaktifkan.');
                },
              ),
              const Divider(),
              const WipasDataRow(label: 'Bahasa', value: 'Indonesia'),
              const WipasDataRow(label: 'Tema', value: 'Terang', divider: false),
            ]),
          ),
          cardGap,
          const WipasAlertBanner(
            kind: AlertKind.info,
            body: 'Otomatis keluar setelah 24 jam. Anda akan diminta masuk kembali.',
          ),
          cardGap,
          WipasCard(
            child: Column(children: [
              const WipasDataRow(label: 'Versi aplikasi', value: 'WIPAS ${AppConfig.appVersion} (build ${AppConfig.appBuild})'),
              WipasDataRow(label: 'Versi model', value: modelVersion ?? '—', divider: false),
            ]),
          ),
          cardGap,
          WipasDestructiveButton(label: 'Keluar', icon: Icons.logout, onPressed: logout),
        ],
      ),
    );
  }
}
