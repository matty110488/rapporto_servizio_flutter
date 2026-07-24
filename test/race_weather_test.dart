import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/race_weather.dart';

void main() {
  test('weather is available only from today through the next seven days', () {
    final now = DateTime(2026, 7, 24, 18);

    expect(
      RaceWeather.isForecastAvailableFor('2026-07-24', now: now),
      isTrue,
    );
    expect(
      RaceWeather.isForecastAvailableFor('2026-07-31', now: now),
      isTrue,
    );
    expect(
      RaceWeather.isForecastAvailableFor('2026-07-23', now: now),
      isFalse,
    );
    expect(
      RaceWeather.isForecastAvailableFor('2026-08-01', now: now),
      isFalse,
    );
  });

  test('parses the compact weather response', () {
    final weather = RaceWeather.fromJson({
      'date': '2026-07-27',
      'location': 'Sondrio, Lombardia, Italia',
      'weatherCode': 61,
      'description': 'Pioggia',
      'temperatureMin': 11.2,
      'temperatureMax': 19.8,
      'precipitationProbability': 70,
      'windSpeedMax': 16.4,
      'fetchedAt': '2026-07-24T12:00:00.000Z',
    });

    expect(weather.weatherCode, 61);
    expect(weather.temperatureMin, 11.2);
    expect(weather.precipitationProbability, 70);
    expect(weather.fetchedAt, isNotNull);
  });
}
