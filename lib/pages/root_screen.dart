import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../pdf/generatore_pdf2.dart';
import '../services/notion_service.dart';
import '../services/rapportino_draft_service.dart';
import '../widgets/allegati_form.dart';
import '../widgets/apparecchiatura_form.dart';
import '../widgets/cronometristi_form.dart';
import '../widgets/danni_form.dart';
import '../widgets/gara_form.dart';
import '../widgets/header.dart';
import '../widgets/help_dialog.dart';

class RootScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final String? initialGaraId;

  const RootScreen({
    super.key,
    required this.loggedUser,
    this.initialGaraId,
  });

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final garaKey = GlobalKey<GaraFormState>();
  final cronometristiKey = GlobalKey<CronometristiFormState>();
  final apparecchiaturaKey = GlobalKey<ApparecchiaturaFormState>();
  final danniKey = GlobalKey<DanniFormState>();
  final allegatiKey = GlobalKey<AllegatiFormState>();
  static const _db2025 = "2afde089ef9580e2b0e7d19d44f3a3f6";
  static const _db2026 = "2b1de089ef9580729622ff9543046cbc";

  late NotionService notion;
  final RapportinoDraftService _draftService = RapportinoDraftService();
  List<Gara> gareDisponibili = [];
  bool loadingGareList = true;
  String? gareError;
  Gara? selectedGara;
  String selectedSport = '';
  int formVersion = 0;
  bool prefilling = false;
  int _prefillTicket = 0;

  bool _containsFisKeyword(String value) {
    final sport = value.trim();
    if (sport.isEmpty) return false;
    return RegExp(r'\b(FISI|FIS)\b', caseSensitive: false).hasMatch(sport);
  }

  bool get _isFisSport {
    return _containsFisKeyword(selectedSport);
  }

  String get _tipoGaraLabel {
    final sport = selectedSport.trim();
    if (sport.isNotEmpty) return sport;
    return 'N/D';
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool get _isAdmin {
    final props = widget.loggedUser['properties'];
    if (props is! Map<String, dynamic>) return false;

    const adminKeys = [
      'ADMIN',
      'Admin',
      'admin',
      'RUOLO',
      'Ruolo',
      'ROLE',
      'Role',
      'role',
    ];

    bool matchAdminText(String? value) {
      if (value == null) return false;
      final lower = value.toLowerCase();
      return lower == 'admin' || lower == 'amministratore';
    }

    bool hasAdminValue(Map<String, dynamic> field) {
      if (field['checkbox'] == true) return true;

      final select = field['select'];
      if (select is Map<String, dynamic>) {
        final name = select['name'];
        if (name is String && matchAdminText(name)) return true;
      }

      final multi = field['multi_select'];
      if (multi is List) {
        for (final entry in multi) {
          if (entry is Map<String, dynamic>) {
            final name = entry['name'];
            if (name is String && matchAdminText(name)) {
              return true;
            }
          }
        }
      }

      final rich = field['rich_text'];
      if (rich is List && rich.isNotEmpty) {
        final first = rich.first;
        if (first is Map<String, dynamic>) {
          final text = first['plain_text'];
          if (text is String && matchAdminText(text)) {
            return true;
          }
        }
      }

      return false;
    }

    for (final key in adminKeys) {
      final value = props[key];
      if (value is Map<String, dynamic> && hasAdminValue(value)) {
        return true;
      }
    }
    return false;
  }

  bool _isStatusAbilitato(Gara gara) {
    const allowed = {
      'DESIGNAZIONE INVIATA',
      'GARA COMPLETATA',
      'RAPPORTINO RICEVUTO',
    };
    final status = gara.status.trim().toUpperCase();
    return allowed.contains(status);
  }

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      apiKey: "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",
      databaseId: _db2025,
    );
    _loadGareDsc();
  }

  Future<void> _loadGareDsc() async {
    setState(() {
      loadingGareList = true;
      gareError = null;
    });
    try {
      final results = await notion.fetchGare(
        additionalDatabaseIds: const [_db2026],
      );
      final allGare =
          results.map((e) => Gara.fromNotion(e)).toList(growable: false);
      final userId = _loggedUserId;
      final filtered = _isAdmin
          ? allGare
          : userId == null
              ? <Gara>[]
              : allGare.where((g) => g.dscIds.contains(userId)).toList();
      final gareValide = filtered.where(_isStatusAbilitato).toList();

      final previousId = selectedGara?.id;
      Gara? nextSelection;
      if (previousId != null) {
        for (final gara in gareValide) {
          if (gara.id == previousId) {
            nextSelection = gara;
            break;
          }
        }
      }
      if (nextSelection == null && widget.initialGaraId != null) {
        for (final gara in gareValide) {
          if (gara.id == widget.initialGaraId) {
            nextSelection = gara;
            break;
          }
        }
      }
      nextSelection ??= gareValide.length == 1 ? gareValide.first : null;
      final selectionChanged = (previousId ?? '') != (nextSelection?.id ?? '');

      if (!mounted) return;
      setState(() {
        gareDisponibili = gareValide;
        loadingGareList = false;
        selectedGara = nextSelection;
        selectedSport = nextSelection?.sport ?? '';
        if (selectionChanged) {
          formVersion++;
        }
      });
      if (nextSelection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _prefillFromSelectedGara();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        gareError = e.toString();
        loadingGareList = false;
      });
    }
  }

  void _selectGara(Gara gara) {
    setState(() {
      selectedGara = gara;
      selectedSport = gara.sport;
      formVersion++;
    });
    _prefillFromSelectedGara();
  }

  Future<String?> _resolveName(String id) async {
    try {
      final name = await notion.fetchNameFromPage(id);
      if (name.isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _resolveNames(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = await Future.wait(ids.map(_resolveName));
    return results.whereType<String>().toList();
  }

  Future<void> _prefillFromSelectedGara() async {
    final gara = selectedGara;
    if (gara == null) return;
    final ticket = ++_prefillTicket;
    setState(() {
      prefilling = true;
    });
    try {
      String? dscName;
      if (gara.dscIds.isNotEmpty) {
        dscName = await _resolveName(gara.dscIds.first);
      }
      final kronosNames = await _resolveNames(gara.kronosIds);

      if (!mounted || ticket != _prefillTicket) return;
      garaKey.currentState?.applyNotionData(
        nome: gara.titolo,
        organizzatore: gara.organizzatore,
        sportValue: gara.sport,
        luogo: gara.localita,
        dataInizio: gara.dataGara,
        dataFine:
            gara.dataGaraFine.isNotEmpty ? gara.dataGaraFine : gara.dataGara,
        dsc: dscName,
      );
      await Future<void>.microtask(() {});
      if (!mounted || ticket != _prefillTicket) return;
      cronometristiKey.currentState?.setCronometristi(kronosNames);
      setState(() {
        selectedSport = gara.sport;
      });
      await _applySavedDraftIfAny(gara.id);
    } catch (e) {
      if (!mounted || ticket != _prefillTicket) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel precompilare la gara: $e')),
      );
    } finally {
      if (mounted && ticket == _prefillTicket) {
        setState(() {
          prefilling = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildRapportinoPayload({
    required Gara garaSelezionata,
    required Map<String, dynamic> gara,
    required List<dynamic> cronos,
    required Map<String, dynamic> orariGiornata,
    required List<dynamic> app,
    required String danni,
    required List<dynamic> immagini,
  }) {
    return {
      'gara': gara,
      'cronometristi': cronos,
      'orariGiornata': orariGiornata,
      'apparecchiature': app,
      'danni': danni,
      'allegati': immagini,
      'garaSelezionata': {
        'id': garaSelezionata.id,
        'titolo': garaSelezionata.titolo,
        'data': garaSelezionata.dataGara,
        'dataFine': garaSelezionata.dataGaraFine,
        'luogo': garaSelezionata.localita,
      },
    };
  }

  Future<void> _saveDraft({
    required String garaId,
    required Map<String, dynamic> payload,
  }) async {
    final draft = {
      'gara': payload['gara'],
      'cronometristi': payload['cronometristi'],
      'orariGiornata': payload['orariGiornata'],
      'apparecchiature': payload['apparecchiature'],
      'danni': payload['danni'],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _draftService.saveDraft(garaId, draft);
  }

  Future<void> _applySavedDraftIfAny(String garaId) async {
    final saved = await _draftService.loadDraft(garaId);
    if (saved == null) return;

    final garaDataRaw = saved['gara'];
    final cronosRaw = saved['cronometristi'];
    final orariRaw = saved['orariGiornata'];
    final appRaw = saved['apparecchiature'];
    final danniRaw = saved['danni'];

    final garaData = garaDataRaw is Map
        ? Map<String, dynamic>.from(garaDataRaw)
        : <String, dynamic>{};
    final cronos = cronosRaw is List ? List<dynamic>.from(cronosRaw) : <dynamic>[];
    final app = appRaw is List ? List<dynamic>.from(appRaw) : <dynamic>[];
    final orari = orariRaw is Map ? Map<String, dynamic>.from(orariRaw) : <String, dynamic>{};
    final danni = (danniRaw ?? '').toString();

    garaKey.currentState?.applySavedData(
      garaData: garaData,
      savedOrari: orari,
    );
    cronometristiKey.currentState?.applySavedData(cronos);
    apparecchiaturaKey.currentState?.applySavedData(app);
    danniKey.currentState?.setData(danni);
  }

  String _formatDateLabel(String value) {
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _garaDisplayLabel(Gara gara) {
    final start = _formatDateLabel(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty
        ? _formatDateLabel(gara.dataGaraFine)
        : start;
    final dateLabel = (end != start) ? "$start - $end" : start;
    final luogo = gara.localita.isEmpty ? '-' : gara.localita;
    return "$dateLabel - ${gara.titolo} - $luogo";
  }

  String _garaDateRange(Gara gara) {
    final start = _formatDateLabel(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty
        ? _formatDateLabel(gara.dataGaraFine)
        : start;
    return end != start ? "$start - $end" : start;
  }

  Widget _buildGareSelectionCard() {
    if (loadingGareList) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Expanded(child: Text("Carico le gare disponibili...")),
          ],
        ),
      );
    }

    if (gareError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(
          borderColor: const Color(0xFFFFD8D8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Impossibile recuperare le gare",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(gareError!),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loadGareDsc,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (gareDisponibili.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: Text(
          _isAdmin
              ? "Rapportini completati per tutte le gare."
              : "Non risultano gare in cui risulti DSC.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //const Text(
          //  "Seleziona la gara per cui vuoi compilare il rapportino",
          //  style: TextStyle(fontWeight: FontWeight.w700),
          //),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedGara?.id,
            items: gareDisponibili
                .map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(_garaDisplayLabel(g)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final gara =
                  gareDisponibili.firstWhere((g) => g.id == value, orElse: () {
                return gareDisponibili.first;
              });
              _selectGara(gara);
            },
            decoration: const InputDecoration(
              labelText: 'Gara',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            hint: const Text('Seleziona una gara'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedGaraInfo() {
    final gara = selectedGara;
    if (gara == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_available),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gara.titolo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("Date: ${_garaDateRange(gara)}"),
          Text("Luogo: ${gara.localita.isEmpty ? '-' : gara.localita}"),
          if (gara.organizzatore.isNotEmpty)
            Text("Organizzatore: ${gara.organizzatore}"),
          if (gara.sport.isNotEmpty) Text("Sport: ${gara.sport}"),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData icon = Icons.circle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0A66C2)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(
      {Color borderColor = const Color(0xFFDCE8F6)}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x11000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildRapportoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(),
          child: HeaderWidget(),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Dati gara',
          icon: Icons.sports_score,
          child: GaraForm(
            key: garaKey,
            onSportChanged: (sport) {
              setState(() {
                selectedSport = sport;
              });
            },
            onDateRangeChanged: (da, a) {
              cronometristiKey.currentState?.syncDaysWithRange(da, a);
            },
            onOrariChanged: (orari) {
              cronometristiKey.currentState?.setOrari(orari);
            },
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Cronometristi',
          icon: Icons.groups,
          child: CronometristiForm(key: cronometristiKey),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Apparecchiatura',
          icon: Icons.precision_manufacturing,
          child: ApparecchiaturaForm(
            key: apparecchiaturaKey,
            isFisSport: _isFisSport,
            tipoGara: _tipoGaraLabel,
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Danni',
          icon: Icons.report_problem,
          child: DanniForm(key: danniKey),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Allegati',
          icon: Icons.attach_file,
          child: AllegatiForm(key: allegatiKey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A66C2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final garaSelezionata = selectedGara;
              if (garaSelezionata == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seleziona prima una gara'),
                  ),
                );
                return;
              }

              final gara = garaKey.currentState?.getData() ?? {};
              final cronos = cronometristiKey.currentState?.getData() ?? [];
              final orariGiornata =
                  garaKey.currentState?.getOrariGiornata() ?? {};
              final app = apparecchiaturaKey.currentState?.getData() ?? [];
              final danni = danniKey.currentState?.getData() ?? '';
              final immagini = allegatiKey.currentState?.getImages() ?? [];
              final payload = _buildRapportinoPayload(
                garaSelezionata: garaSelezionata,
                gara: gara,
                cronos: cronos,
                orariGiornata: orariGiornata,
                app: app,
                danni: danni,
                immagini: immagini,
              );

              try {
                await _saveDraft(
                  garaId: garaSelezionata.id,
                  payload: payload,
                );
                if (kIsWeb) {
                  final pdfBytes = await generaPdfBytesConDati(payload);
                  await Printing.sharePdf(
                    bytes: pdfBytes,
                    filename: 'rapporto_servizio.pdf',
                  );
                } else {
                  final file = await generaPdfConDati(
                    payload,
                    salvaLocalmente: true,
                  );
                  await SharePlus.instance.share(
                    ShareParams(
                      text: 'Rapporto PDF',
                      files: [XFile(file.path)],
                    ),
                  );
                }
                await notion.updateGaraStatus(
                  garaSelezionata.id,
                  'RAPPORTINO RICEVUTO',
                );
                await _loadGareDsc();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Errore generazione PDF: $e')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Genera e invia PDF"),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
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
            color: Color(0x300A66C2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rapporti di servizio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Seleziona la gara e compila il rapportino in tutte le sezioni.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFillForm = selectedGara != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crono Valtellinesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Rapportini',
              HelpContent.rapportini,
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
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFFFFFFF)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 12),
                _buildGareSelectionCard(),
                const SizedBox(height: 12),
                _buildSelectedGaraInfo(),
                if (prefilling)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (!canFillForm &&
                    !loadingGareList &&
                    gareDisponibili.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Seleziona una gara per abilitare il rapportino.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                IgnorePointer(
                  ignoring: !canFillForm,
                  child: Opacity(
                    opacity: canFillForm ? 1 : 0.35,
                    child: KeyedSubtree(
                      key: ValueKey(formVersion),
                      child: _buildRapportoForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
