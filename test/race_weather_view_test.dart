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

  testWidgets('weather summary fits a narrow race card', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: RaceWeatherPill(weather: weather),
                ),
                const SizedBox(height: 12),
                const RaceWeatherPanel(weather: weather),
              ],
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
