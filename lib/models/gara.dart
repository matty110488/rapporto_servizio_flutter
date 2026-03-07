class Gara {
  final String id;
  final String titolo;
  final String sport;
  final String dataGara;
  final String dataGaraFine;
  final String localita;
  final String sitoGara;
  final String organizzatore;
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
        "LOCALITA'",
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
        "STATUS",
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
      titolo: title(p["GARA"]),
      sport: pickSport(p),
      dataGara: p["DATA GARA"]?["date"]?["start"] ?? "",
      dataGaraFine: p["DATA GARA"]?["date"]?["end"] ?? "",
      localita: pickLocalita(p),
      sitoGara: text(p["SITO GARA"]),
      organizzatore: text(p["ORGANIZZATORE"]),
      dataRichiesta: p["DATA RICHIESTA"]?["date"]?["start"] ?? "",
      kronosIds: relation(p["KRONOS DESIGNATI"]),
      dscIds: relation(p["DSC"]),
      pcSegreteriaIds: relation(p["PC SEGRETERIA"]),
      apparecchiature: multiSelect(p["APPARECCHIATURA"]),
      tipologia: p["TIPOLOGIA"]?["select"]?["name"] ?? "",
      status: pickStatus(p),
    );
  }
}
