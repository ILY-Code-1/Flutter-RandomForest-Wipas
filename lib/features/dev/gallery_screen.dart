import 'package:flutter/material.dart';

import '../../core/domain/role.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/widgets.dart';

/// Debug-only component gallery (`/dev/gallery`) for comparing the Wipas
/// components with `docs/design/png/2 · Komponen inti.png`.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _segment = 0;
  int _stepper = 37;
  bool _switch = true;
  String _chip = 'Semua';

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: WipasSpace.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: WipasText.heading),
          const SizedBox(height: WipasSpace.sm),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WipasAppBarSub(title: 'Galeri komponen', subtitle: 'Hanya mode debug'),
      body: ListView(
        padding: const EdgeInsets.all(WipasSpace.lg),
        children: [
          _section('Logo & chip', [
            const Row(children: [WipasLogo(), SizedBox(width: 12), WipasReadOnlyChip(), SizedBox(width: 8), WipasCountBadge(3)]),
            const SizedBox(height: 8),
            Container(
              color: WipasColors.navy,
              padding: const EdgeInsets.all(8),
              child: const Wrap(spacing: 8, runSpacing: 8, children: [
                WipasRoleChip(role: Role.admin, label: 'Admin'),
                WipasRoleChip(role: Role.manajer, label: 'Manajer Warehouse'),
                WipasRoleChip(role: Role.supervisor, label: 'Supervisor Operasional'),
                WipasRoleChip(role: Role.viewer, label: 'Viewer · Tim DI'),
              ]),
            ),
          ]),
          _section('Status badge', [
            Wrap(spacing: 8, runSpacing: 8, children: [for (final k in StatusKind.values) WipasStatusBadge(k)]),
          ]),
          _section('Tombol', [
            WipasPrimaryButton(label: 'Setujui rekomendasi', icon: Icons.check, onPressed: () {}),
            const SizedBox(height: 8),
            const WipasPrimaryButton(label: 'Simpan', icon: Icons.save_outlined, disabledReason: offlineActionHint),
            const SizedBox(height: 8),
            const WipasPrimaryButton(label: 'Memuat', loading: true),
            const SizedBox(height: 8),
            WipasSecondaryButton(label: 'Sesuaikan manual', icon: Icons.edit_outlined, onPressed: () {}),
            const SizedBox(height: 8),
            WipasDestructiveButton(label: 'Keluar', icon: Icons.logout, onPressed: () {}),
            WipasTextButton(label: 'Lupa password?', onPressed: () {}),
          ]),
          _section('Banner', const [
            WipasAlertBanner(kind: AlertKind.info, body: 'Ini adalah rekomendasi sistem.'),
            SizedBox(height: 8),
            WipasAlertBanner(kind: AlertKind.warning, title: 'Deviasi 15,8% melewati ambang 15%', body: 'Peringatan sudah diteruskan.'),
            SizedBox(height: 8),
            WipasAlertBanner(kind: AlertKind.danger, title: 'Model Degraded', body: 'Rolling MAE melampaui ambang.'),
            SizedBox(height: 8),
            WipasAlertBanner(kind: AlertKind.success, title: 'File siap diunduh', body: 'riwayat.csv · 7 baris'),
            SizedBox(height: 8),
            WipasOfflineBanner(),
          ]),
          _section('Kartu', [
            const IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                    child: WipasKpiCard(
                        variant: KpiVariant.predicted, label: 'Predicted H+1', value: '18.420', unit: 'paket', delta: '+4,9% vs H-1')),
                SizedBox(width: 12),
                Expanded(
                    child: WipasKpiCard(
                        variant: KpiVariant.deviation,
                        label: 'Deviasi',
                        value: '15,8%',
                        unit: 'ambang 15%',
                        highlight: true,
                        delta: 'Perlu Perhatian')),
              ]),
            ),
            const SizedBox(height: 8),
            const WipasCard(
              child: Column(children: [
                WipasFeatureBar(label: 'Actual Inbound H-1', fraction: 0.27, highlight: true),
                WipasFeatureBar(label: 'Backlog H-1', fraction: 0.12),
                WipasDataRow(label: 'Pickup Request H-1', value: '21.300'),
                WipasDecisionLogItem(adjusted: true, actor: 'Budi Santoso', time: '9 Okt 2026 06:40', reason: 'Antrean backlog'),
              ]),
            ),
            const SizedBox(height: 8),
            WipasCard(
              padding: EdgeInsets.zero,
              child: WipasNotificationTile(
                icon: Icons.warning_amber_rounded,
                iconBg: WipasColors.warningTint,
                iconColor: WipasColors.warningText,
                typeLabel: 'Deviasi >15%',
                typeColor: WipasColors.warningText,
                title: 'Deviasi prediksi >15%',
                body: 'Predicted 18.420 vs Projection 15.900 (+15,8%).',
                time: 'Kam, 8 Okt 2026 23:02',
                unread: true,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 8),
            WipasCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: WipasListTile(icon: Icons.history, title: 'Riwayat & export', subtitle: 'Export CSV', badgeCount: 3, onTap: () {}),
            ),
          ]),
          _section('Input', [
            WipasSegmentedControl<int>(
              options: const [SegmentOption(0, 'Tabel', icon: Icons.table_chart_outlined), SegmentOption(1, 'Grafik')],
              selected: _segment,
              onChanged: (v) => setState(() => _segment = v),
            ),
            const SizedBox(height: 8),
            WipasFilterChipBar(children: [
              for (final c in const ['Semua', 'Belum dibaca (3)', 'Deviasi', 'Model', 'Data'])
                WipasFilterChip(label: c, selected: c == _chip, onTap: () => setState(() => _chip = c)),
            ]),
            const WipasTextField(label: 'Actual inbound (paket)', hint: 'Contoh: 17.560', suffixText: 'paket'),
            const SizedBox(height: 8),
            const WipasTextField(label: 'Actual inbound (paket)', errorText: 'Nilai tidak boleh negatif.', suffixText: 'paket'),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Rider')),
              WipasNumericStepper(value: _stepper, onChanged: (v) => setState(() => _stepper = v), label: 'Rider'),
            ]),
            WipasSwitch(label: 'Notifikasi di perangkat', value: _switch, onChanged: (v) => setState(() => _switch = v)),
          ]),
          _section('State', [
            const WipasSkeletonScreen(cards: 1),
            const WipasEmptyState(title: 'Belum ada prediksi', message: 'Prediksi muncul setelah batch berjalan.'),
            const SizedBox(height: 8),
            WipasErrorState(onRetry: () {}, attempts: 3),
          ]),
        ],
      ),
    );
  }
}
