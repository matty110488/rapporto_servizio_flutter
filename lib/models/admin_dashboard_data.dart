import '../config/app_config.dart';
import 'gara.dart';

enum AdminAttentionType {
  incompleteDesignation,
  pendingReport,
  incompleteData,
}

enum AdminAttentionUrgency { critical, warning, normal }

class AdminAttentionItem {
  const AdminAttentionItem({
    required this.type,
    required this.gara,
    required this.message,
    required this.timingLabel,
    required this.urgency,
    this.dueDate,
  });

  final AdminAttentionType type;
  final Gara gara;
  final String message;
  final String timingLabel;
  final AdminAttentionUrgency urgency;
  final DateTime? dueDate;
}

class AdminDashboardData {
  const AdminDashboardData({
    this.upcomingRaces = const [],
    this.incompleteDesignations = const [],
    this.pendingReports = const [],
    this.incompleteData = const [],
    this.attentionItems = const [],
  });

  final List<Gara> upcomingRaces;
  final List<Gara> incompleteDesignations;
  final List<Gara> pendingReports;
  final List<Gara> incompleteData;
  final List<AdminAttentionItem> attentionItems;

  static AdminDashboardData fromGare(
    List<Gara> gare, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final horizon = today.add(const Duration(days: 30));

    DateTime? raceDate(Gara gara) {
      final parsed = DateTime.tryParse(gara.dataGara);
      return parsed == null
          ? null
          : DateTime(parsed.year, parsed.month, parsed.day);
    }

    bool isArchived(Gara gara) {
      final status = Gara.statusLabel(gara.status).trim().toUpperCase();
      return RaceStatuses.archivedReports.contains(status);
    }

    ({String label, AdminAttentionUrgency urgency}) futureTiming(
      DateTime? date,
    ) {
      if (date == null) {
        return (
          label: 'Nessuna data impostata',
          urgency: AdminAttentionUrgency.critical,
        );
      }
      final days = date.difference(today).inDays;
      if (days <= 0) {
        return (
          label: 'Scade oggi',
          urgency: AdminAttentionUrgency.critical,
        );
      }
      if (days == 1) {
        return (
          label: 'Scade domani',
          urgency: AdminAttentionUrgency.warning,
        );
      }
      return (
        label: 'Scade tra $days giorni',
        urgency: days <= 7
            ? AdminAttentionUrgency.warning
            : AdminAttentionUrgency.normal,
      );
    }

    ({String label, AdminAttentionUrgency urgency}) overdueTiming(
      DateTime date,
    ) {
      final days = today.difference(date).inDays;
      return (
        label:
            days == 1 ? 'In ritardo da 1 giorno' : 'In ritardo da $days giorni',
        urgency: days >= 7
            ? AdminAttentionUrgency.critical
            : AdminAttentionUrgency.warning,
      );
    }

    final upcoming = gare.where((gara) {
      final date = raceDate(gara);
      return date != null &&
          !date.isBefore(today) &&
          !date.isAfter(horizon) &&
          !isArchived(gara);
    }).toList()
      ..sort((a, b) => raceDate(a)!.compareTo(raceDate(b)!));

    final incompleteDesignations = upcoming
        .where((gara) => gara.dscIds.isEmpty || gara.kronosIds.isEmpty)
        .toList();

    final pendingReports = gare.where((gara) {
      final date = raceDate(gara);
      if (date == null || !date.isBefore(today) || isArchived(gara)) {
        return false;
      }
      final status = gara.status.trim().toUpperCase();
      return status == RaceStatuses.designationSent ||
          status == RaceStatuses.completed;
    }).toList()
      ..sort((a, b) => raceDate(b)!.compareTo(raceDate(a)!));

    final incompleteData = gare.where((gara) {
      final date = raceDate(gara);
      final isOperational = date == null ||
          !date.isBefore(today) ||
          pendingReports.contains(gara);
      return isOperational &&
          (gara.titolo.trim().isEmpty ||
              gara.dataGara.trim().isEmpty ||
              gara.sport.trim().isEmpty ||
              gara.localita.trim().isEmpty);
    }).toList()
      ..sort((a, b) {
        final aDate = raceDate(a);
        final bDate = raceDate(b);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return aDate.compareTo(bDate);
      });

    final attention = <AdminAttentionItem>[
      ...incompleteDesignations.map((gara) {
        final date = raceDate(gara);
        final timing = futureTiming(date);
        final missing = <String>[
          if (gara.dscIds.isEmpty) 'DSC',
          if (gara.kronosIds.isEmpty) 'cronometristi',
        ];
        return AdminAttentionItem(
          type: AdminAttentionType.incompleteDesignation,
          gara: gara,
          message: 'Mancano ${missing.join(' e ')}',
          timingLabel: timing.label,
          urgency: timing.urgency,
          dueDate: date,
        );
      }),
      ...pendingReports.map((gara) {
        final date = raceDate(gara)!;
        final timing = overdueTiming(date);
        return AdminAttentionItem(
          type: AdminAttentionType.pendingReport,
          gara: gara,
          message: 'Rapportino non ancora ricevuto',
          timingLabel: timing.label,
          urgency: timing.urgency,
          dueDate: date,
        );
      }),
      ...incompleteData.map((gara) {
        final date = raceDate(gara);
        final timing = date != null && date.isBefore(today)
            ? overdueTiming(date)
            : futureTiming(date);
        final missing = <String>[
          if (gara.titolo.trim().isEmpty) 'titolo',
          if (gara.dataGara.trim().isEmpty) 'data',
          if (gara.sport.trim().isEmpty) 'sport',
          if (gara.localita.trim().isEmpty) 'località',
        ];
        return AdminAttentionItem(
          type: AdminAttentionType.incompleteData,
          gara: gara,
          message: 'Dati mancanti: ${missing.join(', ')}',
          timingLabel: timing.label,
          urgency: timing.urgency,
          dueDate: date,
        );
      }),
    ];
    attention.sort((a, b) {
      final urgency = a.urgency.index.compareTo(b.urgency.index);
      if (urgency != 0) return urgency;
      final aDate = a.dueDate;
      final bDate = b.dueDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

    return AdminDashboardData(
      upcomingRaces: List.unmodifiable(upcoming),
      incompleteDesignations: List.unmodifiable(incompleteDesignations),
      pendingReports: List.unmodifiable(pendingReports),
      incompleteData: List.unmodifiable(incompleteData),
      attentionItems: List.unmodifiable(attention),
    );
  }
}
