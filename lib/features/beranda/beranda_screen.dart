import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/calculators.dart';
import '../../core/domain/role.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

/// Data shared by Beranda and Prediksi: the latest batch (H+1 anchor) and
/// the last 30 days of predictions (oldest → newest).
class DashboardData {
  const DashboardData({required this.anchor, required this.history, required this.health});

  final Prediction? anchor;
  final List<Prediction> history;
  final ModelHealth? health;

  Prediction? byDate(DateTime d) {
    for (final p in history) {
      if (p.targetDate == d) return p;
    }
    return null;
  }

  /// Predictions in the [days]-day window ending at [end].
  List<Prediction> window(DateTime end, int days) {
    final start = end.subtract(Duration(days: days - 1));
    return history.where((p) => !p.targetDate.isBefore(start) && !p.targetDate.isAfter(end)).toList();
  }
}

/// Window size of the dashboard query (bounded reads).
const dashboardDays = 30;

final dashboardProvider = Provider.autoDispose<AsyncValue<DashboardData>>((ref) {
  final latest = ref.watch(latestPredictionProvider);
  final anchorDate = latest.valueOrNull?.targetDate;
  final today = ref.watch(todayProvider);
  final end = anchorDate ?? today.add(const Duration(days: 1));
  final history = ref.watch(predictionsInRangeProvider((end: end, days: dashboardDays)));
  final health = ref.watch(modelHealthProvider);
  return combineAsync([latest, history, health], () {
    final list = [...history.requireValue]..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    return DashboardData(anchor: latest.requireValue, history: list, health: health.requireValue);
  });
});

/// Retry wiring shared by Beranda and Prediksi.
final dashboardProviders = <ProviderOrFamily>[latestPredictionProvider, predictionsInRangeProvider, modelHealthProvider];

/// Label for a target date relative to today ("(H+1)", "(hari ini)").
String relativeLabel(DateTime date, DateTime today) {
  final diff = date.difference(today).inDays;
  if (diff == 0) return 'hari ini';
  return diff > 0 ? 'H+$diff' : 'H$diff';
}

class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  static const retryKey = 'beranda';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final hub = ref.watch(warehouseNameProvider);
    final repo = ref.watch(repositoryProvider);
    final data = ref.watch(dashboardProvider);
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<DashboardData>(
      data,
      offline: offline,
      lastSync: ref.watch(syncClockProvider),
      isEmpty: (d) => d.anchor == null,
    );

    return Scaffold(
      appBar: WipasAppBarTop(
        title: '$hub (${repo.whId})',
        // The role chip keeps its natural width (up to 72% of the row); the
        // name takes the rest and is ellipsized first.
        subtitleWidget: LayoutBuilder(
          builder: (context, c) => Row(children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.72),
              child: WipasRoleChip(role: user.role, label: user.roleChipLabel),
            ),
            const SizedBox(width: WipasSpace.md),
            Expanded(
              child: Text(user.displayName,
                  overflow: TextOverflow.ellipsis, style: WipasText.bodySmall.copyWith(color: Colors.white)),
            ),
          ]),
        ),
        unreadCount: ref.watch(unreadCountProvider),
        onBell: () => context.push(Routes.notifikasi),
      ),
      body: WipasStateView<DashboardData>(
        state: state,
        attempts: ref.watch(retryCountProvider(retryKey)),
        onRetry: () => retryScreen(ref, retryKey, dashboardProviders),
        empty: Column(children: [
          if (offline) ...[WipasOfflineBanner(lastSync: ref.watch(syncClockProvider)), cardGap],
          const WipasEmptyState(
            icon: Icons.insights_outlined,
            title: 'Belum ada data batch',
            message: 'Prediksi muncul setelah script batch harian dijalankan dan data diimpor dari Excel.',
          ),
        ]),
        builder: (context, d, offline) => _content(context, ref, d, offline, user),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, DashboardData d, bool offline, AppUser user) {
    final role = user.role;
    final today = ref.watch(todayProvider);
    final anchor = d.anchor!;
    final selectedDate = ref.watch(selectedDateProvider) ?? anchor.targetDate;
    final p = d.byDate(selectedDate);
    final minDate = anchor.targetDate.subtract(const Duration(days: dashboardDays - 1));
    final rel = relativeLabel(selectedDate, today);

    void select(DateTime date) => ref.read(selectedDateProvider.notifier).state = date;

    return [
      WipasInfoLine(
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Prediksi dihitung ${anchor.generatedAt == null ? '—' : Fmt.dateTimeWib(anchor.generatedAt!)}'
                  ' · Model ${anchor.modelVersion ?? '—'} · Sumber: '),
          TextSpan(
              text: 'Data ${anchor.sourceLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: WipasColors.textPrimary)),
        ])),
      ),
      const SizedBox(height: WipasSpace.md),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Tanggal target prediksi · '),
          TextSpan(
              text: '${Fmt.date(selectedDate)} ($rel)',
              style: const TextStyle(fontWeight: FontWeight.w700, color: WipasColors.textPrimary)),
        ]),
        style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary, fontSize: 14),
      ),
      const SizedBox(height: WipasSpace.sm),
      WipasDatePickerStrip(
        selected: selectedDate,
        maxDate: anchor.targetDate,
        minDate: minDate,
        today: today,
        onSelected: select,
      ),
      const SizedBox(height: WipasSpace.md),
      if (p == null)
        WipasEmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Belum ada prediksi untuk tanggal terpilih',
          message: 'Pilih tanggal lain atau kembali ke tanggal target terbaru.',
          action: WipasSecondaryButton(label: 'Kembali ke H+1', onPressed: () => select(anchor.targetDate)),
        )
      else
        ..._forPrediction(context, ref, d, p, rel, offline, role),
    ];
  }

  List<Widget> _forPrediction(
      BuildContext context, WidgetRef ref, DashboardData d, Prediction p, String rel, bool offline, Role role) {
    final health = d.health;
    final h1 = d.byDate(p.targetDate.subtract(const Duration(days: 1)));
    final actualH1 = h1?.actualInbound ?? p.inputFeatures.actualInboundH1;
    final dev = p.deviation;
    final gap = (p.predicted != null && p.projection != null) ? p.predicted! - p.projection! : null;
    final vsH1 = (p.predicted != null && actualH1 != null && actualH1 > 0) ? (p.predicted! - actualH1) / actualH1 * 100 : null;
    final trend = d.window(p.targetDate, 14);
    final writeHint = offline ? offlineActionHint : null;

    return [
      if (p.isFallback) ...[
        WipasAlertBanner(
          kind: AlertKind.warning,
          title: 'Fallback H-2 · Data Incomplete Warning',
          body: 'Data H-1 terlambat. Model memakai Actual H-2'
              '${p.inputFeatures.actualInboundH2 == null ? '' : ' (${Fmt.number(p.inputFeatures.actualInboundH2)})'} sebagai pengganti.',
        ),
        cardGap,
      ],
      if (p.needsAttention && dev != null) ...[
        _deviationBanner(role, p, dev, gap),
        cardGap,
      ],
      if (health != null && health.isDegraded) ...[
        WipasAlertBanner(
          kind: AlertKind.danger,
          title: 'Model Degraded',
          body: 'Rolling MAE 7 hari ${Fmt.percent(health.rollingMae7d)} melampaui ambang drift '
              '${Fmt.percent(health.threshold)}. Prediksi tetap tampil sebagai rekomendasi.',
          action: AccessMatrix.canSeeEvaluasi(role)
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: WipasTextButton(
                      label: 'Lihat Evaluasi', trailingIcon: Icons.chevron_right, onPressed: () => context.go(Routes.evaluasi)),
                )
              : null,
        ),
        cardGap,
      ],
      ..._roleActions(context, ref, role, p, writeHint, health),
      _kpiGrid(p, actualH1, dev, gap, vsH1),
      cardGap,
      WipasChartCard(
        title: 'Tren inbound 14 hari',
        subtitle: trend.isEmpty
            ? null
            : 'Projection vs Predicted vs Actual (paket), ${Fmt.range(trend.first.targetDate, trend.last.targetDate)}',
        chart: TrendChart(points: trend, markDate: p.targetDate, markLabel: rel == 'hari ini' ? 'Hari ini' : rel),
        legend: trendLegend,
        summary: trendSummary(trend),
        footer: TrendTooltipBox(p: p, label: '${Fmt.date(p.targetDate)} ($rel)'),
      ),
      cardGap,
      if (AccessMatrix.canSeeManpower(role)) ...[
        _ManpowerSummaryCard(p: p, role: role),
        cardGap,
      ],
      if (health != null) _ModelHealthCard(health: health, role: role),
    ];
  }

  Widget _deviationBanner(Role role, Prediction p, double dev, int? gap) {
    final title = 'Deviasi ${Fmt.percent(dev.abs())} melewati ambang ${Fmt.percent(DeviationCalculator.thresholdPct, digits: 0)}';
    if (role == Role.manajer) {
      return WipasAlertBanner(
        kind: AlertKind.warning,
        title: title,
        body: 'Tinjau rekomendasi sebelum menyetujui alokasi. Keputusan akhir ada di Anda.',
        child: Column(children: [
          const Divider(color: WipasColors.warning, height: WipasSpace.lg),
          Row(children: [
            Expanded(child: _bannerStat('Predicted', Fmt.number(p.predicted))),
            Expanded(child: _bannerStat('Projection', Fmt.number(p.projection))),
            Expanded(child: _bannerStat('Selisih', gap == null ? '—' : Fmt.signedNumber(gap))),
          ]),
        ]),
      );
    }
    return WipasAlertBanner(
      kind: AlertKind.warning,
      title: title,
      body: 'Peringatan sudah diteruskan ke Manajer Warehouse.',
    );
  }

  Widget _bannerStat(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: WipasText.bodySmall.copyWith(color: WipasColors.warningText)),
        Text(v, style: WipasText.heading.copyWith(color: WipasColors.warningText, fontFeatures: const [FontFeature.tabularFigures()])),
      ]);

  List<Widget> _roleActions(
      BuildContext context, WidgetRef ref, Role role, Prediction p, String? writeHint, ModelHealth? health) {
    switch (role) {
      case Role.admin:
        return [
          WipasPrimaryButton(
            label: 'Input Actual Inbound',
            icon: Icons.add,
            onPressed: () => context.push(Routes.inputActual),
          ),
          const SizedBox(height: WipasSpace.md),
          WipasSecondaryButton(
            label: 'Konfigurasi Kapasitas',
            icon: Icons.tune,
            onPressed: () => context.push(Routes.konfigurasi),
          ),
          cardGap,
        ];
      case Role.supervisor:
        return [
          WipasPrimaryButton(
            label: 'Input Actual Inbound',
            icon: Icons.add,
            onPressed: () => context.push(Routes.inputActual),
          ),
          cardGap,
        ];
      case Role.manajer:
        final decisions = ref.watch(decisionsForProvider(p.id)).valueOrNull ?? const [];
        final last = decisions.isEmpty ? null : decisions.first;
        return [
          WipasCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alokasi ${Fmt.date(p.targetDate)}', style: WipasText.heading.copyWith(fontSize: 18)),
              const SizedBox(height: WipasSpace.sm),
              if (last == null)
                const WipasStatusBadge(StatusKind.belum, label: 'Menunggu persetujuan')
              else
                WipasStatusBadge(last.isAdjusted ? StatusKind.disesuaikan : StatusKind.disetujui),
              const SizedBox(height: WipasSpace.sm),
              Text('Setiap persetujuan dan penyesuaian manual tercatat di decision log.',
                  style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
              const SizedBox(height: WipasSpace.md),
              WipasPrimaryButton(
                label: last == null ? 'Tinjau & Setujui Alokasi' : 'Lihat alokasi',
                icon: Icons.check,
                onPressed: () => context.go(Routes.manpower),
              ),
            ]),
          ),
          cardGap,
        ];
      case Role.viewer:
        return [
          Row(children: [
            const WipasReadOnlyChip(),
            const SizedBox(width: WipasSpace.md),
            Expanded(
              child: Text('Dashboard tanpa akses ubah', style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
            ),
          ]),
          cardGap,
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _ViewerTile(
                  icon: Icons.verified_user_outlined,
                  iconColor: health?.isDegraded == true ? WipasColors.danger : WipasColors.teal,
                  title: 'Model Health',
                  body: 'Rolling MAE 7 hari ${Fmt.percent(health?.rollingMae7d)} · '
                      '${health?.isDegraded == true ? 'Degraded' : 'Sehat'}',
                  onTap: () => context.go(Routes.evaluasi),
                ),
              ),
              const SizedBox(width: WipasSpace.md),
              Expanded(
                child: _ViewerTile(
                  icon: Icons.bar_chart,
                  iconColor: WipasColors.navy,
                  title: 'Evaluasi Projection',
                  body: 'Projection vs Actual',
                  onTap: () => context.go(Routes.evaluasi),
                ),
              ),
            ]),
          ),
          cardGap,
        ];
    }
  }

  Widget _kpiGrid(Prediction p, int? actualH1, double? dev, int? gap, double? vsH1) {
    final attention = p.needsAttention;
    return Column(children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: WipasKpiCard(
              variant: KpiVariant.predicted,
              label: 'Predicted H+1',
              value: Fmt.number(p.predicted),
              unit: 'paket',
              delta: vsH1 == null ? null : '${Fmt.signedPercent(vsH1)} vs H-1',
              deltaIcon: (vsH1 ?? 0) >= 0 ? Icons.trending_up : Icons.trending_down,
              deltaColor: WipasColors.tealText,
            ),
          ),
          const SizedBox(width: WipasSpace.md),
          Expanded(
            child: WipasKpiCard(
              variant: KpiVariant.projection,
              label: 'Projection (Tim DI)',
              value: Fmt.number(p.projection),
              unit: 'paket',
              delta: gap == null ? null : 'Selisih ${Fmt.signedNumber(gap)}',
              deltaIcon: Icons.arrow_forward,
            ),
          ),
        ]),
      ),
      cardGap,
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: WipasKpiCard(
              variant: KpiVariant.actual,
              label: 'Actual H-1',
              value: actualH1 == null ? '—' : Fmt.number(actualH1),
              unit: actualH1 == null ? 'belum diterima' : 'paket',
              delta: p.inputFeatures.backlogH1 == null ? null : 'Backlog ${Fmt.number(p.inputFeatures.backlogH1)} paket',
              deltaIcon: Icons.local_shipping_outlined,
              deltaColor: WipasColors.textPrimary,
            ),
          ),
          const SizedBox(width: WipasSpace.md),
          Expanded(
            child: WipasKpiCard(
              variant: KpiVariant.deviation,
              label: 'Deviasi',
              value: dev == null ? '—' : Fmt.percent(dev.abs()),
              unit: 'ambang ${Fmt.percent(DeviationCalculator.thresholdPct, digits: 0)}',
              highlight: attention,
              delta: attention ? 'Perlu Perhatian' : 'Normal',
              deltaIcon: attention ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              deltaColor: attention ? WipasColors.warningText : WipasColors.successText,
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _ViewerTile extends StatelessWidget {
  const _ViewerTile({required this.icon, required this.iconColor, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WipasCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: WipasSpace.sm),
          Text(title, style: WipasText.heading),
          Text(body, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        ]),
      );
}

const _mpIcons = [Icons.pedal_bike, Icons.local_shipping_outlined, Icons.download, Icons.upload];
const _mpLabels = ['Rider', 'Driver', 'Operator Inbound', 'Operator Outbound'];

class _ManpowerSummaryCard extends StatelessWidget {
  const _ManpowerSummaryCard({required this.p, required this.role});
  final Prediction p;
  final Role role;

  @override
  Widget build(BuildContext context) {
    final c = p.manpower?.counts;
    final values = c == null ? null : [c.rider, c.driver, c.opInbound, c.opOutbound];
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WipasCardHeader(
          title: 'Rekomendasi Manpower',
          subtitle: '${Fmt.date(p.targetDate)} · dibulatkan ke atas',
          trailing: AccessMatrix.isReadOnly(role, Routes.manpower) ? const WipasReadOnlyChip() : null,
        ),
        const SizedBox(height: WipasSpace.sm),
        if (values == null)
          Text('Rekomendasi belum tersedia.', style: WipasText.body.copyWith(color: WipasColors.textSecondary))
        else
          for (var i = 0; i < 4; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: i < 3 ? const BoxDecoration(border: Border(bottom: BorderSide(color: WipasColors.divider))) : null,
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: WipasColors.chipFill, child: Icon(_mpIcons[i], size: 20, color: WipasColors.navy)),
                const SizedBox(width: WipasSpace.md),
                Expanded(child: Text(_mpLabels[i], style: WipasText.body.copyWith(fontSize: 15))),
                Text('${values[i]}', style: WipasText.kpi.copyWith(fontSize: 22, height: 1.2)),
                const SizedBox(width: 6),
                Text('orang', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
              ]),
            ),
        const SizedBox(height: WipasSpace.sm),
        const WipasInfoLine(child: Text('Hasil prediksi adalah rekomendasi, bukan perintah.')),
        const SizedBox(height: WipasSpace.md),
        WipasSecondaryButton(
          label: 'Lihat detail',
          icon: null,
          onPressed: () => context.go(Routes.manpower),
        ),
      ]),
    );
  }
}

class _ModelHealthCard extends StatelessWidget {
  const _ModelHealthCard({required this.health, required this.role});
  final ModelHealth health;
  final Role role;

  @override
  Widget build(BuildContext context) {
    final mae = health.rollingMae7d;
    final thr = health.threshold;
    final base = health.baselineMae;
    String note;
    if (health.isDegraded) {
      note = 'Rolling MAE melampaui ambang drift. Disarankan review & retraining manual.';
    } else if (mae != null && thr != null && thr - mae <= 0.5) {
      note = 'Sehat, tetapi mendekati ambang drift (selisih ${Fmt.decimal(thr - mae)} poin).';
    } else {
      note = 'Sehat · Rolling MAE di bawah ambang drift.';
    }
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WipasCardHeader(
          title: 'Model Health',
          subtitle: 'Rolling MAE 7 hari',
          trailing: WipasStatusBadge(health.isDegraded ? StatusKind.degraded : StatusKind.sehat),
        ),
        const SizedBox(height: WipasSpace.sm),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: WipasSpace.sm, children: [
          Text(Fmt.percent(mae),
              style: WipasText.kpi.copyWith(color: health.isDegraded ? WipasColors.danger : WipasColors.textPrimary)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Rolling MAE 7 hari · ambang drift ${Fmt.percent(thr)}',
                style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: WipasSpace.md),
        if (mae != null && thr != null) MaeGauge(mae: mae, threshold: thr, baseline: base),
        const SizedBox(height: WipasSpace.md),
        Row(children: [
          Expanded(child: _metric('MAE validasi', Fmt.percent(health.maeValidation))),
          Expanded(child: _metric('RMSE', Fmt.percent(health.rmse))),
          Expanded(child: _metric('R²', health.r2 == null ? '—' : Fmt.decimal(health.r2!, digits: 2))),
        ]),
        const SizedBox(height: WipasSpace.sm),
        Text(note, style: WipasText.bodySmall),
        if (AccessMatrix.canSeeEvaluasi(role))
          WipasTextButton(label: 'Lihat Evaluasi', trailingIcon: Icons.chevron_right, onPressed: () => context.go(Routes.evaluasi)),
      ]),
    );
  }

  Widget _metric(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        Text(v, style: WipasText.bodyStrong.copyWith(fontWeight: FontWeight.w700)),
      ]);
}

/// Horizontal bar of the rolling MAE with threshold (red) and baseline (grey)
/// markers; labels are placed so they do not overlap the bar.
class MaeGauge extends StatelessWidget {
  const MaeGauge({super.key, required this.mae, required this.threshold, this.baseline});
  final double mae;
  final double threshold;
  final double? baseline;

  @override
  Widget build(BuildContext context) {
    final maxV = (threshold * 1.25).clamp(mae * 1.1, double.infinity);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double pos(double v) => (v / maxV * w).clamp(0, w);
      return SizedBox(
        height: 58,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: (pos(threshold) - 100).clamp(0, w - 110),
            width: 110,
            top: 0,
            child: Text('Ambang drift ${Fmt.percent(threshold)}',
                textAlign: TextAlign.right, style: WipasText.caption.copyWith(color: WipasColors.dangerText)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 20,
            child: Container(
              height: 14,
              decoration: BoxDecoration(color: WipasColors.divider, borderRadius: BorderRadius.circular(WipasRadius.pill)),
              alignment: Alignment.centerLeft,
              child: Container(
                width: pos(mae),
                decoration: BoxDecoration(
                  color: mae > threshold ? WipasColors.danger : WipasColors.primaryLight,
                  borderRadius: BorderRadius.circular(WipasRadius.pill),
                ),
              ),
            ),
          ),
          Positioned(left: pos(threshold) - 1, top: 16, child: Container(width: 3, height: 22, color: WipasColors.danger)),
          if (baseline != null) ...[
            Positioned(left: pos(baseline!) - 1, top: 18, child: Container(width: 2, height: 18, color: WipasColors.textSecondary)),
            Positioned(
              left: (pos(baseline!) - 60).clamp(0, w - 120),
              width: 120,
              top: 40,
              child: Text('Baseline ${Fmt.percent(baseline)}',
                  textAlign: TextAlign.center, style: WipasText.caption),
            ),
          ],
        ]),
      );
    });
  }
}
