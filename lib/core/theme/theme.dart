import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 light theme built from [WipasColors] and [WipasText].
ThemeData buildWipasTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: WipasColors.navy,
    onPrimary: Colors.white,
    secondary: WipasColors.teal,
    onSecondary: Colors.white,
    tertiary: WipasColors.primaryLight,
    onTertiary: Colors.white,
    error: WipasColors.danger,
    onError: Colors.white,
    surface: WipasColors.surface,
    onSurface: WipasColors.textPrimary,
    onSurfaceVariant: WipasColors.textSecondary,
    outline: WipasColors.border,
    outlineVariant: WipasColors.divider,
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(WipasRadius.control));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: WipasColors.background,
    textTheme: const TextTheme(
      titleLarge: WipasText.title,
      titleMedium: WipasText.heading,
      bodyLarge: WipasText.body,
      bodyMedium: WipasText.body,
      bodySmall: WipasText.bodySmall,
      labelLarge: WipasText.button,
      labelMedium: WipasText.caption,
      labelSmall: WipasText.caption,
    ),
    dividerTheme: const DividerThemeData(color: WipasColors.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(WipasSize.touch),
        shape: controlShape,
        backgroundColor: WipasColors.navy,
        disabledBackgroundColor: WipasColors.border,
        disabledForegroundColor: WipasColors.textSecondary,
        textStyle: WipasText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(WipasSize.touch),
        shape: controlShape,
        foregroundColor: WipasColors.navy,
        side: const BorderSide(color: WipasColors.navy, width: 1.5),
        textStyle: WipasText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(WipasSize.touch, WipasSize.touch),
        foregroundColor: WipasColors.link,
        textStyle: WipasText.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WipasColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: WipasSpace.lg, vertical: 14),
      hintStyle: WipasText.body.copyWith(color: WipasColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WipasRadius.control),
        borderSide: const BorderSide(color: WipasColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WipasRadius.control),
        borderSide: const BorderSide(color: WipasColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WipasRadius.control),
        borderSide: const BorderSide(color: WipasColors.navy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WipasRadius.control),
        borderSide: const BorderSide(color: WipasColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WipasRadius.control),
        borderSide: const BorderSide(color: WipasColors.danger, width: 2),
      ),
      errorStyle: WipasText.caption.copyWith(color: WipasColors.danger),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? WipasColors.success : WipasColors.border),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: WipasColors.textPrimary,
      contentTextStyle: WipasText.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WipasRadius.control)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: WipasColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WipasRadius.sheet)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: WipasColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: WipasColors.border,
      dragHandleSize: Size(32, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WipasRadius.sheet))),
    ),
  );
}
