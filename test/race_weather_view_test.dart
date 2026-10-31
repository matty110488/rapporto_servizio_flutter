import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/race_weather.dart';
import 'package:rapporto_servizio/widgets/race_weather_view.dart';

void main() {
  const weather = RaceWeather(
    date: '2026-07-27',
    location:
        'Una località dal nome volutamente molto lungo, Lombardia, Italia',
    weatherCode: 2,
    description: 'Prevalentemente sereno',
    temperatureMin: -10,
    temperatureMax: -2,
    precipitationProbability: 100,
    windSpeedMax: 18,
    fetchedAt: null,
  );

  testWidgets('minimal weather summary fits a narrow race card',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: RaceWeatherPill(weather: weather),
            ),
          ),
        ),
      ),
    );

    expect(find.text('-10° / -2°'), findsOneWidget);
    expect(find.text('Pioggia 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weather detail panel fits a narrow page', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: RaceWeatherPanel(weather: weather),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Previsioni Open-Meteo · aggiornate automaticamente'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
