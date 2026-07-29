import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppVisualStyle { light, dark, vintage80, vintage90 }

extension AppVisualStyleInfo on AppVisualStyle {
  String get label => switch (this) {
        AppVisualStyle.light => 'Chiaro',
        AppVisualStyle.dark => 'Scuro',
        AppVisualStyle.vintage80 => 'Anni 80',
        AppVisualStyle.vintage90 => 'Anni 90',
      };

  String get description => switch (this) {
        AppVisualStyle.light => 'Blu luminoso e superfici chiare',
        AppVisualStyle.dark => 'Blu notte, contrasto morbido',
        AppVisualStyle.vintage80 => 'Nero, fosfori verdi e terminale',
        AppVisualStyle.vintage90 => 'Grigio desktop, viola e finestre rétro',
      };

  IconData get icon => switch (this) {
        AppVisualStyle.light => Icons.light_mode_outlined,
        AppVisualStyle.dark => Icons.dark_mode_outlined,
        AppVisualStyle.vintage80 => Icons.terminal_rounded,
        AppVisualStyle.vintage90 => Icons.desktop_windows_outlined,
      };
}

class AppThemeController {
  static const _preferenceKey = 'app_visual_style';
  static final ValueNotifier<AppVisualStyle> style =
      ValueNotifier(AppVisualStyle.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    style.value = _decode(prefs.getString(_preferenceKey));
  }

  static Future<void> setStyle(AppVisualStyle nextStyle) async {
    if (style.value != nextStyle) style.value = nextStyle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, nextStyle.name);
  }

  static AppVisualStyle _decode(String? raw) {
    return AppVisualStyle.values.firstWhere(
      (entry) => entry.name == raw,
      orElse: () => AppVisualStyle.light,
    );
  }
}

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pageGradient,
    required this.heroGradient,
    required this.heroForeground,
    required this.cardBorder,
    required this.mutedText,
    required this.success,
    required this.isRetro,
  });

  final List<Color> pageGradient;
  final List<Color> heroGradient;
  final Color heroForeground;
  final Color cardBorder;
  final Color mutedText;
  final Color success;
  final bool isRetro;

  static AppThemeTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppThemeTokens>() ??
        AppTheme.build(
          theme.brightness == Brightness.dark
              ? AppVisualStyle.dark
              : AppVisualStyle.light,
        ).extension<AppThemeTokens>()!;
  }

  @override
  AppThemeTokens copyWith({
    List<Color>? pageGradient,
    List<Color>? heroGradient,
    Color? heroForeground,
    Color? cardBorder,
    Color? mutedText,
    Color? success,
    bool? isRetro,
  }) {
    return AppThemeTokens(
      pageGradient: pageGradient ?? this.pageGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      heroForeground: heroForeground ?? this.heroForeground,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      success: success ?? this.success,
      isRetro: isRetro ?? this.isRetro,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;
    return AppThemeTokens(
      pageGradient: List<Color>.generate(
        pageGradient.length,
        (index) => Color.lerp(
          pageGradient[index],
          other.pageGradient[index < other.pageGradient.length
              ? index
              : other.pageGradient.length - 1],
          t,
        )!,
      ),
      heroGradient: List<Color>.generate(
        heroGradient.length,
        (index) => Color.lerp(
          heroGradient[index],
          other.heroGradient[index < other.heroGradient.length
              ? index
              : other.heroGradient.length - 1],
          t,
        )!,
      ),
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      success: Color.lerp(success, other.success, t)!,
      isRetro: t < 0.5 ? isRetro : other.isRetro,
    );
  }
}

class AppTheme {
  static ThemeData build(AppVisualStyle style) {
    final palette = _palette(style);
    final isRetro =
        style == AppVisualStyle.vintage80 || style == AppVisualStyle.vintage90;
    final radius = switch (style) {
      AppVisualStyle.vintage80 => 2.0,
      AppVisualStyle.vintage90 => 5.0,
      _ => 16.0,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: palette.cardBorder),
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: palette.brightness,
      surface: palette.surface,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      surfaceContainerHighest: palette.field,
      outline: palette.cardBorder,
      outlineVariant: palette.cardBorder,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      fontFamily: style == AppVisualStyle.vintage80 ? 'monospace' : 'Roboto',
    );

    return base.copyWith(
      primaryColor: palette.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isRetro ? 0 : 0.8,
        shadowColor: palette.shadow,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: palette.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: style == AppVisualStyle.vintage80 ? 0.8 : 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isRetro ? 0 : 2,
        shadowColor: palette.shadow,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: palette.cardBorder),
      listTileTheme: ListTileThemeData(
        iconColor: palette.primary,
        textColor: palette.onSurface,
      ),
      iconTheme: IconThemeData(color: palette.primary, size: 26),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.field,
        labelStyle: TextStyle(color: palette.mutedText),
        hintStyle: TextStyle(color: palette.mutedText),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.cardBorder),
          borderRadius: BorderRadius.circular(radius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.primary, width: 2),
          borderRadius: BorderRadius.circular(radius),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          shape: shape,
          textStyle: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: isRetro ? 0.5 : 0,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          elevation: isRetro ? 0 : 2,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.field,
        selectedColor: palette.primary,
        disabledColor: palette.field,
        labelStyle: TextStyle(color: palette.onSurface),
        secondaryLabelStyle: TextStyle(color: palette.onPrimary),
        side: BorderSide(color: palette.cardBorder),
        shape: shape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.field,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.field,
        circularTrackColor: palette.field,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.onSurface,
        contentTextStyle: TextStyle(color: palette.surface),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      extensions: [
        AppThemeTokens(
          pageGradient: palette.pageGradient,
          heroGradient: palette.heroGradient,
          heroForeground: palette.heroForeground,
          cardBorder: palette.cardBorder,
          mutedText: palette.mutedText,
          success: palette.success,
          isRetro: isRetro,
        ),
      ],
    );
  }

  static _AppPalette _palette(AppVisualStyle style) => switch (style) {
        AppVisualStyle.light => const _AppPalette(
            brightness: Brightness.light,
            primary: Color(0xFF0A66C2),
            onPrimary: Colors.white,
            secondary: Color(0xFF338FE5),
            onSecondary: Colors.white,
            background: Color(0xFFEAF3FF),
            surface: Colors.white,
            field: Color(0xFFF2F6FB),
            onSurface: Color(0xFF1A2B40),
            mutedText: Color(0xFF5D7189),
            cardBorder: Color(0xFFDCE8F6),
            success: Color(0xFF138A5B),
            shadow: Color(0x22000000),
            pageGradient: [Color(0xFFEAF3FF), Color(0xFFF8FBFF), Colors.white],
            heroGradient: [
              Color(0xFF004E9A),
              Color(0xFF0A66C2),
              Color(0xFF338FE5)
            ],
            heroForeground: Colors.white,
          ),
        AppVisualStyle.dark => const _AppPalette(
            brightness: Brightness.dark,
            primary: Color(0xFF69B7FF),
            onPrimary: Color(0xFF001D35),
            secondary: Color(0xFF8FCBFF),
            onSecondary: Color(0xFF001D35),
            background: Color(0xFF08111F),
            surface: Color(0xFF111E30),
            field: Color(0xFF192A40),
            onSurface: Color(0xFFEAF3FF),
            mutedText: Color(0xFFA9BDD2),
            cardBorder: Color(0xFF2B425D),
            success: Color(0xFF55D69E),
            shadow: Color(0x99000000),
            pageGradient: [
              Color(0xFF08111F),
              Color(0xFF0D1929),
              Color(0xFF111E30)
            ],
            heroGradient: [
              Color(0xFF0B3157),
              Color(0xFF104D7C),
              Color(0xFF17699E)
            ],
            heroForeground: Color(0xFFEAF3FF),
          ),
        AppVisualStyle.vintage80 => const _AppPalette(
            brightness: Brightness.dark,
            primary: Color(0xFF39FF14),
            onPrimary: Colors.black,
            secondary: Color(0xFF00F5FF),
            onSecondary: Colors.black,
            background: Color(0xFF020702),
            surface: Color(0xFF071107),
            field: Color(0xFF0C1C0C),
            onSurface: Color(0xFFB7FFAA),
            mutedText: Color(0xFF72B86A),
            cardBorder: Color(0xFF248C24),
            success: Color(0xFF39FF14),
            shadow: Color(0xAA39FF14),
            pageGradient: [
              Color(0xFF010401),
              Color(0xFF061006),
              Color(0xFF020702)
            ],
            heroGradient: [
              Color(0xFF062006),
              Color(0xFF0B3A0B),
              Color(0xFF075A3A)
            ],
            heroForeground: Color(0xFFB7FFAA),
          ),
        AppVisualStyle.vintage90 => const _AppPalette(
            brightness: Brightness.light,
            primary: Color(0xFF4B1D73),
            onPrimary: Colors.white,
            secondary: Color(0xFF007C7C),
            onSecondary: Colors.white,
            background: Color(0xFFBDBDBD),
            surface: Color(0xFFE8E6DE),
            field: Color(0xFFD5D2C8),
            onSurface: Color(0xFF171717),
            mutedText: Color(0xFF4E4E4E),
            cardBorder: Color(0xFF666666),
            success: Color(0xFF007C4A),
            shadow: Color(0x66000000),
            pageGradient: [
              Color(0xFFC7C7C7),
              Color(0xFFB8C7C7),
              Color(0xFFE1DED5)
            ],
            heroGradient: [
              Color(0xFF35134F),
              Color(0xFF4B1D73),
              Color(0xFF007C7C)
            ],
            heroForeground: Colors.white,
          ),
      };
}

class _AppPalette {
  const _AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.field,
    required this.onSurface,
    required this.mutedText,
    required this.cardBorder,
    required this.success,
    required this.shadow,
    required this.pageGradient,
    required this.heroGradient,
    required this.heroForeground,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color surface;
  final Color field;
  final Color onSurface;
  final Color mutedText;
  final Color cardBorder;
  final Color success;
  final Color shadow;
  final List<Color> pageGradient;
  final List<Color> heroGradient;
  final Color heroForeground;
}
