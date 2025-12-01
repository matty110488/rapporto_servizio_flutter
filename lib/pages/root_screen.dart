import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../pdf/generatore_pdf2.dart';
import '../services/notion_service.dart';
import '../widgets/allegati_form.dart';
import '../widgets/apparecchiatura_form.dart';
import '../widgets/cronometristi_form.dart';
import '../widgets/danni_form.dart';
import '../widgets/gara_form.dart';
import '../widgets/header.dart';
import '../widgets/help_dialog.dart';

class RootScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const RootScreen({super.key, required this.loggedUser});

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
  List<Gara> gareDisponibili = [];
  bool loadingGareList = true;
  String? gareError;
  Gara? selectedGara;
  int formVersion = 0;
  bool prefilling = false;
  int _prefillTicket = 0;

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
      nextSelection ??= gareValide.length == 1 ? gareValide.first : null;
      final selectionChanged = (previousId ?? '') != (nextSelection?.id ?? '');

      if (!mounted) return;
      setState(() {
        gareDisponibili = gareValide;
        loadingGareList = false;
        selectedGara = nextSelection;
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
    } catch (e) {
      if (!mounted || ticket != _prefillTicket) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel precompilare la gara: $e')),
      );
    } finally {
      if (!mounted || ticket != _prefillTicket) return;
      setState(() {
        prefilling = false;
      });
    }
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Expanded(child: Text("Carico le gare disponibili...")),
            ],
          ),
        ),
      );
    }

    if (gareError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Impossibile recuperare le gare",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(gareError!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadGareDsc,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (gareDisponibili.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _isAdmin
                ? "Rapportini completati per tutte le gare."
                : "Non risultano gare in cui risulti DSC.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Seleziona la gara per cui vuoi compilare il rapportino",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGara?.id,
              items: gareDisponibili
                  .map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(_garaDisplayLabel(g)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final gara = gareDisponibili.firstWhere((g) => g.id == value,
                    orElse: () {
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
      ),
    );
  }

  Widget _buildSelectedGaraInfo() {
    final gara = selectedGara;
    if (gara == null) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available),
        title: Text(gara.titolo),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: ${_garaDateRange(gara)}"),
            Text("Luogo: ${gara.localita.isEmpty ? '-' : gara.localita}"),
            if (gara.organizzatore.isNotEmpty)
              Text("Organizzatore: ${gara.organizzatore}"),
            if (gara.sport.isNotEmpty) Text("Sport: ${gara.sport}"),
          ],
        ),
      ),
    );
  }

  Widget _buildRapportoForm() {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: titleStyle),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderWidget(),
            const SizedBox(height: 16),
            sectionTitle('Dati gara'),
            GaraForm(
              key: garaKey,
              onDateRangeChanged: (da, a) {
                cronometristiKey.currentState?.syncDaysWithRange(da, a);
              },
              onOrariChanged: (orari) {
                cronometristiKey.currentState?.setOrari(orari);
              },
            ),
            const SizedBox(height: 16),
            sectionTitle('==============================='),
            CronometristiForm(key: cronometristiKey),
            const SizedBox(height: 16),
            sectionTitle('==============================='),
            ApparecchiaturaForm(key: apparecchiaturaKey),
            const SizedBox(height: 16),
            sectionTitle('==============================='),
            DanniForm(key: danniKey),
            const SizedBox(height: 16),
            sectionTitle('==============================='),
            AllegatiForm(key: allegatiKey),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
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

                  final file = await generaPdfConDati({
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
                  }, salvaLocalmente: true);
                  await Share.shareXFiles([XFile(file.path)],
                      text: 'Rapporto PDF');
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Genera e invia PDF"),
              ),
            ),
          ],
        ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGareSelectionCard(),
              const SizedBox(height: 16),
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
    );
  }
}
