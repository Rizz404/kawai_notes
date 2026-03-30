import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const LightColors light = LightColors._();
  static const DarkColors dark = DarkColors._();
  static const SemanticColors semantic = SemanticColors._();
}

class LightColors {
  const LightColors._();

  final Color background = const Color.fromRGBO(248, 250, 250, 1);
  final Color surface = const Color.fromRGBO(255, 255, 255, 1);
  final Color surfaceVariant = const Color.fromRGBO(240, 249, 248, 1);

  final Color primary = const Color.fromRGBO(13, 148, 136, 1);
  final Color primaryContainer = const Color.fromRGBO(204, 251, 241, 1);
  final Color secondary = const Color.fromRGBO(71, 85, 105, 1);
  final Color secondaryContainer = const Color.fromRGBO(226, 232, 240, 1);

  final Color accent = const Color.fromRGBO(249, 115, 22, 1);
  final Color accentHover = const Color.fromRGBO(234, 88, 12, 1);
  final Color accentPressed = const Color.fromRGBO(194, 65, 12, 1);

  final Color textPrimary = const Color.fromRGBO(15, 23, 42, 1);
  final Color textSecondary = const Color.fromRGBO(71, 85, 105, 1);
  final Color textTertiary = const Color.fromRGBO(148, 163, 184, 1);
  final Color textDisabled = const Color.fromRGBO(203, 213, 225, 1);
  final Color textOnPrimary = const Color.fromRGBO(255, 255, 255, 1);
  final Color textOnAccent = const Color.fromRGBO(255, 255, 255, 1);

  final Color border = const Color.fromRGBO(204, 237, 234, 1);
  final Color borderHover = const Color.fromRGBO(153, 220, 215, 1);
  final Color divider = const Color.fromRGBO(240, 253, 250, 1);

  final Color hover = const Color.fromRGBO(240, 253, 250, 1);
  final Color pressed = const Color.fromRGBO(204, 251, 241, 1);
  final Color focus = const Color.fromRGBO(13, 148, 136, 0.12);
  final Color disabled = const Color.fromRGBO(241, 245, 249, 1);

  final Color card = const Color.fromRGBO(255, 255, 255, 1);
  final Color modal = const Color.fromRGBO(255, 255, 255, 1);
  final Color tooltip = const Color.fromRGBO(4, 47, 46, 1);

  final Color navBar = const Color.fromRGBO(255, 255, 255, 1);
  final Color navSelected = const Color.fromRGBO(13, 148, 136, 1);
  final Color navUnselected = const Color.fromRGBO(100, 116, 139, 1);

  final Color overlay = const Color.fromRGBO(0, 0, 0, 0.5);
  final Color scrim = const Color.fromRGBO(0, 0, 0, 0.32);
}

class DarkColors {
  const DarkColors._();

  final Color background = const Color.fromRGBO(4, 47, 46, 1);
  final Color surface = const Color.fromRGBO(15, 61, 58, 1);
  final Color surfaceVariant = const Color.fromRGBO(19, 78, 74, 1);

  final Color primary = const Color.fromRGBO(45, 212, 191, 1);
  final Color primaryContainer = const Color.fromRGBO(17, 94, 89, 1);
  final Color secondary = const Color.fromRGBO(148, 163, 184, 1);
  final Color secondaryContainer = const Color.fromRGBO(19, 78, 74, 1);

  final Color accent = const Color.fromRGBO(251, 146, 60, 1);
  final Color accentHover = const Color.fromRGBO(253, 186, 116, 1);
  final Color accentPressed = const Color.fromRGBO(249, 115, 22, 1);

  final Color textPrimary = const Color.fromRGBO(240, 253, 250, 1);
  final Color textSecondary = const Color.fromRGBO(203, 213, 225, 1);
  final Color textTertiary = const Color.fromRGBO(148, 163, 184, 1);
  final Color textDisabled = const Color.fromRGBO(51, 65, 85, 1);
  final Color textOnPrimary = const Color.fromRGBO(4, 47, 46, 1);
  final Color textOnAccent = const Color.fromRGBO(255, 255, 255, 1);

  final Color border = const Color.fromRGBO(19, 78, 74, 1);
  final Color borderHover = const Color.fromRGBO(17, 94, 89, 1);
  final Color divider = const Color.fromRGBO(15, 61, 58, 1);

  final Color hover = const Color.fromRGBO(45, 212, 191, 0.08);
  final Color pressed = const Color.fromRGBO(45, 212, 191, 0.15);
  final Color focus = const Color.fromRGBO(45, 212, 191, 0.12);
  final Color disabled = const Color.fromRGBO(15, 61, 58, 1);

  final Color card = const Color.fromRGBO(15, 61, 58, 1);
  final Color modal = const Color.fromRGBO(15, 61, 58, 1);
  final Color tooltip = const Color.fromRGBO(240, 253, 250, 1);

  final Color navBar = const Color.fromRGBO(15, 61, 58, 1);
  final Color navSelected = const Color.fromRGBO(45, 212, 191, 1);
  final Color navUnselected = const Color.fromRGBO(148, 163, 184, 1);

  final Color overlay = const Color.fromRGBO(0, 0, 0, 0.7);
  final Color scrim = const Color.fromRGBO(0, 0, 0, 0.5);
}

class SemanticColors {
  const SemanticColors._();

  final Color success = const Color.fromRGBO(34, 197, 94, 1);
  final Color successLight = const Color.fromRGBO(220, 252, 231, 1);
  final Color successDark = const Color.fromRGBO(22, 163, 74, 1);

  final Color warning = const Color.fromRGBO(251, 191, 36, 1);
  final Color warningLight = const Color.fromRGBO(254, 249, 195, 1);
  final Color warningDark = const Color.fromRGBO(245, 158, 11, 1);

  final Color error = const Color.fromRGBO(239, 68, 68, 1);
  final Color errorLight = const Color.fromRGBO(254, 226, 226, 1);
  final Color errorDark = const Color.fromRGBO(220, 38, 38, 1);

  final Color info = const Color.fromRGBO(59, 130, 246, 1);
  final Color infoLight = const Color.fromRGBO(219, 234, 254, 1);
  final Color infoDark = const Color.fromRGBO(37, 99, 235, 1);
}

class AppColorsTheme {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnPrimary;
  final Color textOnAccent;
  final Color border;
  final Color borderHover;
  final Color divider;
  final Color hover;
  final Color pressed;
  final Color focus;
  final Color disabled;
  final Color card;
  final Color modal;
  final Color tooltip;
  final Color navBar;
  final Color navSelected;
  final Color navUnselected;
  final Color overlay;
  final Color scrim;

  const AppColorsTheme._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.textOnAccent,
    required this.border,
    required this.borderHover,
    required this.divider,
    required this.hover,
    required this.pressed,
    required this.focus,
    required this.disabled,
    required this.card,
    required this.modal,
    required this.tooltip,
    required this.navBar,
    required this.navSelected,
    required this.navUnselected,
    required this.overlay,
    required this.scrim,
  });

  factory AppColorsTheme.light() {
    const colors = AppColors.light;
    return AppColorsTheme._(
      background: colors.background,
      surface: colors.surface,
      surfaceVariant: colors.surfaceVariant,
      primary: colors.primary,
      primaryContainer: colors.primaryContainer,
      secondary: colors.secondary,
      secondaryContainer: colors.secondaryContainer,
      accent: colors.accent,
      accentHover: colors.accentHover,
      accentPressed: colors.accentPressed,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      textDisabled: colors.textDisabled,
      textOnPrimary: colors.textOnPrimary,
      textOnAccent: colors.textOnAccent,
      border: colors.border,
      borderHover: colors.borderHover,
      divider: colors.divider,
      hover: colors.hover,
      pressed: colors.pressed,
      focus: colors.focus,
      disabled: colors.disabled,
      card: colors.card,
      modal: colors.modal,
      tooltip: colors.tooltip,
      navBar: colors.navBar,
      navSelected: colors.navSelected,
      navUnselected: colors.navUnselected,
      overlay: colors.overlay,
      scrim: colors.scrim,
    );
  }

  factory AppColorsTheme.dark() {
    const colors = AppColors.dark;
    return AppColorsTheme._(
      background: colors.background,
      surface: colors.surface,
      surfaceVariant: colors.surfaceVariant,
      primary: colors.primary,
      primaryContainer: colors.primaryContainer,
      secondary: colors.secondary,
      secondaryContainer: colors.secondaryContainer,
      accent: colors.accent,
      accentHover: colors.accentHover,
      accentPressed: colors.accentPressed,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      textDisabled: colors.textDisabled,
      textOnPrimary: colors.textOnPrimary,
      textOnAccent: colors.textOnAccent,
      border: colors.border,
      borderHover: colors.borderHover,
      divider: colors.divider,
      hover: colors.hover,
      pressed: colors.pressed,
      focus: colors.focus,
      disabled: colors.disabled,
      card: colors.card,
      modal: colors.modal,
      tooltip: colors.tooltip,
      navBar: colors.navBar,
      navSelected: colors.navSelected,
      navUnselected: colors.navUnselected,
      overlay: colors.overlay,
      scrim: colors.scrim,
    );
  }
}
