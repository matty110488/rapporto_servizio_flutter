import 'gara.dart';

class GaraPackage {
  const GaraPackage._({
    required this.gare,
    required this.packageId,
    required this.suggested,
  });

  factory GaraPackage.single(Gara gara) => GaraPackage._(
        gare: [gara],
        packageId: null,
        suggested: false,
      );

  factory GaraPackage.group({
    required List<Gara> gare,
    String? packageId,
    required bool suggested,
  }) =>
      GaraPackage._(
        gare: List<Gara>.unmodifiable(_sortGareByDate(gare)),
        packageId: packageId,
        suggested: suggested,
      );

  final List<Gara> gare;
  final String? packageId;
  final bool suggested;

  bool get isPackage => gare.length > 1;
  bool get isConfirmedPackage => isPackage && !suggested && packageId != null;
  Gara get primary => gare.first;

  String get stableKey {
    final id = packageId?.trim();
    if (id != null && id.isNotEmpty) return 'package:$id';
    if (gare.length == 1) return 'gara:${gare.first.id}';
    final ids = gare.map((gara) => gara.id).toList()..sort();
    return 'suggested:${ids.join(',')}';
  }

  List<DateTime> get activeDates {
    final values = <String, DateTime>{};
    for (final gara in gare) {
      final start = _dateOnly(DateTime.tryParse(gara.dataGara));
      if (start == null) continue;
      final parsedEnd = _dateOnly(DateTime.tryParse(gara.dataGaraFine));
      final end =
          parsedEnd != null && !parsedEnd.isBefore(start) ? parsedEnd : start;
      final total = end.difference(start).inDays + 1;
      for (var index = 0; index < total; index++) {
        final date = start.add(Duration(days: index));
        values[_isoDate(date)] = date;
      }
    }
    final dates = values.values.toList()..sort();
    return List<DateTime>.unmodifiable(dates);
  }

  DateTime? get startDate => activeDates.isEmpty ? null : activeDates.first;
  DateTime? get endDate => activeDates.isEmpty ? null : activeDates.last;

  String get title {
    if (gare.isEmpty) return 'Pacchetto gare';
    if (gare.length == 1) return gare.first.titolo;

    final cleaned = gare
        .map((gara) => _cleanTitle(gara.titolo))
        .where((value) => value.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return gare.first.titolo;

    final firstTokens = cleaned.first.split(' ');
    var commonLength = firstTokens.length;
    for (final value in cleaned.skip(1)) {
      final tokens = value.split(' ');
      var index = 0;
      while (index < commonLength &&
          index < tokens.length &&
          firstTokens[index].toLowerCase() == tokens[index].toLowerCase()) {
        index++;
      }
      commonLength = index;
    }
    if (commonLength >= 2) {
      return firstTokens.take(commonLength).join(' ');
    }
    return cleaned.first;
  }
}

List<GaraPackage> buildGaraPackages(List<Gara> source) {
  final manualGroups = <String, List<Gara>>{};
  final withoutManualGroup = <Gara>[];

  for (final gara in _sortGareByDate(source)) {
    final packageId = gara.idSicWin.trim();
    if (packageId.isEmpty) {
      withoutManualGroup.add(gara);
    } else {
      manualGroups.putIfAbsent(packageId, () => []).add(gara);
    }
  }

  final entries = <GaraPackage>[];
  for (final group in manualGroups.entries) {
    if (group.value.length > 1) {
      entries.add(
        GaraPackage.group(
          gare: group.value,
          packageId: group.key,
          suggested: false,
        ),
      );
    } else {
      withoutManualGroup.addAll(group.value);
    }
  }

  entries.addAll(_suggestedPackages(withoutManualGroup));
  entries.sort(_comparePackages);
  return entries;
}

List<GaraPackage> _suggestedPackages(List<Gara> source) {
  final entries = <GaraPackage>[];
  final used = <String>{};
  final sorted = _sortGareByDate(source);

  for (final gara in sorted) {
    if (used.contains(gara.id)) continue;

    final group = <Gara>[gara];
    used.add(gara.id);
    var previous = gara;

    for (final candidate in sorted) {
      if (used.contains(candidate.id)) continue;
      if (_canSuggestSamePackage(previous, candidate, group.first)) {
        group.add(candidate);
        used.add(candidate.id);
        previous = candidate;
      }
    }

    entries.add(
      group.length > 1
          ? GaraPackage.group(gare: group, suggested: true)
          : GaraPackage.single(gara),
    );
  }
  return entries;
}

bool _canSuggestSamePackage(Gara previous, Gara candidate, Gara first) {
  final previousDate = _dateOnly(DateTime.tryParse(previous.dataGara));
  final candidateDate = _dateOnly(DateTime.tryParse(candidate.dataGara));
  if (previousDate == null || candidateDate == null) return false;

  final dayGap = candidateDate.difference(previousDate).inDays;
  if (dayGap < 1 || dayGap > 2) return false;

  final previousPlace = _normalizedPlace(previous);
  final candidatePlace = _normalizedPlace(candidate);
  if (previousPlace.isEmpty || previousPlace != candidatePlace) return false;

  final firstOrganizer = _normalizeText(first.organizzatore);
  final candidateOrganizer = _normalizeText(candidate.organizzatore);
  if (firstOrganizer.isNotEmpty &&
      candidateOrganizer.isNotEmpty &&
      firstOrganizer != candidateOrganizer) {
    return false;
  }

  final firstSport = _normalizeText(first.sport);
  final candidateSport = _normalizeText(candidate.sport);
  if (firstSport.isNotEmpty &&
      candidateSport.isNotEmpty &&
      firstSport != candidateSport) {
    return false;
  }
  return _titlesLookRelated(first.titolo, candidate.titolo);
}

bool _titlesLookRelated(String first, String second) {
  final firstTokens = _titleTokens(first);
  final secondTokens = _titleTokens(second);
  if (firstTokens.isEmpty || secondTokens.isEmpty) return false;

  if (firstTokens.intersection(secondTokens).length >= 2) return true;
  final normalizedFirst = firstTokens.join(' ');
  final normalizedSecond = secondTokens.join(' ');
  return normalizedFirst.length >= 8 &&
      normalizedSecond.length >= 8 &&
      (normalizedFirst.contains(normalizedSecond) ||
          normalizedSecond.contains(normalizedFirst));
}

Set<String> _titleTokens(String value) {
  const ignored = {
    'gara',
    'giornata',
    'giornate',
    'sabato',
    'domenica',
    'venerdi',
    'lunedi',
    'martedi',
    'mercoledi',
    'giovedi',
    'prima',
    'seconda',
    'terza',
    '1',
    '2',
    '3',
  };
  return _normalizeText(value)
      .split(' ')
      .where((token) => token.length > 2 && !ignored.contains(token))
      .toSet();
}

String _normalizedPlace(Gara gara) {
  final localita = _normalizeText(gara.localita);
  return localita.isNotEmpty ? localita : _normalizeText(gara.sitoGara);
}

String _normalizeText(String value) {
  var text = value.toLowerCase().trim();
  const replacements = {
    'à': 'a',
    'è': 'e',
    'é': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };
  replacements.forEach((from, to) => text = text.replaceAll(from, to));
  return text
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

List<Gara> _sortGareByDate(List<Gara> source) => List<Gara>.from(source)
  ..sort((first, second) {
    final firstDate = DateTime.tryParse(first.dataGara);
    final secondDate = DateTime.tryParse(second.dataGara);
    if (firstDate != null && secondDate != null) {
      final comparison = firstDate.compareTo(secondDate);
      if (comparison != 0) return comparison;
    } else if (firstDate != null) {
      return -1;
    } else if (secondDate != null) {
      return 1;
    }
    return first.titolo.toLowerCase().compareTo(second.titolo.toLowerCase());
  });

int _comparePackages(GaraPackage first, GaraPackage second) {
  final firstDate = first.startDate;
  final secondDate = second.startDate;
  if (firstDate != null && secondDate != null) {
    final comparison = firstDate.compareTo(secondDate);
    if (comparison != 0) return comparison;
  } else if (firstDate != null) {
    return -1;
  } else if (secondDate != null) {
    return 1;
  }
  return first.title.toLowerCase().compareTo(second.title.toLowerCase());
}

String _cleanTitle(String value) {
  var title = value.trim();
  final patterns = [
    RegExp(r'\bSabato\b', caseSensitive: false),
    RegExp(r'\bDomenica\b', caseSensitive: false),
    RegExp(r'\bVenerd[iì]\b', caseSensitive: false),
    RegExp(r'\b1a giornata\b', caseSensitive: false),
    RegExp(r'\b2a giornata\b', caseSensitive: false),
    RegExp(r'\b3a giornata\b', caseSensitive: false),
    RegExp(r'\bprima giornata\b', caseSensitive: false),
    RegExp(r'\bseconda giornata\b', caseSensitive: false),
    RegExp(r'\bterza giornata\b', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    title = title.replaceAll(pattern, '');
  }
  return title
      .replaceAll(RegExp(r'\s+[-–—]\s*$'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? _dateOnly(DateTime? value) =>
    value == null ? null : DateTime(value.year, value.month, value.day);

String _isoDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
