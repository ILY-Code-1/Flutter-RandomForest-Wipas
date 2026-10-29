import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/calculators.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

class ManpowerData {
  const ManpowerData({required this.prediction, required this.config, required this.decisions});
  final Prediction? prediction;
  final CapacityConfig config;
  final List<DecisionLog> decisions;
}

final manpowerDataProvider = Provider.autoDispose<AsyncValue<ManpowerData>>((ref) {
  final latest = ref.watch(latestPredictionProvider);
  final config = ref.watch(configProvider);
  final p = latest.valueOrNull;
  final decisions = p == null ? const AsyncData<List<DecisionLog>>([]) : ref.watch(decisionsForProvider(p.id));
  return combineAsync([latest, config, decisions], () {
    final pred = latest.requireValue;
    return ManpowerData(
      prediction: pred,
      config: pred?.manpower?.configSnapshot ?? config.requireValue?.capacity ?? CapacityConfig.defaults,
      decisions: decisions.requireValue,
    );
  });
});

/// One manpower category.
class MpCategory {
  const MpCategory(this.key, this.label, this.longLabel);
  final String key;
  final String label;
  final String longLabel;

  int of(ManpowerCounts c) => switch (key) {
        'rider' => c.rider,
        'driver' => c.driver,
        'op_inbound' => c.opInbound,
        _ => c.opOutbound,
      };
}

const mpCategories = [
  MpCategory('rider', 'Rider', 'Rider'),
  MpCategory('driver', 'Driver', 'Driver'),
  MpCategory('op_inbound', 'Op. Inbound', 'Operator Inbound'),
  MpCategory('op_outbound', 'Op. Outbound', 'Operator Outbound'),
];

/// "Rider 40 (rekomendasi 37)" for every changed category.
String adjustmentSummary(ManpowerCounts finalCounts, ManpowerCounts? recommended) {
  final parts = <String>[];
  for (final c in mpCategories) {
    final f = c.of(finalCounts);
    final r = recommended == null ? null : c.of(recommended);
    if (r == null || f != r) parts.add('${c.label} $f${r == null ? '' : ' (rekomendasi $r)'}');
  }
  return parts.isEmpty ? 'Tanpa perubahan jumlah' : parts.join(', ');
}

class ManpowerScreen extends ConsumerWidget {
  const ManpowerScreen({super.key});

  static const retryKey = 'manpower';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final offline = ref.watch(isOfflineProvider);
    final state = toViewState<ManpowerData>(ref.watch(manpowerDataProvider),
        offline: offline,
        lastSync: ref.watch(syncClockProvider),
        isEmpty: (d) => d.prediction == null || d.prediction!.manpower == null);
    final readOnly = !AccessMatrix.canDecideManpower(user.role);

    return Scaffold(
      appBar: WipasAppBarTop(title: 'Rekomendasi Manpower', subtitle: ref.watch(screenSubtitleProvider)),
      body: WipasStateView<ManpowerData>(
        state: state,
        header: readOnly
            ? Container(
                width: double.infinity,
                color: WipasColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: WipasSpace.sm),
                child: const Align(alignment: Alignment.centerLeft, child: WipasReadOnlyChip()),
              )
            : null,
        attempts: ref.watch(retryCountProvider(retryKey)),
        onRetry: () => retryScreen(ref, retryKey, [latestPredictionProvider, configProvider, decisionsForProvider]),
        empty: Column(children: [
          if (offline) ...[WipasOfflineBanner(lastSync: ref.watch(syncClockProvider)), cardGap],
          const WipasEmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada rekomendasi',
            message: 'Rekomendasi manpower muncul setelah batch prediksi H+1 berjalan.',
          ),
        ]),
        builder: (context, d, offline) => _content(context, ref, d, offline, readOnly, user),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, ManpowerData d, bool offline, bool readOnly, AppUser user) {
    final p = d.prediction!;
    final rec = p.manpower!.counts;
    // Decision state comes from the prediction's App-owned decision_* fields.
    final decided = p.isDecided;
    final shown = p.decisionManpower ?? rec;
    final cfg = d.config;
    final today = ref.watch(todayProvider);
    final diff = p.targetDate.difference(today).inDays;
    final rel = diff == 0 ? 'hari ini' : (diff > 0 ? 'H+$diff' : 'H$diff');

    Widget status;
    if (!decided) {
      status = const WipasStatusBadge(StatusKind.menunggu, label: 'Menunggu persetujuan Manajer');
    } else if (p.isAdjusted) {
      status = const WipasStatusBadge(StatusKind.disesuaikan, label: 'Disesuaikan manual');
    } else {
      status = const WipasStatusBadge(StatusKind.disetujui);
    }

    return [
      WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kebutuhan untuk ${Fmt.date(p.targetDate)} ($rel)',
              style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: WipasSpace.sm, children: [
            Text(Fmt.number(p.predicted), style: WipasText.kpi.copyWith(fontSize: 32, height: 1.2)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('paket', style: WipasText.body.copyWith(color: WipasColors.textSecondary, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: WipasSpace.sm),
          status,
          const SizedBox(height: WipasSpace.md),
          Text('Parameter kapasitas per orang per hari', style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          const SizedBox(height: WipasSpace.sm),
          Wrap(spacing: WipasSpace.sm, runSpacing: WipasSpace.sm, children: [
            WipasTag('Rider ${Fmt.number(cfg.capacityRider)}'),
            WipasTag('Driver ${Fmt.number(cfg.capacityDriver)}'),
            WipasTag('Op. Inbound ${Fmt.number(cfg.capacityOpInbound)}'),
            WipasTag('Op. Outbound ${Fmt.number(cfg.capacityOpOutbound)}'),
            WipasTag('Rasio Rider ${Fmt.decimal(cfg.ratioRider, digits: 2)}'),
            WipasTag('Rasio Driver ${Fmt.decimal(cfg.ratioDriver, digits: 2)}'),
          ]),
        ]),
      ),
      cardGap,
      for (var row = 0; row < 4; row += 2) ...[
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = row; i < row + 2; i++) ...[
              if (i > row) const SizedBox(width: WipasSpace.md),
              Expanded(
                child: _CategoryCard(
                  category: mpCategories[i],
                  value: mpCategories[i].of(shown),
                  recommended: mpCategories[i].of(rec),
                  onHow: () => _showHow(context, mpCategories[i], p, cfg, rec),
                ),
              ),
            ],
          ]),
        ),
        cardGap,
      ],
      const WipasAlertBanner(
        kind: AlertKind.info,
        body: 'Ini adalah rekomendasi sistem. Keputusan akhir ada pada Manajer Operasional.',
      ),
      cardGap,
      if (!readOnly && !decided) ...[
        WipasPrimaryButton(
          key: const Key('btn-setujui'),
          label: 'Setujui rekomendasi',
          icon: Icons.check,
          disabledReason: offline ? offlineActionHint : null,
          onPressed: () => _approve(context, ref, p, rec, user),
        ),
        const SizedBox(height: WipasSpace.md),
        WipasSecondaryButton(
          key: const Key('btn-sesuaikan'),
          label: 'Sesuaikan manual',
          icon: Icons.edit_outlined,
          disabledReason: offline ? offlineActionHint : null,
          onPressed: () => _adjust(context, ref, p, rec, user),
        ),
        cardGap,
      ],
      _DecisionLogCard(decisions: d.decisions, recommended: rec, date: p.targetDate),
    ];
  }

  Future<void> _showHow(BuildContext context, MpCategory c, Prediction p, CapacityConfig cfg, ManpowerCounts rec) {
    final total = p.predicted ?? 0;
    final usesRatio = c.key == 'rider' || c.key == 'driver';
    final ratio = c.key == 'rider' ? cfg.ratioRider : cfg.ratioDriver;
    final cap = switch (c.key) {
      'rider' => cfg.capacityRider,
      'driver' => cfg.capacityDriver,
      'op_inbound' => cfg.capacityOpInbound,
      _ => cfg.capacityOpOutbound,
    };
    final numerator = usesRatio ? total * ratio : total.toDouble();
    final raw = numerator / cap;
    final formula = usesRatio
        ? '${c.label} = (Total paket × rasio ${c.label}) ÷ kapasitas ${c.label}'
        : '${c.label} = Total paket ÷ kapasitas ${c.label}';
    final subst1 = usesRatio
        ? '(${Fmt.number(total)} × ${Fmt.decimal(ratio, digits: 2)}) ÷ ${Fmt.number(cap)}'
        : '${Fmt.number(total)} ÷ ${Fmt.number(cap)}';
    final subst2 = usesRatio
        ? '${Fmt.number(numerator)} ÷ ${Fmt.number(cap)} = ${Fmt.decimal(raw, digits: 2)}'
        : '= ${Fmt.decimal(raw, digits: 2)}';
    return showWipasBottomSheet<void>(
      context,
      title: 'Cara hitung · ${c.label}',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(WipasSpace.lg),
          decoration: BoxDecoration(color: WipasColors.background, borderRadius: BorderRadius.circular(WipasRadius.card)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rumus', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            Text(formula, style: WipasText.heading),
          ]),
        ),
        const SizedBox(height: WipasSpace.sm),
        WipasDataRow(label: 'Total prediksi', value: '${Fmt.number(total)} paket', divider: false),
        WipasDataRow(
          label: usesRatio ? 'Rasio ${c.label} · kapasitas' : 'Kapasitas',
          value: usesRatio
              ? '${Fmt.decimal(ratio, digits: 2)} · ${Fmt.number(cap)} paket/hari'
              : '${Fmt.number(cap)} paket/hari',
          divider: false,
        ),
        const SizedBox(height: WipasSpace.sm),
        Container(
          padding: const EdgeInsets.all(WipasSpace.lg),
          decoration: BoxDecoration(color: WipasColors.chipFill, borderRadius: BorderRadius.circular(WipasRadius.card)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Substitusi angka', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            Text(subst1, style: WipasText.heading.copyWith(fontWeight: FontWeight.w500)),
            Text(subst2, style: WipasText.heading.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: WipasSpace.xs),
            Text('Dibulatkan ke atas: ${c.of(rec)} orang', style: WipasText.heading.copyWith(color: WipasColors.navy)),
          ]),
        ),
        const SizedBox(height: WipasSpace.lg),
        WipasSecondaryButton(label: 'Tutup', onPressed: () => Navigator.of(ctx).pop()),
      ]),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, Prediction p, ManpowerCounts rec, AppUser user) async {
    final ok = await showWipasConfirmDialog(
      context,
      title: 'Setujui rekomendasi?',
      body: 'Anda menyetujui Rider ${rec.rider}, Driver ${rec.driver}, Op. Inbound ${rec.opInbound}, dan '
          'Op. Outbound ${rec.opOutbound} untuk ${Fmt.date(p.targetDate)}. Keputusan akan dicatat di log.',
      confirmLabel: 'Setujui',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(repositoryProvider).addDecision(
            prediction: p,
            uid: user.uid,
            name: user.displayName,
            decision: DecisionStatus.approved,
            manpowerFinal: rec,
          );
      if (context.mounted) showWipasSnackBar(context, 'Rekomendasi disetujui dan dicatat di log.');
    } catch (e) {
      if (context.mounted) showWipasSnackBar(context, 'Gagal menyimpan keputusan. Coba lagi.');
    }
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Prediction p, ManpowerCounts rec, AppUser user) async {
    final result = await showWipasBottomSheet<(ManpowerCounts, String)>(
      context,
      title: 'Sesuaikan manual',
      builder: (_) => AdjustSheet(recommended: rec),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(repositoryProvider).addDecision(
            prediction: p,
            uid: user.uid,
            name: user.displayName,
            decision: DecisionStatus.adjusted,
            manpowerFinal: result.$1,
            reason: result.$2,
          );
      if (context.mounted) showWipasSnackBar(context, 'Penyesuaian disimpan dan dicatat di log.');
    } catch (_) {
      if (context.mounted) showWipasSnackBar(context, 'Gagal menyimpan penyesuaian. Coba lagi.');
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.value, required this.recommended, required this.onHow});
  final MpCategory category;
  final int value;
  final int recommended;
  final VoidCallback onHow;

  @override
  Widget build(BuildContext context) {
    final changed = value != recommended;
    return Container(
      decoration: BoxDecoration(
        color: WipasColors.surface,
        borderRadius: BorderRadius.circular(WipasRadius.card),
        border: Border.all(color: changed ? WipasColors.infoBorder : WipasColors.border),
        boxShadow: WipasElevation.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.md, WipasSpace.lg, WipasSpace.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category.label, style: WipasText.body.copyWith(color: WipasColors.textSecondary, fontWeight: FontWeight.w600)),
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: WipasSpace.sm, children: [
              Text('$value', style: WipasText.kpi.copyWith(fontSize: 30, height: 1.2)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('orang', style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
              ),
            ]),
            Text(changed ? 'Rekomendasi $recommended' : 'Rekomendasi sistem',
                style: WipasText.bodySmall.copyWith(color: changed ? WipasColors.infoText : WipasColors.textSecondary)),
          ]),
        ),
        const Spacer(),
        const Divider(),
        Center(
          child: WipasTextButton(
            label: 'Cara hitung',
            icon: Icons.receipt_long_outlined,
            onPressed: onHow,
          ),
        ),
      ]),
    );
  }
}

/// Bottom sheet content: four steppers + mandatory reason.
class AdjustSheet extends StatefulWidget {
  const AdjustSheet({super.key, required this.recommended});
  final ManpowerCounts recommended;

  static const reasonRequired = 'Alasan wajib diisi.';

  @override
  State<AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<AdjustSheet> {
  late ManpowerCounts _counts = widget.recommended;
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _set(String key, int v) => setState(() {
        _counts = switch (key) {
          'rider' => _counts.copyWith(rider: v),
          'driver' => _counts.copyWith(driver: v),
          'op_inbound' => _counts.copyWith(opInbound: v),
          _ => _counts.copyWith(opOutbound: v),
        };
      });

  void _save() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = AdjustSheet.reasonRequired);
      return;
    }
    Navigator.of(context).pop((_counts, reason));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in mpCategories)
        Container(
          padding: const EdgeInsets.symmetric(vertical: WipasSpace.sm),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WipasColors.divider))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.label, style: WipasText.heading),
                Builder(builder: (_) {
                  final r = c.of(widget.recommended);
                  final d = c.of(_counts) - r;
                  return Text(
                    d == 0 ? 'Rekomendasi $r' : 'Rekomendasi $r (${d > 0 ? '+' : '−'}${d.abs()})',
                    style: WipasText.bodySmall.copyWith(color: d == 0 ? WipasColors.textSecondary : WipasColors.infoText),
                  );
                }),
              ]),
            ),
            WipasNumericStepper(label: c.label, value: c.of(_counts), onChanged: (v) => _set(c.key, v)),
          ]),
        ),
      const SizedBox(height: WipasSpace.lg),
      WipasTextField(
        label: 'Alasan penyesuaian (wajib)',
        controller: _reason,
        fieldKey: const Key('adjust-reason'),
        hint: 'Contoh: Antrean backlog 640 paket perlu tambahan kurir',
        maxLines: 3,
        minLines: 3,
        errorText: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      const SizedBox(height: WipasSpace.lg),
      Row(children: [
        Expanded(child: WipasSecondaryButton(label: 'Batal', onPressed: () => Navigator.of(context).pop())),
        const SizedBox(width: WipasSpace.md),
        Expanded(
          child: WipasPrimaryButton(key: const Key('btn-simpan-penyesuaian'), label: 'Simpan penyesuaian', onPressed: _save),
        ),
      ]),
    ]);
  }
}

class _DecisionLogCard extends StatelessWidget {
  const _DecisionLogCard({required this.decisions, required this.recommended, required this.date});
  final List<DecisionLog> decisions;
  final ManpowerCounts recommended;
  final DateTime date;

  @override
  Widget build(BuildContext context) => WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WipasCardHeader(title: 'Log keputusan', leading: Icon(Icons.format_list_bulleted, color: WipasColors.textPrimary)),
          const SizedBox(height: WipasSpace.sm),
          if (decisions.isEmpty)
            Text(
              'Belum ada keputusan untuk ${Fmt.dayMonthYear(date)}. Setiap persetujuan atau penyesuaian dicatat '
              'beserta waktu dan alasannya.',
              style: WipasText.body.copyWith(color: WipasColors.textSecondary),
            )
          else
            for (final d in decisions)
              Container(
                margin: const EdgeInsets.only(bottom: WipasSpace.sm),
                padding: const EdgeInsets.only(left: WipasSpace.md),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: d.isAdjusted ? WipasColors.info : WipasColors.success, width: 3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    d.isAdjusted
                        ? 'Disesuaikan: ${adjustmentSummary(d.manpowerFinal ?? recommended, recommended)}'
                            '${(d.reason ?? '').isEmpty ? '' : ' · alasan: ${d.reason}'}'
                        : 'Disetujui: Rider ${recommended.rider}, Driver ${recommended.driver}, '
                            'Op. Inbound ${recommended.opInbound}, Op. Outbound ${recommended.opOutbound}',
                    style: WipasText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text('oleh ${d.decidedByName} · ${d.decidedAt == null ? 'menyinkronkan…' : Fmt.logTime(d.decidedAt!)}',
                      style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                ]),
              ),
        ]),
      );
}
