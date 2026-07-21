import '../config/app_config.dart';

class Gara {
  final String id;
  final String titolo;
  final String sport;
  final String dataGara;
  final String dataGaraFine;
  final String localita;
  final String sitoGara;
  final String organizzatore;
  final String idSicWin;
  final String dataRichiesta;

  final List<String> kronosIds;
  final List<String> dscIds;
  final List<String> pcSegreteriaIds;

  final List<String> apparecchiature;
  final String tipologia;
  final String status;

  Gara({
    required this.id,
    required this.titolo,
    required this.sport,
    required this.dataGara,
    required this.dataGaraFine,
    required this.localita,
    required this.sitoGara,
    required this.organizzatore,
    required this.idSicWin,
    required this.dataRichiesta,
    required this.kronosIds,
    required this.dscIds,
    required this.pcSegreteriaIds,
    required this.apparecchiature,
    required this.tipologia,
    required this.status,
  });

  factory Gara.fromNotion(Map<String, dynamic> json) {
    final p = json["properties"];

    // -------- SMALL HELPERS --------
    String text(Map? obj) {
      if (obj == null) return "";
      final rt = obj["rich_text"];
      if (rt == null || rt.isEmpty) return "";
      return rt[0]["plain_text"] ?? "";
    }

    String plainValue(Map? obj) {
      if (obj == null) return "";

      final richText = obj["rich_text"];
      if (richText is List && richText.isNotEmpty) {
        final first = richText.first;
        if (first is Map && first["plain_text"] is String) {
          return (first["plain_text"] as String).trim();
        }
      }

      final titleValue = obj["title"];
      if (titleValue is List && titleValue.isNotEmpty) {
        final first = titleValue.first;
        if (first is Map && first["plain_text"] is String) {
          return (first["plain_text"] as String).trim();
        }
      }

      final number = obj["number"];
      if (number != null) return number.toString();

      final select = obj["select"];
      if (select is Map && select["name"] is String) {
        return (select["name"] as String).trim();
      }

      final formula = obj["formula"];
      if (formula is Map) {
        final string = formula["string"];
        if (string is String && string.trim().isNotEmpty) {
          return string.trim();
        }
        final formulaNumber = formula["number"];
        if (formulaNumber != null) return formulaNumber.toString();
      }

      return "";
    }

    String title(Map? obj) {
      if (obj == null) return "";
      final t = obj["title"];
      if (t == null || t.isEmpty) return "";
      return t[0]["plain_text"] ?? "";
    }

    List<String> relation(Map? obj) {
      if (obj == null) return [];
      final list = obj["relation"];
      if (list == null) return [];
      return List<String>.from(list.map((x) => x["id"]));
    }

    String selectOrStatusName(Map? obj) {
      if (obj == null) return "";

      String pick(Map? source) {
        if (source == null) return "";
        final name = source["name"];
        if (name is String && name.isNotEmpty) return name;
        return "";
      }

      final selectName = pick(obj["select"]);
      if (selectName.isNotEmpty) return selectName;

      final statusName = pick(obj["status"]);
      if (statusName.isNotEmpty) return statusName;

      return "";
    }

    List<String> multiSelect(Map? obj) {
      if (obj == null) return [];
      final list = obj["multi_select"];
      if (list == null) return [];
      return List<String>.from(list.map((x) => x["name"]));
    }

    String pickSport(Map<String, dynamic>? props) {
      if (props == null) return "";
      const candidateKeys = [
        "SPORT",
        "Sport",
        "DISCIPLINA",
        "Disciplina",
        "DISCIPLINE",
        "Discipline",
      ];

      for (final key in candidateKeys) {
        final value = props[key];
        if (value is Map<String, dynamic>) {
          // Select / Status
          final selectValue = selectOrStatusName(value);
          if (selectValue.isNotEmpty) return selectValue;

          // Multi-select
          final multi = multiSelect(value);
          if (multi.isNotEmpty) return multi.join(', ');
        }
      }

      return "";
    }

    String pickLocalita(Map? props) {
      if (props == null) return "";
      const candidateKeys = [
        NotionRaceProperties.location,
        "LOCALITA\u2019",
        "LOCALIT\u00c0",
        "LOCALITA",
        "LOCALITA?",
      ];

      for (final key in candidateKeys) {
        final value = text(props[key]);
        if (value.isNotEmpty) return value;
      }
      return "";
    }

    String pickStatus(Map<String, dynamic>? props) {
      if (props == null) return "";
      const candidateKeys = [
        NotionRaceProperties.status,
        "STATUS GARA",
        "STATO",
        "STATO GARA",
      ];

      for (final key in candidateKeys) {
        final value = selectOrStatusName(props[key]);
        if (value.isNotEmpty) return value;
      }

      // Fallback: pick the first status/select property available.
      for (final entry in props.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final type = value["type"];
          if (type == "status" || type == "select") {
            final name = selectOrStatusName(value);
            if (name.isNotEmpty) return name;
          }
        }
      }
      return "";
    }

    return Gara(
      id: json["id"],
      titolo: title(p[NotionRaceProperties.title]),
      sport: pickSport(p),
      dataGara: p[NotionRaceProperties.date]?["date"]?["start"] ?? "",
      dataGaraFine: p[NotionRaceProperties.date]?["date"]?["end"] ?? "",
      localita: pickLocalita(p),
      sitoGara: text(p[NotionRaceProperties.venue]),
      organizzatore: text(p[NotionRaceProperties.organizer]),
      idSicWin: plainValue(p[NotionRaceProperties.packageId]),
      dataRichiesta:
          p[NotionRaceProperties.requestDate]?["date"]?["start"] ?? "",
      kronosIds: relation(p[NotionRaceProperties.designatedTimekeepers]),
      dscIds: relation(p[NotionRaceProperties.serviceManager]),
      pcSegreteriaIds: relation(p[NotionRaceProperties.secretaryPc]),
      apparecchiature: multiSelect(p[NotionRaceProperties.equipment]),
      tipologia: p[NotionRaceProperties.type]?["select"]?["name"] ?? "",
      status: pickStatus(p),
    );
  }

  static String statusLabel(String rawStatus) {
    final normalized = rawStatus.trim().toUpperCase();
    if (normalized == RaceStatuses.reportReceived) {
      return RaceStatuses.reportSentLabel;
    }
    return rawStatus;
  }
}
