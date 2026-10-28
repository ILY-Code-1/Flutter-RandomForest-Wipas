import 'package:flutter/material.dart';

/// Design tokens from `docs/design/png/6 · Handoff · Token desain.png`.
/// This is the single source for colors, type, spacing, radius and sizes.
class WipasColors {
  WipasColors._();

  static const navy = Color(0xFF1F3A5F);
  static const primaryLight = Color(0xFF3B6FB6);
  static const teal = Color(0xFF0F9D8A);
  static const tealText = Color(0xFF0B7C6D);
  static const link = Color(0xFF2F5F9F);

  static const success = Color(0xFF2E7D32);
  static const successTint = Color(0xFFE8F4E9);
  static const successBorder = Color(0xFFA5D6A7);
  static const successText = Color(0xFF1B5E20);

  static const warning = Color(0xFFF9A825);
  static const warningTint = Color(0xFFFFF4D6);
  static const warningText = Color(0xFF7A4F00);

  static const danger = Color(0xFFC62828);
  static const dangerTint = Color(0xFFFBE9E9);
  static const dangerBorder = Color(0xFFEF9A9A);
  static const dangerText = Color(0xFF8E1B1B);

  static const info = Color(0xFF1565C0);
  static const infoTint = Color(0xFFE3F0FC);
  static const infoBorder = Color(0xFF90CAF9);
  static const infoText = Color(0xFF0D3A73);

  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE3EC);
  static const divider = Color(0xFFEEF1F6);
  static const textPrimary = Color(0xFF1B2433);
  static const textSecondary = Color(0xFF5B6779);
  static const seriesProjection = Color(0xFF7A8CA5);

  /// Light navy used for the active bottom-nav pill and parameter chips.
  static const navyTint = Color(0xFFDCE6F3);
  static const chipFill = Color(0xFFE6EDF6);
}

class WipasText {
  WipasText._();

  static const _family = 'Inter';
  static const _tabular = [FontFeature.tabularFigures()];

  static const title = TextStyle(
      fontFamily: _family, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: WipasColors.textPrimary);
  static const heading = TextStyle(
      fontFamily: _family, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: WipasColors.textPrimary);
  static const body = TextStyle(
      fontFamily: _family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: WipasColors.textPrimary);
  static const bodyStrong = TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: WipasColors.textPrimary,
      fontFeatures: _tabular);
  static const bodySmall = TextStyle(
      fontFamily: _family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: WipasColors.textPrimary);
  static const caption = TextStyle(
      fontFamily: _family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: WipasColors.textSecondary);
  static const kpi = TextStyle(
      fontFamily: _family,
      fontSize: 28,
      height: 32 / 28,
      fontWeight: FontWeight.w700,
      color: WipasColors.textPrimary,
      fontFeatures: _tabular);
  static const button = TextStyle(fontFamily: _family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
}

class WipasSpace {
  WipasSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class WipasRadius {
  WipasRadius._();
  static const card = 12.0;
  static const control = 10.0;
  static const sheet = 16.0;
  static const pill = 999.0;
}

class WipasSize {
  WipasSize._();
  static const screen = Size(360, 800);
  static const touch = 48.0;
  static const chipVisual = 32.0;
  static const appBar = 64.0;
  static const bottomNav = 80.0;
  static const navIndicator = Size(64, 32);
  static const badge = 28.0;
  static const tag = 24.0;
  static const icon = 20.0;
  static const iconLarge = 24.0;
}

class WipasElevation {
  WipasElevation._();
  static const card = [BoxShadow(color: Color(0x141B2433), offset: Offset(0, 1), blurRadius: 2)];
  static const overlay = [BoxShadow(color: Color(0x401B2433), offset: Offset(0, 8), blurRadius: 24)];
}

class WipasMotion {
  WipasMotion._();
  static const skeleton = Duration(milliseconds: 1400);
  static const spinner = Duration(seconds: 1);

  /// Honors the platform reduced-motion setting.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
