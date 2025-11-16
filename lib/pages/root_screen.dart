import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gara.dart';
import '../pdf/generatore_pdf2.dart';
import '../services/notion_service.dart';
import '../widgets/allegati_form.dart';
import '../widgets/apparecchiatura_form.dart';
import '../widgets/cronometristi_form.dart';
import '../widgets/danni_form.dart';
import '../widgets/gara_form.dart';
import '../widgets/header.dart';

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

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      apiKey: "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",
      databaseId: "2acde089ef958065aa24fce00357a425",
    );
    _loadGareDsc();
  }

  Future<void> _loadGareDsc() async {
    setState(() {
      loadingGareList = true;
      gareError = null;
    });
    try {
      final results = await notion.fetchGare();
      final allGare =
          results.map((e) => Gara.fromNotion(e)).toList(growable: false);
      final userId = _loggedUserId;
      final filtered = userId == null
          ? <Gara>[]
          : allGare.where((g) => g.dscIds.contains(userId)).toList();

      final previousId = selectedGara?.id;
      Gara? nextSelection;
      if (previousId != null) {
        for (final gara in filtered) {
          if (gara.id == previousId) {
            nextSelection = gara;
            break;
          }
        }
      }
      nextSelection ??= filtered.length == 1 ? filtered.first : null;
      final selectionChanged = (previousId ?? '') != (nextSelection?.id ?? '');

      if (!mounted) return;
      setState(() {
        gareDisponibili = filtered;
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
    final dateLabel = (end != start) ? "$start �+' $end" : start;
    final luogo = gara.localita.isEmpty ? '-' : gara.localita;
    return "$dateLabel A� ${gara.titolo} A� $luogo";
  }

  String _garaDateRange(Gara gara) {
    final start = _formatDateLabel(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty
        ? _formatDateLabel(gara.dataGaraFine)
        : start;
    return end != start ? "$start �+' $end" : start;
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
              Expanded(child: Text("Carico le gare in cui sei DSC...")),
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
            "Non risultano gare in cui risulti DSC. Contatta la segreteria per abilitare il rapportino.",
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderWidget(),
        SizedBox(height: 24),
        GaraForm(
          key: garaKey,
          onDateRangeChanged: (da, a) {
            cronometristiKey.currentState?.syncDaysWithRange(da, a);
          },
        ),
        SizedBox(height: 24),
        CronometristiForm(key: cronometristiKey),
        SizedBox(height: 24),
        ApparecchiaturaForm(key: apparecchiaturaKey),
        SizedBox(height: 24),
        DanniForm(key: danniKey),
        AllegatiForm(key: allegatiKey),
        SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            final garaSelezionata = selectedGara;
            if (garaSelezionata == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Seleziona prima una gara in cui sei DSC'),
                ),
              );
              return;
            }

            final gara = garaKey.currentState?.getData() ?? {};
            final cronos = cronometristiKey.currentState?.getData() ?? [];
            final app = apparecchiaturaKey.currentState?.getData() ?? [];
            final danni = danniKey.currentState?.getData() ?? '';
            final immagini = allegatiKey.currentState?.getImages() ?? [];

            final file = await generaPdfConDati({
              'gara': gara,
              'cronometristi': cronos,
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
            await Share.shareXFiles([XFile(file.path)], text: 'Rapporto PDF');
          },
          icon: Icon(Icons.picture_as_pdf),
          label: Text("Genera e invia PDF"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFillForm = selectedGara != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crono Valtellinesi'),
        actions: [
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
