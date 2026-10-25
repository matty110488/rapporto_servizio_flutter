import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rapporto_servizio/theme/app_theme.dart';

void main() {
  test('light theme mirrors the website palette', () {
    final theme = AppTheme.light();
    final colors = theme.extension<CronoColors>()!;

    expect(theme.brightness, Brightness.light);
    expect(colors.page, const Color(0xFFF4F5F7));
    expect(colors.textPrimary, const Color(0xFF0F172A));
    expect(colors.accent, const Color(0xFF1D4ED8));
    expect(theme.cardTheme.elevation, 0);
  });

  test('dark theme mirrors the website palette', () {
    final theme = AppTheme.dark();
    final colors = theme.extension<CronoColors>()!;

    expect(theme.brightness, Brightness.dark);
    expect(colors.page, const Color(0xFF0D0D0D));
    expect(colors.card, const Color(0xFF141414));
    expect(colors.accent, const Color(0xFFF4C430));
    expect(theme.scaffoldBackgroundColor, colors.page);
  });
}
