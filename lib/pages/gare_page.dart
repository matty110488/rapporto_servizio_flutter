import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../services/prank_popup_service.dart';
import '../widgets/help_dialog.dart';
import '../widgets/stopwatch_loading.dart';
import 'dettaglio_gara.dart';

class GarePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  const GarePage({super.key, required this.loggedUser});

  @override
  State<GarePage> createState() => _GarePageState();
}

class _GarePageState extends State<GarePage> {
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';
  static const Map<int, String> _databaseByYear = {
    2025: _db2025,
    2026: _db2026,
  };

  late NotionService notion;
  List<Gara> gare = [];
  bool loading = true;
  Set<String> updatingGare = {};
  Set<String> expandedMonths = {};
  int selectedYear = DateTime.now().year;
  _CalendarPeriod calendarPeriod = _CalendarPeriod.upcoming;
  _AssignmentFilter assignmentFilter = _AssignmentFilter.all;
  String sportFilter = '';

  @override
  void initState() {
    super.initState();

    if (!_databaseByYear.containsKey(selectedYear)) {
      selectedYear = _databaseByYear.keys.reduce((a, b) => a > b ? a : b);
    }
    notion = NotionService(databaseId: _databaseByYear[selectedYear]!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrankPopupService.maybeShow(context, widget.loggedUser);
    });

    load();
  }

  Future<void> load({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() {
        loading = true;
      });
    }
    notion = NotionService(databaseId: _databaseByYear[selectedYear]!);
    final results = await notion.fetchGare();
    final nextGare = results.map((e) => Gara.fromNotion(e)).toList();

    if (!mounted) return;
    setState(() {
      gare = nextGare;
      expandedMonths = _defaultExpandedMonths(nextGare);
      loading = false;
    });
  }

  Future<void> _changeYear(int year) async {
    if (year == selectedYear) return;
    setState(() {
      selectedYear = year;
      sportFilter = '';
      assignmentFilter = _AssignmentFilter.all;
      calendarPeriod = year < DateTime.now().year
          ? _CalendarPeriod.past
          : _CalendarPeriod.upcoming;
      loading = true;
    });
    await load();
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool _isUserAssigned(Gara gara) {
    final userId = _loggedUserId;
    if (userId == null) return false;
    return gara.kronosIds.contains(userId);
  }

  bool _puoCandidarsi(Gara gara) {
    final upper = gara.status.toUpperCase();
    return upper == 'DA GESTIRE' || upper == 'IN PROGRESS';
  }

  bool _isDisponibilitaData(Gara gara) {
    return _isUserAssigned(gara) && _puoCandidarsi(gara);
  }

  bool _isDesignato(Gara gara) {
    return _isUserAssigned(gara) && !_puoCandidarsi(gara);
  }

  bool _isPastEvent(Gara gara) {
    final end = _parseDate(gara.dataGaraFine);
    final start = _parseDate(gara.dataGara);
    final reference = end ?? start;
    if (reference == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(reference.year, reference.month, reference.day);
    return eventDay.isBefore(today);
  }

  String _loggedUserName() {
    final props = widget.loggedUser['properties'];
    if (props is Map<String, dynamic>) {
      String propertyText(List<String> keys) {
        for (final key in keys) {
          final value = props[key];
          if (value is! Map<String, dynamic>) continue;

          final title = value['title'];
          if (title is List && title.isNotEmpty) {
            final first = title.first;
            if (first is Map<String, dynamic>) {
              final plain = first['plain_text'];
              if (plain is String && plain.trim().isNotEmpty) {
                return plain.trim();
              }
            }
          }

          final richText = value['rich_text'];
          if (richText is List && richText.isNotEmpty) {
            final first = richText.first;
            if (first is Map<String, dynamic>) {
              final plain = first['plain_text'];
              if (plain is String && plain.trim().isNotEmpty) {
                return plain.trim();
              }
            }
          }
        }
        return '';
      }

      final nome = propertyText(const ['NOME', 'Nome', 'nome', 'FIRST_NAME']);
      final cognome = propertyText(
        const ['COGNOME', 'Cognome', 'cognome', 'LAST_NAME'],
      );
      if (nome.isNotEmpty && cognome.isNotEmpty) {
        return '$nome $cognome';
      }
      if (cognome.isNotEmpty) return cognome;
      if (nome.isNotEmpty) return nome;

      for (final value in props.values) {
        if (value is! Map<String, dynamic>) continue;
        if (value['type'] == 'title') {
          final titles = value['title'] as List<dynamic>? ?? const [];
          if (titles.isNotEmpty) {
            final first = titles.first;
            if (first is Map<String, dynamic>) {
              final plain = first['plain_text'];
              if (plain is String && plain.trim().isNotEmpty) {
                return plain.trim();
              }
            }
          }
        }
        if (value['type'] == 'rich_text') {
          final texts = value['rich_text'] as List<dynamic>? ?? const [];
          if (texts.isNotEmpty) {
            final first = texts.first;
            if (first is Map<String, dynamic>) {
              final plain = first['plain_text'];
              if (plain is String && plain.trim().isNotEmpty) {
                return plain.trim();
              }
            }
          }
        }
      }
    }

    final id = _loggedUserId;
    if (id != null && id.isNotEmpty) return id;
    return 'Utente';
  }

  List<String> _parseDisponibilitaNames(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _mergeDisponibilitaViaApp({
    required String currentValue,
    required String currentUserName,
    required bool join,
  }) {
    final names = _parseDisponibilitaNames(currentValue);
    bool containsName(String target) => names.any(
          (n) => n.toLowerCase() == target.toLowerCase(),
        );

    if (join) {
      if (!containsName(currentUserName)) {
        names.add(currentUserName);
      }
    } else {
      names.removeWhere(
        (n) => n.toLowerCase() == currentUserName.toLowerCase(),
      );
    }
    return names.join(', ');
  }

  List<Gara> _applyFilters(List<Gara> source) {
    var filtered = List<Gara>.from(source);
    filtered = filtered
        .where((g) => g.status.trim().toUpperCase() != 'VENDUTA')
        .toList();
    filtered = filtered.where((g) {
      final isPast = _isPastEvent(g);
      return calendarPeriod == _CalendarPeriod.past ? isPast : !isPast;
    }).toList();
    if (assignmentFilter == _AssignmentFilter.disponibilita) {
      filtered = filtered.where(_isDisponibilitaData).toList();
    } else if (assignmentFilter == _AssignmentFilter.designato) {
      filtered = filtered.where(_isDesignato).toList();
    }
    if (sportFilter.isNotEmpty) {
      filtered = filtered.where((g) => g.sport.trim() == sportFilter).toList();
    }
    return filtered;
  }

  Set<String> _defaultExpandedMonths(List<Gara> source) {
    final filtered = source
        .where((g) => g.status.trim().toUpperCase() != 'VENDUTA')
        .where((g) {
      final isPast = _isPastEvent(g);
      return calendarPeriod == _CalendarPeriod.past ? isPast : !isPast;
    }).toList();
    final grouped = _garePerMese(filtered);
    if (calendarPeriod == _CalendarPeriod.past) {
      return grouped.keys.take(2).toSet();
    }
    return grouped.keys.toSet();
  }

  List<String> _sportsOptions() {
    final sports = gare
        .where((g) => g.status.trim().toUpperCase() != 'VENDUTA')
        .map((g) => g.sport.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sports;
  }

  Map<String, List<_CalendarEntry>> _garePerMese(List<Gara> source) {
    final sorted = List<Gara>.from(source)
      ..sort((a, b) {
        final da = _parseDate(a.dataGara);
        final db = _parseDate(b.dataGara);

        if (da != null && db != null) {
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
        } else if (da != null && db == null) {
          return -1;
        } else if (da == null && db != null) {
          return 1;
        }

        return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
      });

    final entries = _calendarEntries(sorted);
    final Map<String, List<_CalendarEntry>> grouped = {};
    for (final entry in entries) {
      final date = entry.startDate;
      final label = date == null ? 'Senza data' : _meseAnno(date);
      grouped.putIfAbsent(label, () => []).add(entry);
    }

    return grouped;
  }

  List<_CalendarEntry> _calendarEntries(List<Gara> sorted) {
    final manualGroups = <String, List<Gara>>{};
    final withoutManualGroup = <Gara>[];

    for (final gara in sorted) {
      final packageId = gara.idSicWin.trim();
      if (packageId.isEmpty) {
        withoutManualGroup.add(gara);
      } else {
        manualGroups.putIfAbsent(packageId, () => []).add(gara);
      }
    }

    final entries = <_CalendarEntry>[];
    for (final group in manualGroups.entries) {
      final gare = _sortGareByDate(group.value);
      if (gare.length > 1) {
        entries.add(
          _CalendarEntry.package(
            gare: gare,
            packageId: group.key,
            suggested: false,
          ),
        );
      } else {
        withoutManualGroup.addAll(gare);
      }
    }

    entries
        .addAll(_suggestedPackageEntries(_sortGareByDate(withoutManualGroup)));
    entries.sort(_compareCalendarEntries);
    return entries;
  }

  List<_CalendarEntry> _suggestedPackageEntries(List<Gara> source) {
    final entries = <_CalendarEntry>[];
    final used = <String>{};

    for (final gara in source) {
      if (used.contains(gara.id)) continue;

      final group = <Gara>[gara];
      used.add(gara.id);
      var last = gara;

      for (final candidate in source) {
        if (used.contains(candidate.id)) continue;
        if (_canSuggestSamePackage(last, candidate, group.first)) {
          group.add(candidate);
          used.add(candidate.id);
          last = candidate;
        }
      }

      if (group.length > 1) {
        entries.add(
          _CalendarEntry.package(
            gare: _sortGareByDate(group),
            suggested: true,
          ),
        );
      } else {
        entries.add(_CalendarEntry.single(gara));
      }
    }

    return entries;
  }

  bool _canSuggestSamePackage(Gara previous, Gara candidate, Gara first) {
    final previousDate = _parseDate(previous.dataGara);
    final candidateDate = _parseDate(candidate.dataGara);
    if (previousDate == null || candidateDate == null) return false;

    final previousDay = DateTime(
      previousDate.year,
      previousDate.month,
      previousDate.day,
    );
    final candidateDay = DateTime(
      candidateDate.year,
      candidateDate.month,
      candidateDate.day,
    );
    final dayGap = candidateDay.difference(previousDay).inDays;
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

  bool _titlesLookRelated(String a, String b) {
    final aTokens = _titleTokens(a);
    final bTokens = _titleTokens(b);
    if (aTokens.isEmpty || bTokens.isEmpty) return false;

    final common = aTokens.intersection(bTokens);
    if (common.length >= 2) return true;

    final normalizedA = aTokens.join(' ');
    final normalizedB = bTokens.join(' ');
    return normalizedA.length >= 8 &&
        normalizedB.length >= 8 &&
        (normalizedA.contains(normalizedB) ||
            normalizedB.contains(normalizedA));
  }

  Set<String> _titleTokens(String value) {
    const ignored = {
      'gara',
      'giornata',
      'giornate',
      'sabato',
      'domenica',
      'venerdi',
      'venerdì',
      'lunedi',
      'lunedì',
      'martedi',
      'martedì',
      'mercoledi',
      'mercoledì',
      'giovedi',
      'giovedì',
      'prima',
      'seconda',
      'terza',
      '1',
      '2',
      '3',
    };
    return _normalizeText(value)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length > 2)
        .where((token) => !ignored.contains(token))
        .toSet();
  }

  String _normalizedPlace(Gara gara) {
    final localita = _normalizeText(gara.localita);
    if (localita.isNotEmpty) return localita;
    return _normalizeText(gara.sitoGara);
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
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<Gara> _sortGareByDate(List<Gara> source) {
    return List<Gara>.from(source)
      ..sort((a, b) {
        final da = _parseDate(a.dataGara);
        final db = _parseDate(b.dataGara);
        if (da != null && db != null) {
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
        }
        return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
      });
  }

  int _compareCalendarEntries(_CalendarEntry a, _CalendarEntry b) {
    final da = a.startDate;
    final db = b.startDate;
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da != null && db == null) {
      return -1;
    } else if (da == null && db != null) {
      return 1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  Future<void> _toggleDisponibilita(Gara gara, bool join) async {
    final userId = _loggedUserId;
    if (userId == null) return;

    setState(() {
      updatingGare.add(gara.id);
    });

    List<String> ids;
    try {
      ids = await notion.fetchKronosDesignatiIds(gara.id);
    } catch (_) {
      ids = List<String>.from(gara.kronosIds);
    }

    if (join) {
      if (!ids.contains(userId)) ids.add(userId);
    } else {
      ids.removeWhere((id) => id == userId);
    }

    try {
      String currentDisponibilitaViaApp = '';
      try {
        currentDisponibilitaViaApp =
            await notion.fetchDisponibilitaViaAppText(gara.id);
      } catch (_) {
        currentDisponibilitaViaApp = '';
      }

      final disponibilitaViaApp = _mergeDisponibilitaViaApp(
        currentValue: currentDisponibilitaViaApp,
        currentUserName: _loggedUserName(),
        join: join,
      );
      await notion.updateKronosDesignati(
        gara.id,
        ids,
        disponibilitaViaApp: disponibilitaViaApp,
      );
      AdminNotificationResult? notificationResult;
      String? notificationError;
      try {
        notificationResult = await notion.notifyAdminsAvailability(
          garaId: gara.id,
          garaTitolo: gara.titolo,
          userId: userId,
          userName: _loggedUserName(),
          available: join,
        );
      } catch (e) {
        // Non blocchiamo il flusso disponibilita se la push fallisce.
        notificationError = e.toString();
        print('Notifica admin fallita: $e');
      }
      await load();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _availabilitySnackText(
              garaTitle: gara.titolo,
              joined: join,
              notificationResult: notificationResult,
              notificationError: notificationError,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingGare.remove(gara.id);
        });
      }
    }
  }

  String _availabilitySnackText({
    required String garaTitle,
    required bool joined,
    required AdminNotificationResult? notificationResult,
    required String? notificationError,
  }) {
    final action = joined
        ? 'Ti sei reso disponibile per $garaTitle'
        : 'Hai annullato la disponibilita per $garaTitle';

    if (notificationResult != null) {
      if (notificationResult.sent > 0) {
        return '$action. Notifiche inviate agli admin: ${notificationResult.sent}.';
      }
      if (notificationResult.reason.isNotEmpty) {
        return '$action. Nessun admin notificato: ${notificationResult.reason}.';
      }
      if (notificationResult.errors.isNotEmpty) {
        return '$action. Notifica admin non consegnata: ${notificationResult.errors.first}.';
      }
      return '$action. Nessun admin notificato.';
    }

    if (notificationError != null && notificationError.isNotEmpty) {
      return '$action. Notifica admin fallita: $notificationError';
    }

    return action;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(gare);
    final grouped = _garePerMese(filtered);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario gare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna calendario',
            onPressed: loading ? null : () => load(showSpinner: true),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Calendario',
              HelpContent.calendario,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Home'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: loading
            ? _buildLoadingState()
            : RefreshIndicator(
                onRefresh: () => load(showSpinner: false),
                child: grouped.isEmpty
                    ? _buildEmptyState(filtersEnabled: true)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        children: [
                          _buildCalendarHeader(filtered.length),
                          const SizedBox(height: 10),
                          _buildFiltersCard(),
                          const SizedBox(height: 10),
                          ...grouped.entries.map(_buildMonthSection),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: const Center(
            child: StopwatchLoading(label: 'Caricamento calendario gare...'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({bool filtersEnabled = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (filtersEnabled) ...[
          _buildCalendarHeader(0),
          const SizedBox(height: 10),
          _buildFiltersCard(),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 44, color: Colors.blueGrey.shade300),
              const SizedBox(height: 10),
              const Text(
                'Nessuna gara disponibile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                ' ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => load(showSpinner: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    final sports = _sportsOptions();
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterGroup(
                label: 'Anno',
                child: Wrap(
                  spacing: 6,
                  children: _databaseByYear.keys
                      .toList()
                      .reversed
                      .map(
                        (year) => _buildFilterChip(
                          label: year == DateTime.now().year
                              ? '$year'
                              : '$year archivio',
                          selected: selectedYear == year,
                          onSelected: (_) => _changeYear(year),
                        ),
                      )
                      .toList(),
                ),
              ),
              _filterGroup(
                label: 'Vista',
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildFilterChip(
                      label: 'Prossime',
                      selected: calendarPeriod == _CalendarPeriod.upcoming,
                      onSelected: (_) => setState(() {
                        calendarPeriod = _CalendarPeriod.upcoming;
                        expandedMonths = _defaultExpandedMonths(gare);
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Passate',
                      selected: calendarPeriod == _CalendarPeriod.past,
                      onSelected: (_) => setState(() {
                        calendarPeriod = _CalendarPeriod.past;
                        expandedMonths = _defaultExpandedMonths(gare);
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Filtri',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Tutte le gare',
                selected: assignmentFilter == _AssignmentFilter.all,
                onSelected: (_) =>
                    setState(() => assignmentFilter = _AssignmentFilter.all),
              ),
              _buildFilterChip(
                label: 'Gare dove ho dato disponibilità',
                selected: assignmentFilter == _AssignmentFilter.disponibilita,
                onSelected: (_) => setState(
                  () => assignmentFilter = _AssignmentFilter.disponibilita,
                ),
              ),
              _buildFilterChip(
                label: 'Gare dove sono designato',
                selected: assignmentFilter == _AssignmentFilter.designato,
                onSelected: (_) => setState(
                    () => assignmentFilter = _AssignmentFilter.designato),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: sportFilter.isEmpty ? '' : sportFilter,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Tutti gli sport'),
                    ),
                    ...sports.map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => sportFilter = value ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Sport',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  sportFilter = '';
                  assignmentFilter = _AssignmentFilter.all;
                }),
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Pulisci'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(int visibleCount) {
    final isCurrentYear = selectedYear == DateTime.now().year;
    final periodLabel =
        calendarPeriod == _CalendarPeriod.upcoming ? 'prossime' : 'passate';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004E9A), Color(0xFF0A66C2), Color(0xFF338FE5)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220A66C2),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentYear
                      ? 'Calendario $selectedYear'
                      : 'Archivio $selectedYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$visibleCount gare $periodLabel visibili',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Aggiorna calendario',
            onPressed: loading ? null : () => load(showSpinner: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _filterGroup({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF49627E),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF0A66C2).withOpacity(0.18),
      backgroundColor: const Color(0xFFF4F8FF),
      side: BorderSide(
        color: selected ? const Color(0xFF0A66C2) : const Color(0xFFDCE8F6),
      ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0A66C2) : const Color(0xFF27415F),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildMonthSection(MapEntry<String, List<_CalendarEntry>> entry) {
    final isExpanded = expandedMonths.contains(entry.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(entry.key),
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${entry.value.length}',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          onExpansionChanged: (open) {
            setState(() {
              if (open) {
                expandedMonths.add(entry.key);
              } else {
                expandedMonths.remove(entry.key);
              }
            });
          },
          children: entry.value
              .map((calendarEntry) => Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: _buildCalendarEntryCard(calendarEntry),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCalendarEntryCard(_CalendarEntry entry) {
    if (entry.isPackage) return _buildPackageCard(entry);
    return _buildRaceCard(entry.gare.first);
  }

  Widget _buildPackageCard(_CalendarEntry entry) {
    final gare = entry.gare;
    final main = gare.first;
    final packageLabel = entry.suggested ? 'Gara in più giorni' : 'Pacchetto';
    final packageColor =
        entry.suggested ? const Color(0xFF9D6400) : const Color(0xFF1F5FA8);
    final packageSoft =
        entry.suggested ? const Color(0xFFFFF3DE) : const Color(0xFFE4F0FF);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(
          color: entry.suggested
              ? const Color(0xFFF1D6A8)
              : const Color(0xFFCFE2FA),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0A66C2),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FCFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCE8F6)),
                  ),
                  child: _dateBadge(main),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: packageSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              packageLabel,
                              style: TextStyle(
                                color: packageColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!entry.suggested &&
                              (entry.packageId ?? '').isNotEmpty)
                            _metaPill(Icons.tag, entry.packageId!),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _metaPill(
                              Icons.date_range, _formatEntryDateRange(entry)),
                          _metaPill(
                            Icons.view_day_outlined,
                            '${gare.length} giornate',
                          ),
                          if (main.sport.isNotEmpty)
                            _metaPill(Icons.sports, main.sport),
                          if (main.localita.isNotEmpty)
                            _metaPill(Icons.place, main.localita),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: gare
                  .map(
                    (gara) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPackageDayRow(gara),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageDayRow(Gara gara) {
    return Material(
      color: const Color(0xFFF7FBFF),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DettaglioGara(gara: gara),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  _fmtDate(gara.dataGara) ?? '-',
                  style: const TextStyle(
                    color: Color(0xFF27415F),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gara.titolo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(gara.status),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF6D7E91),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRaceCard(Gara g) {
    final showAction = _loggedUserId != null;
    final candidabile = _puoCandidarsi(g);
    final assigned = _isUserAssigned(g);
    final designato = _isDesignato(g);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DettaglioGara(gara: g),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF9FCFF),
            border: Border.all(color: const Color(0xFFD9E8FA)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCE8F6)),
                  ),
                  child: _dateBadge(g),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              g.titolo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusChip(g.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _metaPill(Icons.event, _formatDateRange(g)),
                          if (g.sport.isNotEmpty)
                            _metaPill(Icons.sports, g.sport),
                          if (g.localita.isNotEmpty)
                            _metaPill(Icons.place, g.localita),
                        ],
                      ),
                      if (assigned || designato) ...[
                        const SizedBox(height: 9),
                        _involvementChip(
                          designato ? 'Sei designato' : 'Disponibilità data',
                          designato
                              ? Icons.verified_user_outlined
                              : Icons.person_pin_circle_outlined,
                        ),
                      ],
                      if (showAction && candidabile) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: updatingGare.contains(g.id)
                              ? null
                              : () => _toggleDisponibilita(g, !assigned),
                          icon: updatingGare.contains(g.id)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(assigned
                                  ? Icons.person_remove_alt_1
                                  : Icons.person_add_alt_1),
                          label: Text(assigned
                              ? 'Rimuovimi dalla gara'
                              : 'Mi rendo disponibile'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0A66C2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBadge(Gara gara) {
    final date = _parseDate(gara.dataGara);
    if (date == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, color: Color(0xFF6D7E91)),
          SizedBox(height: 4),
          Text(
            'N/D',
            style: TextStyle(
              color: Color(0xFF27415F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    final day = DateFormat('dd').format(date);
    const shortMonths = [
      'GEN',
      'FEB',
      'MAR',
      'APR',
      'MAG',
      'GIU',
      'LUG',
      'AGO',
      'SET',
      'OTT',
      'NOV',
      'DIC',
    ];
    final month = shortMonths[date.month - 1];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day,
          style: const TextStyle(
            color: Color(0xFF0A66C2),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          month,
          style: const TextStyle(
            color: Color(0xFF49627E),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _metaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF306AA3)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF27415F),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _involvementChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1D7C4B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1D7C4B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _meseAnno(DateTime date) {
    const mesi = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    final nome = mesi[date.month - 1];
    return '$nome ${date.year}';
  }

  DateTime? _parseDate(String value) => DateTime.tryParse(value);

  String _formatDateRange(Gara gara) {
    final start = _fmtDate(gara.dataGara);
    final end =
        gara.dataGaraFine.isNotEmpty ? _fmtDate(gara.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start - $end';
    return start ?? end ?? '-';
  }

  String _formatEntryDateRange(_CalendarEntry entry) {
    final start = entry.startDate;
    final end = entry.endDate ?? start;
    if (start == null && end == null) return '-';
    final formattedStart =
        start == null ? null : DateFormat('dd/MM/yyyy').format(start);
    final formattedEnd =
        end == null ? null : DateFormat('dd/MM/yyyy').format(end);
    if (formattedStart != null &&
        formattedEnd != null &&
        formattedStart != formattedEnd) {
      return '$formattedStart - $formattedEnd';
    }
    return formattedStart ?? formattedEnd ?? '-';
  }

  String? _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  _StatusStyle _statusStyle(String status) {
    final upper = status.trim().toUpperCase();
    if (upper == 'DESIGNAZIONE INVIATA') {
      return const _StatusStyle(
        soft: Color(0xFFE4F0FF),
        strong: Color(0xFF1F5FA8),
        accent: Color(0xFF2D83D6),
      );
    }
    if (upper == 'GARA COMPLETATA' || upper == 'SICWIN OK') {
      return const _StatusStyle(
        soft: Color(0xFFE8F7EF),
        strong: Color(0xFF1D7C4B),
        accent: Color(0xFF2EA568),
      );
    }
    if (upper == 'IN PROGRESS') {
      return const _StatusStyle(
        soft: Color(0xFFFFF3DE),
        strong: Color(0xFF9D6400),
        accent: Color(0xFFE2A53C),
      );
    }
    return const _StatusStyle(
      soft: Color(0xFFEDEFF3),
      strong: Color(0xFF515A68),
      accent: Color(0xFF8B95A5),
    );
  }

  Widget _statusChip(String status) {
    final style = _statusStyle(status);
    final text = status.trim().isEmpty ? 'N/D' : Gara.statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: style.strong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color soft;
  final Color strong;
  final Color accent;

  const _StatusStyle({
    required this.soft,
    required this.strong,
    required this.accent,
  });
}

class _CalendarEntry {
  final List<Gara> gare;
  final String? packageId;
  final bool suggested;

  _CalendarEntry._({
    required this.gare,
    required this.packageId,
    required this.suggested,
  });

  factory _CalendarEntry.single(Gara gara) {
    return _CalendarEntry._(
      gare: [gara],
      packageId: null,
      suggested: false,
    );
  }

  factory _CalendarEntry.package({
    required List<Gara> gare,
    String? packageId,
    required bool suggested,
  }) {
    return _CalendarEntry._(
      gare: gare,
      packageId: packageId,
      suggested: suggested,
    );
  }

  bool get isPackage => gare.length > 1;

  DateTime? get startDate {
    for (final gara in gare) {
      final date = DateTime.tryParse(gara.dataGara);
      if (date != null) return date;
    }
    return null;
  }

  DateTime? get endDate {
    for (final gara in gare.reversed) {
      final end = DateTime.tryParse(gara.dataGaraFine);
      if (end != null) return end;
      final start = DateTime.tryParse(gara.dataGara);
      if (start != null) return start;
    }
    return null;
  }

  String get title {
    if (gare.isEmpty) return 'Pacchetto gare';
    if (gare.length == 1) return gare.first.titolo;

    final cleaned = gare
        .map((gara) => _cleanTitle(gara.titolo))
        .where((title) => title.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return gare.first.titolo;

    final firstTokens = cleaned.first.split(' ');
    var commonLength = firstTokens.length;
    for (final title in cleaned.skip(1)) {
      final tokens = title.split(' ');
      var i = 0;
      while (i < commonLength &&
          i < tokens.length &&
          firstTokens[i] == tokens[i]) {
        i++;
      }
      commonLength = i;
    }

    if (commonLength >= 2) {
      return firstTokens.take(commonLength).join(' ');
    }
    return cleaned.first;
  }

  static String _cleanTitle(String value) {
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
    title = title.replaceAll(RegExp(r'\s+[-–—]\s*$'), '');
    return title.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

enum _AssignmentFilter {
  all,
  disponibilita,
  designato,
}

enum _CalendarPeriod {
  upcoming,
  past,
}
