class ExpenseReportLine {
  const ExpenseReportLine({
    required this.category,
    required this.label,
    required this.date,
    required this.quantity,
    required this.unit,
    required this.unitRate,
    required this.amount,
  });

  final String category;
  final String label;
  final String date;
  final double quantity;
  final String unit;
  final double? unitRate;
  final double amount;

  factory ExpenseReportLine.fromJson(Map<String, dynamic> json) {
    double number(Object? value) => (value as num?)?.toDouble() ?? 0;
    return ExpenseReportLine(
      category: (json['category'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      quantity: number(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
      unitRate: json['unitRate'] == null ? null : number(json['unitRate']),
      amount: number(json['amount']),
    );
  }
}

class ExpenseReportSnapshot {
  const ExpenseReportSnapshot({
    required this.racePageId,
    required this.title,
    required this.sport,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.tariffVersion,
    required this.total,
    required this.totalsByCategory,
    required this.lines,
    required this.requiresManualReview,
    required this.warnings,
  });

  final String racePageId;
  final String title;
  final String sport;
  final String location;
  final String startDate;
  final String endDate;
  final String tariffVersion;
  final double total;
  final Map<String, double> totalsByCategory;
  final List<ExpenseReportLine> lines;
  final bool requiresManualReview;
  final List<String> warnings;

  factory ExpenseReportSnapshot.fromJson(Map<String, dynamic> json) {
    final race = json['race'] is Map
        ? Map<String, dynamic>.from(json['race'] as Map)
        : const <String, dynamic>{};
    final rawTotals = json['totalsByCategory'] is Map
        ? Map<String, dynamic>.from(json['totalsByCategory'] as Map)
        : const <String, dynamic>{};
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return ExpenseReportSnapshot(
      racePageId: (json['racePageId'] ?? '').toString(),
      title: (race['title'] ?? '').toString(),
      sport: (race['sport'] ?? '').toString(),
      location: (race['location'] ?? '').toString(),
      startDate: (race['startDate'] ?? '').toString(),
      endDate: (race['endDate'] ?? '').toString(),
      tariffVersion: (json['tariffVersion'] ?? '').toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      totalsByCategory: rawTotals.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0),
      ),
      lines: rawLines
          .whereType<Map>()
          .map((line) => ExpenseReportLine.fromJson(
                Map<String, dynamic>.from(line),
              ))
          .toList(growable: false),
      requiresManualReview: json['requiresManualReview'] == true,
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((warning) => warning.toString())
          .where((warning) => warning.isNotEmpty)
          .toList(growable: false),
    );
  }
}
