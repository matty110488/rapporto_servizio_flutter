import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/gara.dart';
import '../models/race_weather.dart';
import '../state/session_state.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? _sharedClient;

  static final http.Client _sharedClient = http.Client();
  static final Map<String, _WeatherCacheEntry> _cache = {};
  static final Map<String, Future<RaceWeather?>> _pending = {};
  static const _cacheDuration = Duration(hours: 2);

  final http.Client _client;

  Future<RaceWeather?> fetchForRace(
    Gara gara, {
    bool forceRefresh = false,
  }) {
    final location = _locationFor(gara);
    if (location.isEmpty ||
        !RaceWeather.isForecastAvailableFor(gara.dataGara)) {
      return Future.value(null);
    }
    return fetch(
      location: location,
      date: _dateOnly(gara.dataGara),
      forceRefresh: forceRefresh,
    );
  }

  Future<RaceWeather?> fetch({
    required String location,
    required String date,
    bool forceRefresh = false,
  }) async {
    final normalizedLocation = location.trim();
    final cacheKey = '${normalizedLocation.toLowerCase()}|$date';
    final cached = _cache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.loadedAt) < _cacheDuration) {
      return cached.weather;
    }

    final pending = _pending[cacheKey];
    if (pending != null) return pending;

    final request = _fetchFromBackend(
      location: normalizedLocation,
      date: date,
    );
    _pending[cacheKey] = request;
    try {
      final weather = await request;
      _cache[cacheKey] = _WeatherCacheEntry(
        weather: weather,
        loadedAt: DateTime.now(),
      );
      return weather;
    } finally {
      if (identical(_pending[cacheKey], request)) {
        _pending.remove(cacheKey);
      }
    }
  }

  Future<RaceWeather?> _fetchFromBackend({
    required String location,
    required String date,
  }) async {
    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) return null;

    try {
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({
          'action': 'getRaceWeather',
          'location': location,
          'date': date,
        }),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final weather = data['weather'];
      if (weather is! Map<String, dynamic>) return null;
      return RaceWeather.fromJson(weather);
    } catch (_) {
      return null;
    }
  }

  static String _locationFor(Gara gara) {
    final locality = gara.localita.trim();
    if (locality.isNotEmpty) return locality;
    return gara.sitoGara.trim();
  }

  static String _dateOnly(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }
}

class _WeatherCacheEntry {
  const _WeatherCacheEntry({
    required this.weather,
    required this.loadedAt,
  });

  final RaceWeather? weather;
  final DateTime loadedAt;
}
