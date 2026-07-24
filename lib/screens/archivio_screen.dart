import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/notion_user.dart';
import '../widgets/standard_app_bar_actions.dart';

class ArchivioScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const ArchivioScreen({super.key, required this.loggedUser});

  @override
  State<ArchivioScreen> createState() => _ArchivioScreenState();
}

class _ArchivioScreenState extends State<ArchivioScreen> {
  late NotionService notion;
  List<_ArchivedRaceReport> rapportini = [];
  bool loading = true;
  String? errore;
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    selectedYear = AppConfig.currentRaceYear;
    notion = NotionService(
      databaseId: AppConfig.raceDatabaseIds[selectedYear]!,
    );
    _caricaArchivio();
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool get _isAdmin => isNotionAdmin(widget.loggedUser);

  String _normalizedId(String value) =>
      value.replaceAll('-', '').trim().toLowerCase();

  Future<void> _caricaArchivio({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      errore = null;
    });

    try {
      if (forceRefresh) {
        NotionService.invalidateRaceDatabaseCache();
      }
      final results = await notion.fetchReportArchive();
      final all = results
          .map(
            (page) => _ArchivedRaceReport(
              gara: Gara.fromNotion(page),
              files: _reportFiles(page),
            ),
          )
          .where((entry) => entry.files.isNotEmpty)
          .toList();

      final userId = _loggedUserId;

      final filtered = all.where((entry) {
        if (_isAdmin) return true;
        if (userId == null) return false;
        final normalizedUserId = _normalizedId(userId);
        return entry.gara.dscIds.map(_normalizedId).contains(normalizedUserId);
      }).toList();

      filtered.sort((a, b) {
        final da = DateTime.tryParse(a.gara.dataGara);
        final db = DateTime.tryParse(b.gara.dataGara);
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.gara.titolo
            .toLowerCase()
            .compareTo(b.gara.titolo.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        rapportini = filtered;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errore = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _changeYear(int year) async {
    if (year == selectedYear) return;
    setState(() {
      selectedYear = year;
      loading = true;
      errore = null;
    });
    notion = NotionService(databaseId: AppConfig.raceDatabaseIds[year]!);
    await _caricaArchivio();
  }

  String _fmtDateRange(Gara g) {
    String fmt(String iso) {
      return formatItalianIsoDateOrValue(iso);
    }

    final start = fmt(g.dataGara);
    final end = g.dataGaraFine.isNotEmpty ? fmt(g.dataGaraFine) : start;
    return start == end ? start : '$start - $end';
  }

  List<_NotionReportFile> _reportFiles(Map<String, dynamic> page) {
    final properties = page['properties'];
    if (properties is! Map<String, dynamic>) return const [];
    Map<String, dynamic>? field;
    for (final entry in properties.entries) {
      if (entry.key.trim().toLowerCase() ==
              NotionRaceProperties.files.toLowerCase() &&
          entry.value is Map<String, dynamic>) {
        field = entry.value as Map<String, dynamic>;
        break;
      }
    }
    final rawFiles = field?['files'];
    if (rawFiles is! List) return const [];
    return rawFiles
        .whereType<Map<String, dynamic>>()
        .map(_NotionReportFile.fromNotion)
        .where((file) => file.url.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _apriRapportino(_NotionReportFile file) async {
    final uri = Uri.tryParse(file.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non riesco ad aprire il rapportino da Notion.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivio rapportini inviati'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Scegli anno',
            initialValue: selectedYear,
            onSelected: _changeYear,
            itemBuilder: (context) => AppConfig.configuredRaceYears.reversed
                .map(
                  (year) => PopupMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  selectedYear.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          ...standardAppBarActions(
            context,
            helpTitle: 'Archivio',
            helpContent: HelpContent.archivio,
            onRefresh: () => _caricaArchivio(forceRefresh: true),
            refreshEnabled: !loading,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errore != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Errore nel caricamento: $errore'),
                  ),
                )
              : rapportini.isEmpty
                  ? const Center(
                      child: Text('Nessun rapportino inviato in archivio.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rapportini.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final archived = rapportini[index];
                        final gara = archived.gara;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE8F6)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gara.titolo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Data: ${_fmtDateRange(gara)}'),
                                if (gara.localita.isNotEmpty)
                                  Text('Luogo: ${gara.localita}'),
                                if (gara.sport.isNotEmpty)
                                  Text('Sport: ${gara.sport}'),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: archived.files
                                      .map(
                                        (file) => FilledButton.icon(
                                          onPressed: () =>
                                              _apriRapportino(file),
                                          icon: const Icon(
                                            Icons.picture_as_pdf_rounded,
                                          ),
                                          label: Text(
                                            archived.files.length == 1
                                                ? 'Apri rapportino'
                                                : file.name,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ArchivedRaceReport {
  const _ArchivedRaceReport({required this.gara, required this.files});

  final Gara gara;
  final List<_NotionReportFile> files;
}

class _NotionReportFile {
  const _NotionReportFile({required this.name, required this.url});

  final String name;
  final String url;

  factory _NotionReportFile.fromNotion(Map<String, dynamic> json) {
    final file = json['file'];
    final external = json['external'];
    final url = file is Map
        ? file['url']
        : external is Map
            ? external['url']
            : null;
    return _NotionReportFile(
      name: json['name'] is String ? json['name'] as String : 'Rapportino PDF',
      url: url is String ? url : '',
    );
  }
}
