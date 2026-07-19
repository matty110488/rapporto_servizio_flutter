/// Central configuration for non-secret application parameters.
///
/// Secrets and environment-specific credentials must stay in Vercel, GitHub,
/// or Firebase configuration and must never be added to this file.
abstract final class AppConfig {
  /// Notion race databases, keyed by sporting season/year.
  ///
  /// Keep the entries ordered from oldest to newest. When a new annual
  /// database is ready, add it here after cloning the previous year's schema.
  static const Map<int, String> raceDatabaseIds = {
    2025: '2afde089ef9580e2b0e7d19d44f3a3f6',
    2026: '2b1de089ef9580729622ff9543046cbc',
  };

  static List<int> get configuredRaceYears =>
      List<int>.unmodifiable(raceDatabaseIds.keys);

  static List<String> get allRaceDatabaseIds =>
      List<String>.unmodifiable(raceDatabaseIds.values);

  /// First database used by pages that load every configured year.
  static String get primaryRaceDatabaseId => raceDatabaseIds.values.first;

  /// Remaining databases loaded together with [primaryRaceDatabaseId].
  static List<String> get additionalRaceDatabaseIds =>
      List<String>.unmodifiable(raceDatabaseIds.values.skip(1));

  static int get latestRaceYear => raceDatabaseIds.keys.last;

  static const dashboardRefreshInterval = Duration(minutes: 5);
  static const notificationBadgeRefreshInterval = Duration(seconds: 45);
  static const notificationsPageRefreshInterval = Duration(seconds: 30);
  static const reportDraftAutosaveInterval = Duration(seconds: 4);

  /// Vercel accepts request bodies up to 4.5 MB for this upload flow.
  static const int maxNotionPdfBytes = 4500000;
}

/// Notion property names that form the contract between the cloned annual
/// databases and the application.
abstract final class NotionRaceProperties {
  static const title = 'GARA';
  static const date = 'DATA GARA';
  static const location = "LOCALITA'";
  static const venue = 'SITO GARA';
  static const organizer = 'ORGANIZZATORE';
  static const packageId = 'ID SIC WIN';
  static const requestDate = 'DATA RICHIESTA';
  static const designatedTimekeepers = 'KRONOS DESIGNATI';
  static const serviceManager = 'DSC';
  static const secretaryPc = 'PC SEGRETERIA';
  static const equipment = 'APPARECCHIATURA';
  static const type = 'TIPOLOGIA';
  static const status = 'STATUS';
  static const files = 'Files & media';
}

/// Status values shared by filters, reports, archive, and Notion updates.
abstract final class RaceStatuses {
  static const designationSent = 'DESIGNAZIONE INVIATA';
  static const completed = 'GARA COMPLETATA';
  static const sicWinOk = 'SICWIN OK';
  static const reportReceived = 'RAPPORTINO RICEVUTO';
  static const reportSentLabel = 'RAPPORTINO INVIATO';

  static const reportCompilationAllowed = {
    designationSent,
    completed,
  };

  static const designationListAllowed = {
    designationSent,
    completed,
    sicWinOk,
  };

  static const archivedReports = {
    reportReceived,
    reportSentLabel,
  };
}
