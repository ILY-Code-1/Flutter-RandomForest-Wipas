import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/calculators.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

class KonfigurasiData {
  const KonfigurasiData({required this.config, required this.latest, required this.history});
  final CapacityConfig config;
  final Prediction? latest;
  final List<ConfigHistoryEntry> history;
}

final konfigurasiDataProvider = Provider.autoDispose<AsyncValue<KonfigurasiData>>((ref) {
  final cfg = ref.watch(configProvider);
  final latest = ref.watch(latestPredictionProvider);
  final history = ref.watch(configHistoryProvider);
  return combineAsync([cfg, latest, history], () => KonfigurasiData(
        config: cfg.requireValue?.capacity ?? CapacityConfig.defaults,
        latest: latest.requireValue,
        history: history.requireValue,
      ));
});

class _Field {
  const _Field(this.key, this.label, this.helper, this.unit, this.isRatio);
  final String key;
  final String label;
  final String helper;
  final String unit;
  final bool isRatio;
}

const _fields = [
  _Field('capacity_rider', 'Capacity_Rider', 'Kapasitas Rider (paket per orang per hari)', 'paket/hari', false),
  _Field('capacity_driver', 'Capacity_Driver', 'Kapasitas Driver (paket per orang per hari)', 'paket/hari', false),
  _Field('capacity_op_inbound', 'Capacity_Op_Inbound', 'Kapasitas Operator Inbound', 'paket/hari', false),
  _Field('capacity_op_outbound', 'Capacity_Op_Outbound', 'Kapasitas Operator Outbound', 'paket/hari', false),
  _Field('ratio_rider', 'Ratio_Rider', 'Porsi paket yang diantar Rider', 'rasio', true),
  _Field('ratio_driver', 'Ratio_Driver', 'Porsi paket yang diantar Driver', 'rasio', true),
];

final _historyLabels = {for (final f in _fields) f.key: f.label};

String _fmtValue(String key, num v) => key.startsWith('ratio') ? Fmt.decimal(v, digits: 2) : Fmt.number(v);

class KonfigurasiScreen extends ConsumerStatefulWidget {
  const KonfigurasiScreen({super.key});

  @override
  ConsumerState<KonfigurasiScreen> createState() => _KonfigurasiScreenState();
}

class _KonfigurasiScreenState extends ConsumerState<KonfigurasiScreen> {
  final _controllers = {for (final f in _fields) f.key: TextEditingController()};
  CapacityConfig? _loaded;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(CapacityConfig c) {
    _loaded = c;
    final m = c.toMap();
    for (final f in _fields) {
      _controllers[f.key]!.text = _fmtValue(f.key, m[f.key] as num);
    }
  }

  Map<String, num?> _values() => {
        for (final f in _fields)
          f.key: f.isRatio ? Fmt.parseDecimal(_controllers[f.key]!.text) : Fmt.parseDecimal(_controllers[f.key]!.text.replaceAll('.', '')),
      };

  CapacityConfig? _parsed() {
    final v = _values();
    if (!ConfigValidator.validate(v).isValid) return null;
    return CapacityConfig(
      capacityRider: v['capacity_rider']!,
      capacityDriver: v['capacity_driver']!,
      capacityOpInbound: v['capacity_op_inbound']!,
      capacityOpOutbound: v['capacity_op_outbound']!,
      ratioRider: v['ratio_rider']!.toDouble(),
      ratioDriver: v['ratio_driver']!.toDouble(),
    );
  }

  Future<void> _save(CapacityConfig next) async {
    final user = ref.read(currentUserProvider)!;
    final old = _loaded!.toMap();
    final changes = [
      for (final f in _fields)
        if (old[f.key] != next.toMap()[f.key])
          '${f.label}: ${_fmtValue(f.key, old[f.key] as num)} → ${_fmtValue(f.key, next.toMap()[f.key] as num)}',
    ];
    final ok = await showWipasConfirmDialog(
      context,
      title: 'Simpan konfigurasi?',
      body: 'Perubahan langsung dipakai untuk rekomendasi berikutnya dan dicatat di riwayat.',
      content: Text(changes.join('\n'), style: WipasText.body.copyWith(fontWeight: FontWeight.w600)),
      confirmLabel: 'Simpan',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveConfig(newValues: next, uid: user.uid, name: user.displayName);
      if (mounted) {
        _loaded = next;
        showWipasSnackBar(context, 'Konfigurasi tersimpan dan dicatat di riwayat.');
      }
    } catch (_) {
      if (mounted) showWipasSnackBar(context, 'Gagal menyimpan konfigurasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    final async = ref.watch(konfigurasiDataProvider);
    if (async.hasValue && _loaded == null) _load(async.requireValue.config);
    final state = toViewState<KonfigurasiData>(async, offline: offline, lastSync: ref.watch(syncClockProvider));

    return Scaffold(
      appBar: WipasAppBarSub(
        title: 'Konfigurasi Kapasitas',
        subtitle: ref.watch(screenSubtitleProvider),
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.lainnya),
      ),
      body: WipasStateView<KonfigurasiData>(
        state: state,
        attempts: ref.watch(retryCountProvider('konfigurasi')),
        onRetry: () => retryScreen(ref, 'konfigurasi', [configProvider, latestPredictionProvider, configHistoryProvider]),
        empty: const SizedBox.shrink(),
        builder: (context, d, offline) => _content(d, offline),
      ),
    );
  }

  List<Widget> _content(KonfigurasiData d, bool offline) {
    final values = _values();
    final validation = ConfigValidator.validate(values);
    final next = _parsed();
    final changed = next != null && next != _loaded;
    final ratioError = validation.ratioError;

    String? disabledReason;
    if (offline) {
      disabledReason = offlineActionHint;
    } else if (validation.isValid && !changed) {
      disabledReason = 'Belum ada perubahan untuk disimpan.';
    }

    return [
      const WipasAlertBanner(
        kind: AlertKind.info,
        body: 'Perubahan berlaku tanpa deploy ulang aplikasi. Ratio_Rider + Ratio_Driver harus = 1,00.',
      ),
      cardGap,
      WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const WipasCardHeader(title: 'Parameter'),
          const SizedBox(height: WipasSpace.sm),
          for (final f in _fields) ...[
            WipasTextField(
              label: f.label,
              controller: _controllers[f.key],
              fieldKey: Key('cfg-${f.key}'),
              suffixText: f.unit,
              keyboardType: TextInputType.numberWithOptions(decimal: f.isRatio, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
              errorText: validation.fieldErrors[f.key] ?? (f.isRatio && ratioError != null ? '' : null),
              helperText: f.helper,
              onChanged: (_) => setState(() {}),
            ),
            if (validation.fieldErrors[f.key] != null)
              Text(f.helper, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            const SizedBox(height: WipasSpace.md),
          ],
          if (ratioError != null)
            Semantics(
              liveRegion: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline, size: 16, color: WipasColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ratioError,
                      style: WipasText.bodySmall.copyWith(color: WipasColors.danger, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
      ),
      cardGap,
      _PreviewCard(next: next, current: d.latest?.manpower?.counts, latest: d.latest),
      cardGap,
      WipasPrimaryButton(
        key: const Key('btn-simpan-config'),
        label: 'Simpan perubahan',
        icon: Icons.save_outlined,
        loading: _saving,
        disabledReason: disabledReason,
        onPressed: (validation.isValid && changed) ? () => _save(next) : null,
      ),
      cardGap,
      _HistoryCard(history: d.history),
    ];
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.next, required this.current, required this.latest});
  final CapacityConfig? next;
  final ManpowerCounts? current;
  final Prediction? latest;

  @override
  Widget build(BuildContext context) {
    final predicted = latest?.predicted;
    Widget body;
    if (next == null) {
      body = const WipasInfoLine(
        icon: Icons.warning_amber_rounded,
        color: WipasColors.warningText,
        child: Text('Perbaiki nilai yang belum valid untuk melihat pratinjau.',
            style: TextStyle(color: WipasColors.warningText, fontSize: 14)),
      );
    } else if (predicted == null) {
      body = Text('Belum ada Predicted H+1 untuk dihitung.', style: WipasText.body.copyWith(color: WipasColors.textSecondary));
    } else {
      final r = ManpowerCalculator.compute(predicted, next!);
      final cur = current ?? r;
      final labels = ['Rider', 'Driver', 'Op. Inbound', 'Op. Outbound'];
      final nv = [r.rider, r.driver, r.opInbound, r.opOutbound];
      final cv = [cur.rider, cur.driver, cur.opInbound, cur.opOutbound];
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Dengan nilai ini, rekomendasi besok: '),
          TextSpan(
            text: 'Rider ${r.rider} · Driver ${r.driver} · Op. Inbound ${r.opInbound} · Op. Outbound ${r.opOutbound}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ]), style: WipasText.body.copyWith(fontSize: 15)),
        const SizedBox(height: WipasSpace.md),
        for (var row = 0; row < 4; row += 2) ...[
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = row; i < row + 2; i++) ...[
                if (i > row) const SizedBox(width: WipasSpace.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(WipasSpace.md),
                    decoration: BoxDecoration(color: WipasColors.chipFill, borderRadius: BorderRadius.circular(WipasRadius.control)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(labels[i], style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                      Text('${nv[i]}', style: WipasText.kpi.copyWith(fontSize: 24, color: WipasColors.navy)),
                      Text(
                        nv[i] == cv[i]
                            ? 'sama dengan saat ini'
                            : 'saat ini ${cv[i]} (${nv[i] > cv[i] ? '+' : '−'}${(nv[i] - cv[i]).abs()})',
                        style: WipasText.bodySmall.copyWith(color: nv[i] == cv[i] ? WipasColors.textSecondary : WipasColors.link),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: WipasSpace.sm),
        ],
        Text(
          'Berdasarkan Predicted ${Fmt.number(predicted)} paket (${Fmt.dateNoYear(latest!.targetDate)}), dibulatkan ke atas.',
          style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
        ),
      ]);
    }
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WipasCardHeader(title: 'Pratinjau dampak'),
        const SizedBox(height: WipasSpace.sm),
        body,
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final List<ConfigHistoryEntry> history;

  @override
  Widget build(BuildContext context) => WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const WipasCardHeader(title: 'Riwayat perubahan', subtitle: 'Audit trail: siapa, kapan, nilai lama → baru'),
          const SizedBox(height: WipasSpace.sm),
          if (history.isEmpty)
            Text('Belum ada perubahan konfigurasi.', style: WipasText.body.copyWith(color: WipasColors.textSecondary))
          else
            for (final h in history)
              Container(
                padding: const EdgeInsets.symmetric(vertical: WipasSpace.md),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: WipasColors.divider))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.changedByName, style: WipasText.body.copyWith(fontWeight: FontWeight.w700)),
                  Text(h.changedAt == null ? 'menyinkronkan…' : Fmt.logTime(h.changedAt!),
                      style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                  for (final k in _historyLabels.keys)
                    if (h.newValues[k] != null && h.oldValues[k] != h.newValues[k])
                      Text(
                        '${_historyLabels[k]}: ${h.oldValues[k] == null ? '—' : _fmtValue(k, h.oldValues[k]!)} → '
                        '${_fmtValue(k, h.newValues[k]!)}',
                        style: WipasText.body,
                      ),
                ]),
              ),
        ]),
      );
}
