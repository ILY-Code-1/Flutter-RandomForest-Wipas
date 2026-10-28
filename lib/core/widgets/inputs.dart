import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/formatters.dart';
import '../theme/tokens.dart';

/// Labeled text field: label above, height 48, radius 10, error with icon.
class WipasTextField extends StatelessWidget {
  const WipasTextField({
    super.key,
    required this.label,
    this.labelSuffix,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.suffixText,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.fieldKey,
  });

  final String label;
  final String? labelSuffix;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final String? suffixText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: label),
            if (labelSuffix != null)
              TextSpan(text: ' $labelSuffix', style: const TextStyle(fontWeight: FontWeight.w400, color: WipasColors.textSecondary)),
          ]),
          style: WipasText.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: hasError ? WipasColors.danger : WipasColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          style: WipasText.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon ??
                (suffixText == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: WipasSpace.lg),
                        child: Center(
                          widthFactor: 1,
                          child: Text(suffixText!, style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
                        ),
                      )),
            enabledBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WipasRadius.control),
                    borderSide: const BorderSide(color: WipasColors.danger, width: 1.5),
                  )
                : null,
          ),
        ),
        if (hasError && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 16, color: WipasColors.danger),
              const SizedBox(width: 6),
              Expanded(child: Text(errorText!, style: WipasText.bodySmall.copyWith(color: WipasColors.danger))),
            ]),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
        ],
      ],
    );
  }
}

/// − value + stepper with 48dp round buttons; long-press repeats.
class WipasNumericStepper extends StatefulWidget {
  const WipasNumericStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 9999, this.label});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? label;

  @override
  State<WipasNumericStepper> createState() => _WipasNumericStepperState();
}

class _WipasNumericStepperState extends State<WipasNumericStepper> {
  Timer? _repeat;

  void _step(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _startRepeat(int delta) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 120), (_) => _step(delta));
  }

  void _stopRepeat() => _repeat?.cancel();

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  Widget _button(IconData icon, int delta, String semantic) {
    final enabled = delta < 0 ? widget.value > widget.min : widget.value < widget.max;
    return Semantics(
      button: true,
      label: '$semantic ${widget.label ?? ''}'.trim(),
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeat(delta) : null,
        onLongPressEnd: (_) => _stopRepeat(),
        child: SizedBox(
          width: WipasSize.touch,
          height: WipasSize.touch,
          child: OutlinedButton(
            onPressed: enabled ? () => _step(delta) : null,
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(WipasSize.touch, WipasSize.touch),
              side: BorderSide(color: enabled ? WipasColors.navy : WipasColors.border, width: 1.5),
            ),
            child: Icon(icon, color: enabled ? WipasColors.navy : WipasColors.textSecondary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _button(Icons.remove, -1, 'Kurangi'),
        SizedBox(
          width: 56,
          child: Text('${widget.value}',
              textAlign: TextAlign.center, style: WipasText.kpi.copyWith(fontSize: 22, height: 28 / 22)),
        ),
        _button(Icons.add, 1, 'Tambah'),
      ]);
}

/// Labeled Material 3 switch row with a 48dp area.
class WipasSwitch extends StatelessWidget {
  const WipasSwitch({super.key, required this.label, required this.value, required this.onChanged, this.subtitle});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: WipasSize.touch),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: WipasText.body.copyWith(fontSize: 15)),
                  if (subtitle != null) Text(subtitle!, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                ]),
              ),
              Switch(value: value, onChanged: onChanged),
            ]),
          ),
        ),
      );
}

class SegmentOption<T> {
  const SegmentOption(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// 2–3 segments, height 48, radius 10; active = navy fill + white text.
class WipasSegmentedControl<T> extends StatelessWidget {
  const WipasSegmentedControl({super.key, required this.options, required this.selected, required this.onChanged});

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: WipasSize.touch,
        decoration: BoxDecoration(
          color: WipasColors.surface,
          border: Border.all(color: WipasColors.navy, width: 1.5),
          borderRadius: BorderRadius.circular(WipasRadius.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.value == selected,
                child: InkWell(
                  onTap: () => onChanged(o.value),
                  child: Container(
                    alignment: Alignment.center,
                    color: o.value == selected ? WipasColors.navy : Colors.transparent,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (o.icon != null) ...[
                        Icon(o.icon, size: WipasSize.icon, color: o.value == selected ? Colors.white : WipasColors.navy),
                        const SizedBox(width: WipasSpace.sm),
                      ],
                      Flexible(
                        child: Text(o.label,
                            overflow: TextOverflow.ellipsis,
                            style: WipasText.button.copyWith(color: o.value == selected ? Colors.white : WipasColors.navy)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Filter chip: 32dp visual inside a 48dp tap area; selected = navy + check.
class WipasFilterChip extends StatelessWidget {
  const WipasFilterChip({super.key, required this.label, required this.selected, required this.onTap, this.showCheck = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WipasRadius.pill),
          child: SizedBox(
            height: WipasSize.touch,
            child: Center(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? WipasColors.navy : WipasColors.surface,
                  border: Border.all(color: selected ? WipasColors.navy : WipasColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(WipasRadius.pill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected && showCheck) ...[
                    const Icon(Icons.check, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(label,
                      style: WipasText.bodyStrong.copyWith(
                          color: selected ? Colors.white : WipasColors.textPrimary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Horizontally scrolling chip strip; fades at the right edge when there are
/// more than four chips.
class WipasFilterChipBar extends StatelessWidget {
  const WipasFilterChipBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: WipasSpace.sm),
      itemBuilder: (_, i) => children[i],
    );
    return SizedBox(
      height: WipasSize.touch + 8,
      child: children.length > 4
          ? ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.86, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: list,
            )
          : list,
    );
  }
}

/// Prev/next date strip ("Rab 7 · Kam 8 Hari ini · Jum 9 H+1") with a
/// calendar button. Dates after [maxDate] are not selectable.
class WipasDatePickerStrip extends StatelessWidget {
  const WipasDatePickerStrip({
    super.key,
    required this.selected,
    required this.maxDate,
    required this.today,
    required this.onSelected,
    this.minDate,
    this.daysBefore = 2,
    this.daysAfter = 1,
  });

  final DateTime selected;
  final DateTime maxDate;
  final DateTime? minDate;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;
  final int daysBefore;
  final int daysAfter;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = -daysBefore; i <= daysAfter + 1; i++) selected.add(Duration(days: i)),
    ];
    return SizedBox(
      height: 84,
      child: Row(children: [
        Expanded(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.9, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final d in days) _DayCell(date: d, strip: this)],
            ),
          ),
        ),
        const SizedBox(width: WipasSpace.sm),
        Semantics(
          button: true,
          label: 'Pilih tanggal',
          child: InkWell(
            borderRadius: BorderRadius.circular(WipasRadius.card),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selected.isAfter(maxDate) ? maxDate : selected,
                firstDate: minDate ?? maxDate.subtract(const Duration(days: 365)),
                lastDate: maxDate,
                locale: const Locale('id', 'ID'),
              );
              if (picked != null) onSelected(DateTime.utc(picked.year, picked.month, picked.day));
            },
            child: Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: WipasColors.surface,
                border: Border.all(color: WipasColors.border),
                borderRadius: BorderRadius.circular(WipasRadius.card),
              ),
              child: const Icon(Icons.calendar_today_outlined, color: WipasColors.navy),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.strip});
  final DateTime date;
  final WipasDatePickerStrip strip;

  @override
  Widget build(BuildContext context) {
    final isSelected = date == strip.selected;
    final enabled = !date.isAfter(strip.maxDate) && (strip.minDate == null || !date.isBefore(strip.minDate!));
    final isToday = date == strip.today;
    final isH1 = date == strip.today.add(const Duration(days: 1));
    final fg = isSelected ? Colors.white : (enabled ? WipasColors.textPrimary : WipasColors.textSecondary);
    final sub = isToday ? 'Hari ini' : (isH1 ? 'H+1' : null);
    return Padding(
      padding: const EdgeInsets.only(right: WipasSpace.sm),
      child: Semantics(
        button: true,
        selected: isSelected,
        enabled: enabled,
        label: '${Fmt.date(date)}${sub == null ? '' : ', $sub'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(WipasRadius.card),
          onTap: enabled ? () => strip.onSelected(date) : null,
          child: Container(
            width: 56,
            decoration: BoxDecoration(
              color: isSelected ? WipasColors.navy : WipasColors.surface,
              border: Border.all(color: isSelected ? WipasColors.navy : WipasColors.border),
              borderRadius: BorderRadius.circular(WipasRadius.card),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(Fmt.dayName(date), style: WipasText.bodySmall.copyWith(color: isSelected ? Colors.white70 : WipasColors.textSecondary)),
              Text('${date.day}', style: WipasText.heading.copyWith(color: fg, fontSize: 18)),
              if (sub != null)
                Text(sub,
                    style: WipasText.caption.copyWith(
                        color: isSelected ? Colors.white : WipasColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}
