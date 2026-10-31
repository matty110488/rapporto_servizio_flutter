import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';
import 'package:rapporto_servizio/widgets/app_ui.dart';

void main() {
  test('theme exposes the institutional design tokens', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
  });

  testWidgets('shared UI components fit a narrow accessible viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const AppSurface(
                child: Text(
                  'Titolo della gara volutamente molto lungo per verificare '
                  'la disposizione su uno schermo mobile stretto',
                ),
              ),
              const SizedBox(height: 8),
              AppFilterChip(
                label: 'Mia disponibilità',
                selected: true,
                onSelected: (_) {},
              ),
              const AppStatusBadge(
                label: 'Designazione inviata',
                foregroundColor: AppColors.primaryDeep,
                backgroundColor: AppColors.primarySoft,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Titolo della gara'), findsOneWidget);
  });

  testWidgets('outlined app card uses the subtle border and pressed color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppCard(
            variant: AppCardVariant.outlined,
            onTap: () {},
            child: const Text('Gara'),
          ),
        ),
      ),
    );

    final cardFinder = find.byType(AppCard);
    final material = tester.widget<Material>(
      find.descendant(of: cardFinder, matching: find.byType(Material)).first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: cardFinder, matching: find.byType(InkWell)),
    );

    expect(material.color, AppColors.surface);
    expect(material.elevation, 0);
    expect(shape.side.color, AppColors.cardOutline);
    expect(shape.side.width, AppStrokes.thin);
    expect(shape.borderRadius, BorderRadius.circular(AppRadii.card));
    expect(
      inkWell.overlayColor?.resolve({WidgetState.pressed}),
      AppColors.cardPressed,
    );
  });

  testWidgets('horizontal hint follows overflow and scroll position',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: AppHorizontalScrollHint(
              child: SizedBox(width: 500, height: 44),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsOneWidget,
    );
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsNothing,
    );
  });

  testWidgets('horizontal hint stays hidden when everything fits',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AppHorizontalScrollHint(
              child: SizedBox(width: 200, height: 44),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsNothing,
    );
  });
}
