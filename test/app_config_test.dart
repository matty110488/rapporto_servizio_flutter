import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';

void main() {
  test('annual Notion database configuration is valid and ordered', () {
    final years = AppConfig.configuredRaceYears;
    final sortedYears = [...years]..sort();

    expect(years, sortedYears);
    expect(years, containsAll(<int>[2025, 2026]));
    expect(AppConfig.raceDatabaseIds.values.toSet().length,
        AppConfig.raceDatabaseIds.length);
    for (final id in AppConfig.allRaceDatabaseIds) {
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
  });

  test('primary and additional database lists cover every configured year', () {
    expect(
      <String>[
        AppConfig.primaryRaceDatabaseId,
        ...AppConfig.additionalRaceDatabaseIds,
      ],
      AppConfig.allRaceDatabaseIds,
    );
    expect(AppConfig.latestRaceYear, AppConfig.configuredRaceYears.last);
  });

  test('Notion schema contract contains the properties required by reports',
      () {
    expect(NotionRaceProperties.title, 'GARA');
    expect(NotionRaceProperties.date, 'DATA GARA');
    expect(NotionRaceProperties.status, 'STATUS');
    expect(NotionRaceProperties.files, 'Files & media');
    expect(NotionRaceProperties.packageId, 'ID SIC WIN');
  });
}
