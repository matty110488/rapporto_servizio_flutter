import '../services/notion_service.dart';

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

    List<String> multiSelect(Map? obj) {
      if (obj == null) return [];
      final list = obj["multi_select"];
      if (list == null) return [];
      return List<String>.from(list.map((x) => x["name"]));
    }

    return Gara(
      id: json["id"],
      titolo: title(p["GARA"]),
      sport: p["SPORT"]?["select"]?["name"] ?? "",
      dataGara: p["DATA GARA"]?["date"]?["start"] ?? "",
      dataGaraFine: p["DATA GARA"]?["date"]?["end"] ?? "",
      localita: text(p["LOCALITÀ"]),
      sitoGara: text(p["SITO GARA"]),
      organizzatore: text(p["ORGANIZZATORE"]),
      dataRichiesta: p["DATA RICHIESTA"]?["date"]?["start"] ?? "",
      kronosIds: relation(p["KRONOS DESIGNATI"]),
      dscIds: relation(p["DSC"]),
      pcSegreteriaIds: relation(p["PC SEGRETERIA"]),
      apparecchiature: multiSelect(p["APPARECCHIATURA"]),
      tipologia: p["TIPOLOGIA"]?["select"]?["name"] ?? "",
      status: p["STATUS"]?["select"]?["name"] ?? "",
    );
  }
}
