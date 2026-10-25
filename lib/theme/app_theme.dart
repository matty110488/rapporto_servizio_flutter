import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class CronoColors extends ThemeExtension<CronoColors> {
  const CronoColors({
    required this.page,
    required this.section,
    required this.card,
    required this.elevated,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.inverse,
    required this.inverseSoft,
    required this.onInverse,
    required this.onInverseMuted,
    required this.inverseBorder,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color page;
  final Color section;
  final Color card;
  final Color elevated;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color inverse;
  final Color inverseSoft;
  final Color onInverse;
  final Color onInverseMuted;
  final Color inverseBorder;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  static const light = CronoColors(
    page: Color(0xFFF4F5F7),
    section: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    border: Color(0xFFCBD5E1),
    borderStrong: Color(0xFF94A3B8),
    accent: Color(0xFF1D4ED8),
    accentHover: Color(0xFF1E3A8A),
    accentSoft: Color(0xFFDBEAFE),
    onAccentSoft: Color(0xFF1E40AF),
    inverse: Color(0xFF020617),
    inverseSoft: Color(0xFF0F172A),
    onInverse: Color(0xFFFFFFFF),
    onInverseMuted: Color(0xFFCBD5E1),
    inverseBorder: Color(0xFF475569),
    success: Color(0xFF176B42),
    successSoft: Color(0xFFE8F7EF),
    warning: Color(0xFF9A5800),
    warningSoft: Color(0xFFFFF3D6),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0xFFFFE8E6),
  );

  static const dark = CronoColors(
    page: Color(0xFF0D0D0D),
    section: Color(0xFF0A0A0A),
    card: Color(0xFF141414),
    elevated: Color(0xFF1B1B1B),
    surfaceMuted: Color(0xFF202020),
    textPrimary: Color(0xFFF7F7F2),
    textSecondary: Color(0xFFD1D1CC),
    textMuted: Color(0xFFA3A3A3),
    border: Color(0xFF343434),
    borderStrong: Color(0xFF525252),
    accent: Color(0xFFF4C430),
    accentHover: Color(0xFFFFD447),
    accentSoft: Color(0xFF3B310B),
    onAccentSoft: Color(0xFFFFE27A),
    inverse: Color(0xFF080808),
    inverseSoft: Color(0xFF111111),
    onInverse: Color(0xFFFFFFFF),
    onInverseMuted: Color(0xFFD4D4D4),
    inverseBorder: Color(0xFF404040),
    success: Color(0xFF67D69A),
    successSoft: Color(0xFF102A1D),
    warning: Color(0xFFFFC766),
    warningSoft: Color(0xFF35260D),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0xFF3A1715),
  );

  @override
  CronoColors copyWith() => this;

  @override
  CronoColors lerp(covariant CronoColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension CronoThemeContext on BuildContext {
  CronoColors get cronoColors =>
      Theme.of(this).extension<CronoColors>() ?? CronoColors.light;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light, CronoColors.light);

  static ThemeData dark() => _build(Brightness.dark, CronoColors.dark);

  static ThemeData _build(Brightness brightness, CronoColors colors) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: isDark ? const Color(0xFF090909) : Colors.white,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.onAccentSoft,
      secondary: colors.accent,
      onSecondary: isDark ? const Color(0xFF090909) : Colors.white,
      secondaryContainer: colors.surfaceMuted,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.success,
      onTertiary: isDark ? const Color(0xFF07130C) : Colors.white,
      error: colors.danger,
      onError: isDark ? const Color(0xFF1B0504) : Colors.white,
      surface: colors.section,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.inverse,
      onInverseSurface: colors.onInverse,
      inversePrimary:
          isDark ? const Color(0xFF1D4ED8) : const Color(0xFFF4C430),
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      canvasColor: colors.section,
      fontFamily: kIsWeb ? 'Arial' : null,
      visualDensity: VisualDensity.standard,
      extensions: [colors],
    );
    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -1.4,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -1.1,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.55,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.42),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          bodyColor: colors.textPrimary,
          displayColor: colors.textPrimary,
        );
    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      shape: const WidgetStatePropertyAll(controlShape),
    );
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.section,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
        ),
        shape: Border(bottom: BorderSide(color: colors.border)),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: colors.borderStrong)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: colors.accent,
        textColor: colors.textPrimary,
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevated,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.section,
        indicatorColor: colors.accentSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.section,
        indicatorColor: colors.accentSoft,
        selectedIconTheme: IconThemeData(color: colors.onAccentSoft),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSoft,
        contentTextStyle: TextStyle(color: colors.onInverse),
        actionTextColor: isDark ? colors.accent : const Color(0xFF93C5FD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceMuted,
        selectedColor: colors.accentSoft,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : colors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.surfaceMuted,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(color: colors.onInverse),
      ),
    );
  }
}
