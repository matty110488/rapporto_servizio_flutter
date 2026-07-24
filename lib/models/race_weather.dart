class RaceWeather {
  const RaceWeather({
    required this.date,
    required this.location,
    required this.weatherCode,
    required this.description,
    required this.temperatureMin,
    required this.temperatureMax,
    required this.precipitationProbability,
    required this.windSpeedMax,
    required this.fetchedAt,
  });

  final String date;
  final String location;
  final int weatherCode;
  final String description;
  final double? temperatureMin;
  final double? temperatureMax;
  final int? precipitationProbability;
  final double? windSpeedMax;
  final DateTime? fetchedAt;

  factory RaceWeather.fromJson(Map<String, dynamic> json) {
    double? decimal(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    int? integer(String key) {
      final value = json[key];
      return value is num ? value.round() : int.tryParse('$value');
    }

    return RaceWeather(
      date: json['date'] as String? ?? '',
      location: json['location'] as String? ?? '',
      weatherCode: integer('weatherCode') ?? -1,
      description: json['description'] as String? ?? 'Variabile',
      temperatureMin: decimal('temperatureMin'),
      temperatureMax: decimal('temperatureMax'),
      precipitationProbability: integer('precipitationProbability'),
      windSpeedMax: decimal('windSpeedMax'),
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? ''),
    );
  }

  static bool isForecastAvailableFor(
    String dateValue, {
    DateTime? now,
    int forecastDays = 7,
  }) {
    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return false;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final raceDay = DateTime(parsed.year, parsed.month, parsed.day);
    final dayOffset = raceDay.difference(today).inDays;
    return dayOffset >= 0 && dayOffset <= forecastDays;
  }
}
