import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';
import 'package:rapporto_servizio/widgets/app_ui.dart';

void main() {
  test('theme exposes the institutional design tokens', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(AppColors.background, const Color(0xFFEAF2FB));
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
  });

  for (final size in [
    const Size(320, 700),
    const Size(375, 700),
    const Size(393, 700),
    const Size(430, 700),
    const Size(700, 320),
    const Size(1024, 768),
  ]) {
    testWidgets(
        'Valtellina background stays interactive at ${size.width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: ValtellinaBackground.builder,
          home: Scaffold(
            body: ListView(
              children: [
                SizedBox(
                  height: size.height * 1.5,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FilledButton(
                      onPressed: () => tapped = true,
                      child: const Text('Azione'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ValtellinaBackground), findsOneWidget);
      expect(
        find.byKey(const ValueKey('valtellina-background-art')),
        findsOneWidget,
      );
      await tester.tap(find.text('Azione'));
      expect(tapped, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mountain watermark fades without a horizontal seam',
      (tester) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ValtellinaBackground(child: SizedBox.expand()),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(
        const ValueKey('valtellina-background-paint-boundary'),
      ),
    );
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1),
    );
    final byteData = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final pixels = byteData!.buffer.asUint8List();

    List<double> colorOffsetAt(int y) {
      List<double> average(int startX, int endX) {
        final sum = <double>[0, 0, 0];
        for (var x = startX; x < endX; x++) {
          final index = (y * image!.width + x) * 4;
          sum[0] += pixels[index];
          sum[1] += pixels[index + 1];
          sum[2] += pixels[index + 2];
        }
        final count = (endX - startX).toDouble();
        return sum.map((value) => value / count).toList();
      }

      final clearArea = average(0, 36);
      final mountainArea = average(300, 426);
      return List.generate(
        3,
        (index) => mountainArea[index] - clearArea[index],
      );
    }

    var largestStep = 0.0;
    var previous = colorOffsetAt(80);
    for (var y = 81; y <= 230; y++) {
      final current = colorOffsetAt(y);
      for (var channel = 0; channel < 3; channel++) {
        final step = (current[channel] - previous[channel]).abs();
        if (step > largestStep) largestStep = step;
      }
      previous = current;
    }

    expect(largestStep, lessThan(4));
    expect(tester.takeException(), isNull);
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
