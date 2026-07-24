import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/race_weather.dart';

IconData raceWeatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code >= 1 && code <= 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.water_drop_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 86) return Icons.grain_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_queue_rounded;
}

String raceWeatherTemperature(RaceWeather weather) {
  final minimum = weather.temperatureMin?.round();
  final maximum = weather.temperatureMax?.round();
  if (minimum == null && maximum == null) return '';
  if (minimum == null) return '$maximum°';
  if (maximum == null) return '$minimum°';
  return '$minimum° / $maximum°';
}

class RaceWeatherPill extends StatelessWidget {
  const RaceWeatherPill({
    super.key,
    required this.weather,
  });

  final RaceWeather weather;

  @override
  Widget build(BuildContext context) {
    final temperature = raceWeatherTemperature(weather);
    final rain = weather.precipitationProbability;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDCF8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            raceWeatherIcon(weather.weatherCode),
            size: 16,
            color: const Color(0xFF0A66C2),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              [
                weather.description,
                if (temperature.isNotEmpty) temperature,
                if (rain != null) 'pioggia $rain%',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF27415F),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RaceWeatherPanel extends StatelessWidget {
  const RaceWeatherPanel({
    super.key,
    required this.weather,
  });

  final RaceWeather weather;

  @override
  Widget build(BuildContext context) {
    final temperature = raceWeatherTemperature(weather);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E7F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100A4C8A),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  raceWeatherIcon(weather.weatherCode),
                  color: const Color(0xFF0A66C2),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREVISIONI GARA',
                      style: TextStyle(
                        color: Color(0xFF647587),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weather.description,
                      style: const TextStyle(
                        color: Color(0xFF1B344F),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (temperature.isNotEmpty)
                Text(
                  temperature,
                  style: const TextStyle(
                    color: Color(0xFF0A66C2),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth >= 460
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (weather.precipitationProbability != null)
                    SizedBox(
                      width: width,
                      child: _WeatherMetric(
                        icon: Icons.water_drop_outlined,
                        label: 'Pioggia',
                        value: '${weather.precipitationProbability}%',
                      ),
                    ),
                  if (weather.windSpeedMax != null)
                    SizedBox(
                      width: width,
                      child: _WeatherMetric(
                        icon: Icons.air_rounded,
                        label: 'Vento max',
                        value: '${weather.windSpeedMax!.round()} km/h',
                      ),
                    ),
                  if (weather.location.isNotEmpty)
                    SizedBox(
                      width: width,
                      child: _WeatherMetric(
                        icon: Icons.location_on_outlined,
                        label: 'Località',
                        value: weather.location,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 11),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => launchUrl(
              Uri.parse('https://open-meteo.com/'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'Previsioni Open-Meteo · aggiornate automaticamente',
                style: TextStyle(
                  color: Color(0xFF607D9A),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0A66C2)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF647587),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF27415F),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
