import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/domain/calculators.dart';
import '../../core/domain/role.dart';
import '../../core/format/formatters.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../common/common.dart';

/// Date being filled in (null = today WIB).
final inputActualDateProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

class InputActualData {
  const InputActualData({required this.window, required this.health});

  /// Predictions from date−6 to date+1 (oldest → newest).
  final List<Prediction> window;
  final ModelHealth? health;

  Prediction? byDate(DateTime d) {
    for (final p in window) {
      if (p.targetDate == d) return p;
    }
    return null;
  }
}

final inputActualDataProvider = Provider.autoDispose<AsyncValue<InputActualData>>((ref) {
  final DateTime today = ref.watch(todayProvider);
  final date = ref.watch(inputActualDateProvider) ?? today;
  final range = ref.watch(predictionsInRangeProvider((end: date.add(const Duration(days: 1)), days: 8)));
  final health = ref.watch(modelHealthProvider);
  return combineAsync([range, health], () {
    final list = [...range.requireValue]..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    return InputActualData(window: list, health: health.requireValue);
  });
});

/// Rolling MAE (7 days ending at [date]) if [actual] is used for [date].
double? projectedRollingMae(List<Prediction> window, DateTime date, int actual) {
  final errors = <double>[];
  for (final p in window) {
    if (p.targetDate.isAfter(date) || date.difference(p.targetDate).inDays >= 7) continue;
    final a = p.targetDate == date ? actual : p.actualInbound;
    final e = ErrorMetrics.dailyErrorPct(p.predicted, a);
    if (e != null) errors.add(e);
  }
  return ErrorMetrics.rollingMae(errors);
}

class InputActualScreen extends ConsumerStatefulWidget {
  const InputActualScreen({super.key});

  @override
  ConsumerState<InputActualScreen> createState() => _InputActualScreenState();
}

class _InputActualScreenState extends ConsumerState<InputActualScreen> {
  final _actual = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _saving = false;
  DateTime? _prefilledFor;

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _error = text.trim().isEmpty ? null : ActualValidator.validate(text));
  }

  Future<void> _save(DateTime date, Prediction? p, AppUser user) async {
    final err = ActualValidator.validate(_actual.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (p == null) {
      showWipasSnackBar(context, 'Belum ada dokumen prediksi untuk ${Fmt.date(date)}.');
      return;
    }
    final value = Fmt.parseInt(_actual.text)!;
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveActual(targetDate: date, actual: value, note: _note.text, uid: user.uid);
      if (mounted) showWipasSnackBar(context, 'Actual ${Fmt.date(date)} tersimpan: ${Fmt.number(value)} paket.');
    } on MissingDocumentException catch (e) {
      if (mounted) showWipasSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showWipasSnackBar(context, 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Briefly null while signing out; the router then leaves this screen.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final today = ref.watch(todayProvider);
    final date = ref.watch(inputActualDateProvider) ?? today;
    final offline = ref.watch(isOfflineProvider);
    final async = ref.watch(inputActualDataProvider);
    final state = toViewState<InputActualData>(async, offline: offline, lastSync: ref.watch(syncClockProvider));

    // Prefill with the stored actual when switching dates.
    final current = async.valueOrNull?.byDate(date);
    if (_prefilledFor != date && async.hasValue) {
      _prefilledFor = date;
      _actual.text = current?.actualInbound == null ? '' : Fmt.number(current!.actualInbound);
      _note.text = current?.actualNote ?? '';
      _error = null;
    }

    return Scaffold(
      appBar: WipasAppBarSub(
        title: 'Input Actual Inbound',
        subtitle: ref.watch(screenSubtitleProvider),
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.beranda),
      ),
      body: WipasStateView<InputActualData>(
        state: state,
        skeletonCards: 2,
        attempts: ref.watch(retryCountProvider('input-actual')),
        onRetry: () => retryScreen(ref, 'input-actual', [predictionsInRangeProvider, modelHealthProvider]),
        empty: const SizedBox.shrink(),
        builder: (context, d, offline) => _content(context, d, date, today, offline, user),
      ),
    );
  }

  List<Widget> _content(BuildContext context, InputActualData d, DateTime date, DateTime today, bool offline, AppUser user) {
    final p = d.byDate(date);
    final next = d.byDate(date.add(const Duration(days: 1)));
    final typed = _error == null ? Fmt.parseInt(_actual.text) : null;
    final isToday = date == today;
    final invalid = _error != null && _actual.text.trim().isNotEmpty;

    return [
      if (user.role == Role.supervisor && isToday && p != null && p.actualInbound == null) ...[
        WipasAlertBanner(
          kind: AlertKind.warning,
          icon: Icons.schedule,
          title: 'Actual hari ini belum diinput',
          body: 'Shift hari ini sudah berakhir. Isi Actual inbound ${Fmt.date(date)} agar evaluasi model tetap akurat.',
        ),
        cardGap,
      ],
      WipasCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Tanggal', style: WipasText.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(WipasRadius.control),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: today.subtract(const Duration(days: 13)),
                lastDate: today,
                locale: const Locale('id', 'ID'),
              );
              if (picked != null) {
                ref.read(inputActualDateProvider.notifier).state = DateTime.utc(picked.year, picked.month, picked.day);
              }
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
              decoration: BoxDecoration(
                color: WipasColors.surface,
                border: Border.all(color: WipasColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(WipasRadius.control),
              ),
              child: Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: Fmt.date(date)),
                    if (isToday) const TextSpan(text: ' (hari ini)', style: TextStyle(color: WipasColors.textSecondary)),
                  ]), style: WipasText.body.copyWith(fontSize: 16)),
                ),
                const Icon(Icons.calendar_today_outlined, color: WipasColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: WipasSpace.lg),
          WipasTextField(
            label: 'Actual inbound (paket)',
            controller: _actual,
            fieldKey: const Key('actual-field'),
            hint: 'Contoh: 17.560',
            suffixText: 'paket',
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-−]'))],
            errorText: _error,
            onChanged: _onChanged,
          ),
          const SizedBox(height: WipasSpace.lg),
          WipasTextField(
            label: 'Catatan',
            labelSuffix: '(opsional)',
            controller: _note,
            hint: 'Contoh: Ada penundaan truk dari Bekasi',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: WipasSpace.lg),
          if (p == null)
            Padding(
              padding: const EdgeInsets.only(bottom: WipasSpace.sm),
              child: Text('Belum ada dokumen prediksi untuk ${Fmt.date(date)}; actual tidak dapat disimpan.',
                  style: WipasText.bodySmall.copyWith(color: WipasColors.warningText)),
            ),
          WipasPrimaryButton(
            key: const Key('btn-simpan-actual'),
            label: 'Simpan',
            icon: Icons.save_outlined,
            loading: _saving,
            disabledReason: offline ? offlineActionHint : null,
            onPressed: (invalid || p == null) ? null : () => _save(date, p, user),
          ),
        ]),
      ),
      cardGap,
      if (p != null && typed != null) _ComparisonCard(p: p, actual: typed, window: d.window, date: date, health: d.health)
      else const _ComparisonPlaceholder(),
      cardGap,
      InputFeaturesCard(
        title: 'Data fitur hari ini',
        subtitle: 'Dipakai model untuk prediksi berikutnya',
        features: (next ?? p)?.inputFeatures ?? const InputFeatures(),
        compact: true,
      ),
    ];
  }
}

class _ComparisonPlaceholder extends StatelessWidget {
  const _ComparisonPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WipasSpace.lg),
        decoration: BoxDecoration(
          border: Border.all(color: WipasColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(WipasRadius.card),
        ),
        child: Row(children: [
          const Icon(Icons.bar_chart, color: WipasColors.textSecondary, size: 28),
          const SizedBox(width: WipasSpace.md),
          Expanded(
            child: Text('Isi angka Actual untuk melihat selisih dengan Predicted dan dampaknya ke Rolling MAE.',
                style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          ),
        ]),
      );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.p, required this.actual, required this.window, required this.date, this.health});
  final Prediction p;
  final int actual;
  final List<Prediction> window;
  final DateTime date;
  final ModelHealth? health;

  @override
  Widget build(BuildContext context) {
    final predicted = p.predicted;
    final diff = predicted == null ? null : actual - predicted;
    final diffPct = (predicted == null || predicted == 0) ? null : diff! / predicted * 100;
    final normal = diffPct == null || diffPct.abs() <= DeviationCalculator.thresholdPct;
    final before = health?.rollingMae7d;
    final after = projectedRollingMae(window, date, actual);
    return WipasCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WipasCardHeader(title: 'Perbandingan dengan prediksi'),
        const SizedBox(height: WipasSpace.sm),
        WipasDataRow(label: 'Predicted', value: Fmt.number(predicted), valueColor: WipasColors.tealText, divider: false),
        WipasDataRow(label: 'Actual', value: Fmt.number(actual), valueColor: WipasColors.navy, divider: false),
        WipasDataRow(
          label: 'Selisih',
          value: diff == null ? '—' : '${Fmt.signedNumber(diff)} paket (${Fmt.signedPercent(diffPct!)})',
          divider: false,
        ),
        const SizedBox(height: WipasSpace.sm),
        Row(children: [
          WipasStatusBadge(normal ? StatusKind.normal : StatusKind.perluPerhatian),
          const SizedBox(width: WipasSpace.md),
          Text('Batas deviasi ${Fmt.percent(DeviationCalculator.thresholdPct, digits: 0)}',
              style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        ]),
        const SizedBox(height: WipasSpace.md),
        Container(
          padding: const EdgeInsets.all(WipasSpace.lg),
          decoration: BoxDecoration(color: WipasColors.chipFill, borderRadius: BorderRadius.circular(WipasRadius.card)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dampak ke Rolling MAE 7 hari', style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
            Text('${Fmt.percent(before)} → ${Fmt.percent(after)}', style: WipasText.kpi.copyWith(color: WipasColors.navy)),
            Text(
              'Ambang drift ${Fmt.percent(health?.threshold)} · baseline ${Fmt.percent(health?.baselineMae)} · '
              'estimasi aplikasi, nilai resmi dihitung script',
              style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}
