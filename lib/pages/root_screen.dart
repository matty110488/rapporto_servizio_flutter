import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/gara.dart';
import '../models/gara_package.dart';
import '../pdf/generatore_pdf2.dart';
import '../services/notion_service.dart';
import '../services/prank_popup_service.dart';
import '../services/rapportino_draft_service.dart';
import '../utils/italian_date_formatter.dart';
import '../widgets/allegati_form.dart';
import '../widgets/apparecchiatura_form.dart';
import '../widgets/cronometristi_form.dart';
import '../widgets/danni_form.dart';
import '../widgets/gara_form.dart';
import '../widgets/header.dart';
import '../widgets/standard_app_bar_actions.dart';
import '../widgets/stopwatch_loading.dart';

class RootScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final String? initialGaraId;
  final bool? initialWholePackage;
  final bool includeSentReports;
  final int? initialRaceYear;

  const RootScreen({
    super.key,
    required this.loggedUser,
    this.initialGaraId,
    this.initialWholePackage,
    this.includeSentReports = false,
    this.initialRaceYear,
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
  late NotionService notion;
  final RapportinoDraftService _draftService = RapportinoDraftService();
  List<Gara> gareDisponibili = [];
  List<GaraPackage> pacchettiDisponibili = [];
  bool loadingGareList = true;
  String? gareError;
  Gara? selectedGara;
  GaraPackage? selectedPackage;
  bool wholePackage = false;
  int formVersion = 0;
  bool prefilling = false;
  int _prefillTicket = 0;
  Timer? _autosaveTimer;
  bool _savingDraft = false;
  DateTime? _lastDraftSavedAt;
  String? _lastDraftFingerprint;
  bool _initialScopeApplied = false;
  bool _allowPop = false;

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
    final status = gara.status.trim().toUpperCase();
    return RaceStatuses.reportCompilationAllowed.contains(status) ||
        (widget.includeSentReports && status == RaceStatuses.reportReceived);
  }

  List<Gara> get _selectedReportGare {
    final package = selectedPackage;
    final gara = selectedGara;
    if (package != null && package.isPackage && wholePackage) {
      return package.gare;
    }
    return gara == null ? const [] : [gara];
  }

  GaraPackage? get _selectedReportPackage {
    final gare = _selectedReportGare;
    if (gare.isEmpty) return null;
    if (gare.length == 1) return GaraPackage.single(gare.first);
    return GaraPackage.group(
      gare: gare,
      packageId: selectedPackage?.packageId,
      suggested: selectedPackage?.suggested ?? true,
    );
  }

  String get _draftKey => wholePackage && selectedPackage?.isPackage == true
      ? selectedPackage!.stableKey
      : selectedGara?.id ?? '';

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      databaseId: AppConfig.raceDatabaseIds[widget.initialRaceYear] ??
          AppConfig.currentRaceDatabaseId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrankPopupService.maybeShow(context, widget.loggedUser);
    });
    _autosaveTimer = Timer.periodic(
      AppConfig.reportDraftAutosaveInterval,
      (_) => unawaited(_autosaveIfChanged()),
    );
    _loadGareDsc();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
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
      final filtered = _isAdmin
          ? allGare
          : userId == null
              ? <Gara>[]
              : allGare.where((g) => g.dscIds.contains(userId)).toList();
      final gareValide = filtered.where(_isStatusAbilitato).toList();

      final packages = buildGaraPackages(gareValide);
      final previousPackageKey = selectedPackage?.stableKey;
      final previousId = selectedGara?.id;
      GaraPackage? nextPackage;
      if (previousPackageKey != null) {
        for (final package in packages) {
          if (package.stableKey == previousPackageKey) {
            nextPackage = package;
            break;
          }
        }
      }
      final requestedId = previousId ?? widget.initialGaraId;
      if (nextPackage == null && requestedId != null) {
        for (final package in packages) {
          if (package.gare.any((gara) => gara.id == requestedId)) {
            nextPackage = package;
            break;
          }
        }
      }
      nextPackage ??= packages.length == 1 ? packages.first : null;
      Gara? nextSelection;
      if (nextPackage != null) {
        for (final gara in nextPackage.gare) {
          if (gara.id == previousId) {
            nextSelection = gara;
            break;
          }
        }
        nextSelection ??= nextPackage.primary;
      }
      final selectionChanged =
          (selectedPackage?.stableKey ?? '') != (nextPackage?.stableKey ?? '');

      if (!mounted) return;
      setState(() {
        gareDisponibili = gareValide;
        pacchettiDisponibili = packages;
        loadingGareList = false;
        selectedPackage = nextPackage;
        selectedGara = nextSelection;
        if (selectionChanged) {
          final initialScope =
              _initialScopeApplied ? null : widget.initialWholePackage;
          wholePackage =
              initialScope ?? nextPackage?.isConfirmedPackage ?? false;
          _initialScopeApplied = true;
          formVersion++;
        }
      });
      if (nextSelection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _prefillFromSelection();
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

  Future<void> _selectPackage(GaraPackage package) async {
    await _savePendingChangesIfAny();
    if (!mounted) return;
    setState(() {
      selectedPackage = package;
      selectedGara = package.primary;
      wholePackage = package.isConfirmedPackage;
      formVersion++;
    });
    _prefillFromSelection();
  }

  Future<void> _selectSingleGara(Gara gara) async {
    await _savePendingChangesIfAny();
    if (!mounted) return;
    setState(() {
      selectedGara = gara;
      wholePackage = false;
      formVersion++;
    });
    _prefillFromSelection();
  }

  Future<void> _selectWholePackage() async {
    final package = selectedPackage;
    if (package == null) return;
    await _savePendingChangesIfAny();
    if (!mounted) return;
    setState(() {
      wholePackage = true;
      selectedGara = package.primary;
      formVersion++;
    });
    _prefillFromSelection();
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

  Future<bool> _prefillFromSelection({bool applyDraft = true}) async {
    final package = _selectedReportPackage;
    if (package == null) return false;
    final gara = package.primary;
    final selectedGare = package.gare;
    final activeDates = package.activeDates;
    final ticket = ++_prefillTicket;
    setState(() {
      prefilling = true;
      _lastDraftSavedAt = null;
      _lastDraftFingerprint = null;
    });
    try {
      String? dscName;
      if (gara.dscIds.isNotEmpty) {
        dscName = await _resolveName(gara.dscIds.first);
      }
      final datesByKronosId = <String, Set<DateTime>>{};
      for (final selected in selectedGare) {
        final dates = GaraPackage.single(selected).activeDates;
        for (final id in selected.kronosIds) {
          datesByKronosId.putIfAbsent(id, () => <DateTime>{}).addAll(dates);
        }
      }
      final resolvedNames = await Future.wait(
        datesByKronosId.keys.map(
          (id) async => MapEntry(id, await _resolveName(id)),
        ),
      );
      final datesByName = <String, Set<DateTime>>{};
      for (final entry in resolvedNames) {
        final name = entry.value;
        if (name == null || name.isEmpty) continue;
        datesByName
            .putIfAbsent(name, () => <DateTime>{})
            .addAll(datesByKronosId[entry.key] ?? const {});
      }

      if (!mounted || ticket != _prefillTicket) return false;
      garaKey.currentState?.applyPackageData(
        nome: package.title,
        organizzatore: gara.organizzatore,
        sportValue: gara.sport,
        luogo: gara.localita,
        dates: activeDates,
        dsc: dscName,
      );
      await Future<void>.microtask(() {});
      if (!mounted || ticket != _prefillTicket) return false;
      cronometristiKey.currentState?.syncDaysWithDates(activeDates);
      cronometristiKey.currentState?.setCronometristiPerDate(
        datesByName.map(
          (name, dates) => MapEntry(name, dates.toList()..sort()),
        ),
      );
      setState(() {});
      if (applyDraft) {
        await _applySavedDraftIfAny(_draftKey);
      }
      _lastDraftFingerprint = _draftFingerprint(_currentDraftPayload());
      return true;
    } catch (e) {
      if (!mounted || ticket != _prefillTicket) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel precompilare la gara: $e')),
      );
      return false;
    } finally {
      if (mounted && ticket == _prefillTicket) {
        setState(() {
          prefilling = false;
        });
      }
    }
  }

  Future<void> _restoreOriginalData() async {
    if (_selectedReportPackage == null || prefilling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_rounded, size: 38),
        title: const Text('Ripristinare i dati della gara?'),
        content: const Text(
          'Dati gara, date e cronometristi verranno ricaricati dal '
          'calendario. Ore, km, spese e note inseriti nella sezione '
          'cronometristi saranno sostituiti. Orari della gara, '
          'apparecchiature, danni e allegati resteranno invariati. '
          'Anche la bozza locale verrà aggiornata.',
          style: TextStyle(fontSize: 16, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Ripristina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final restored = await _prefillFromSelection(applyDraft: false);
    if (!mounted || !restored) return;
    try {
      await _saveDraft(
        garaId: _draftKey,
        payload: {
          'gara': garaKey.currentState?.getData() ?? {},
          'cronometristi': cronometristiKey.currentState?.getData() ?? [],
          'orariGiornata': garaKey.currentState?.getOrariGiornata() ?? {},
          'apparecchiature': apparecchiaturaKey.currentState?.getData() ?? [],
          'danni': danniKey.currentState?.getData() ?? '',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dati ripristinati, ma bozza non salvata: $e')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dati originari ripristinati'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _buildRapportinoPayload({
    required List<Gara> gareSelezionate,
    required GaraPackage reportPackage,
    required Map<String, dynamic> gara,
    required List<dynamic> cronos,
    required Map<String, dynamic> orariGiornata,
    required List<dynamic> app,
    required String danni,
    required List<dynamic> immagini,
  }) {
    final garaSelezionata = gareSelezionate.first;
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
      'gareSelezionate': gareSelezionate
          .map(
            (gara) => {
              'id': gara.id,
              'titolo': gara.titolo,
              'data': gara.dataGara,
              'dataFine': gara.dataGaraFine,
              'luogo': gara.localita,
            },
          )
          .toList(),
      'pacchetto': {
        'attivo': gareSelezionate.length > 1,
        'id': reportPackage.packageId ?? '',
        'titolo': reportPackage.title,
        'suggerito': reportPackage.suggested,
        'giornate': reportPackage.activeDates
            .map((date) => DateFormat('yyyy-MM-dd').format(date))
            .toList(),
      },
    };
  }

  Future<bool> _confirmReportValidation(GaraPackage package) async {
    final packageDetails = package.isPackage
        ? ' Il PDF comprenderà ${package.gare.length} gare e '
            '${package.activeDates.length} giornate.'
        : '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined, size: 38),
        title: const Text('Validare il rapportino?'),
        content: Text(
          'Stai per validare e salvare il rapportino su Notion.$packageDetails '
          'Al termine ${package.isPackage ? 'tutte le gare incluse saranno' : 'la gara sarà'} '
          'contrassegnat${package.isPackage ? 'e' : 'a'} come “Rapportino ricevuto”. '
          'Potrai quindi scegliere se inviarlo via email o WhatsApp.',
          style: const TextStyle(fontSize: 16, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Torna alla compilazione'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Valida e salva'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showReportSendOptions({
    required XFile file,
    required GaraPackage reportPackage,
  }) async {
    if (!mounted) return;
    final delivery = await showDialog<_ReportDelivery>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.task_alt_rounded, size: 42),
        title: const Text('Rapportino salvato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Il rapportino è stato validato e archiviato su Notion.',
              style: TextStyle(fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Scegli come inviarlo. Si aprirà il menu di condivisione del '
              'dispositivo con il PDF già allegato.',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ReportDelivery.email),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Invia via email'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ReportDelivery.whatsApp),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Invia via WhatsApp'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF168A45),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Non ora'),
          ),
        ],
      ),
    );
    if (delivery == null || !mounted) return;
    await _shareValidatedReport(
      file: file,
      reportPackage: reportPackage,
      delivery: delivery,
    );
  }

  Future<void> _shareValidatedReport({
    required XFile file,
    required GaraPackage reportPackage,
    required _ReportDelivery delivery,
  }) async {
    final channel =
        delivery == _ReportDelivery.email ? 'l’app email' : 'WhatsApp';
    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: delivery == _ReportDelivery.email
              ? 'Rapporto di servizio - ${reportPackage.title}'
              : null,
          text: 'Rapporto di servizio - ${reportPackage.title}',
          files: [file],
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Non riesco ad aprire $channel. Puoi inviare il PDF in seguito '
            'dall’Archivio rapportini.',
          ),
        ),
      );
    }
  }

  Future<void> _saveDraft({
    required String garaId,
    required Map<String, dynamic> payload,
  }) async {
    final package = _selectedReportPackage;
    final savedAt = DateTime.now();
    final draft = {
      'gara': payload['gara'],
      'cronometristi': payload['cronometristi'],
      'orariGiornata': payload['orariGiornata'],
      'apparecchiature': payload['apparecchiature'],
      'danni': payload['danni'],
      'title': package?.title ?? 'Rapportino',
      'dateLabel': package == null ? '' : _packageDatesLabel(package),
      'primaryGaraId': selectedGara?.id ?? '',
      'wholePackage': wholePackage && selectedPackage?.isPackage == true,
      'userId': _loggedUserId ?? '',
      'updatedAt': savedAt.toIso8601String(),
    };
    await _draftService.saveDraft(garaId, draft);
    if (mounted) {
      setState(() => _lastDraftSavedAt = savedAt);
    }
  }

  Map<String, dynamic> _currentDraftPayload() => {
        'gara': garaKey.currentState?.getData() ?? {},
        'cronometristi': cronometristiKey.currentState?.getData() ?? [],
        'orariGiornata': garaKey.currentState?.getOrariGiornata() ?? {},
        'apparecchiature': apparecchiaturaKey.currentState?.getData() ?? [],
        'danni': danniKey.currentState?.getData() ?? '',
      };

  String _draftFingerprint(Map<String, dynamic> payload) => jsonEncode(payload);

  Future<bool> _saveCurrentDraft({bool showMessage = false}) async {
    if (_draftKey.isEmpty || prefilling || _savingDraft) return false;
    final payload = _currentDraftPayload();
    setState(() => _savingDraft = true);
    try {
      await _saveDraft(garaId: _draftKey, payload: payload);
      _lastDraftFingerprint = _draftFingerprint(payload);
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bozza salvata su questo dispositivo'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile salvare la bozza: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _autosaveIfChanged() async {
    if (!mounted || selectedGara == null || prefilling || _savingDraft) return;
    final payload = _currentDraftPayload();
    final fingerprint = _draftFingerprint(payload);
    if (_lastDraftFingerprint == null) {
      _lastDraftFingerprint = fingerprint;
      return;
    }
    if (fingerprint == _lastDraftFingerprint) return;
    await _saveCurrentDraft();
  }

  Future<void> _savePendingChangesIfAny() async {
    if (selectedGara == null || prefilling || _lastDraftFingerprint == null) {
      return;
    }
    final fingerprint = _draftFingerprint(_currentDraftPayload());
    if (fingerprint != _lastDraftFingerprint) {
      await _saveCurrentDraft();
    }
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _allowPop) return;
    await _savePendingChangesIfAny();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _applySavedDraftIfAny(String garaId) async {
    final saved = await _draftService.loadDraft(garaId);
    if (saved == null) return;

    _lastDraftSavedAt = DateTime.tryParse(
      (saved['updatedAt'] ?? '').toString(),
    );

    final garaDataRaw = saved['gara'];
    final cronosRaw = saved['cronometristi'];
    final orariRaw = saved['orariGiornata'];
    final appRaw = saved['apparecchiature'];
    final danniRaw = saved['danni'];

    final garaData = garaDataRaw is Map
        ? Map<String, dynamic>.from(garaDataRaw)
        : <String, dynamic>{};
    final cronos =
        cronosRaw is List ? List<dynamic>.from(cronosRaw) : <dynamic>[];
    final app = appRaw is List ? List<dynamic>.from(appRaw) : <dynamic>[];
    final orari = orariRaw is Map
        ? Map<String, dynamic>.from(orariRaw)
        : <String, dynamic>{};
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
    return formatItalianIsoDateOrValue(value);
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

  String _packageDisplayLabel(GaraPackage package) {
    if (!package.isPackage) return _garaDisplayLabel(package.primary);
    final dates = package.activeDates;
    final dateLabel = dates.isEmpty
        ? 'Senza data'
        : dates.length == 1
            ? formatItalianDate(dates.first)
            : '${formatItalianDate(dates.first, includeYear: false)} - '
                '${formatItalianDate(dates.last)}';
    return '$dateLabel · ${package.title} · ${dates.length} giornate';
  }

  String _packageDatesLabel(GaraPackage package) {
    final dates = package.activeDates;
    if (dates.isEmpty) return 'Date non disponibili';
    return dates.map(formatItalianDate).join(', ');
  }

  Widget _scopeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? const Color(0xFFE8F3FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primary : const Color(0xFFD7E1ED),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? primary : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : icon,
                  color: selected ? Colors.white : const Color(0xFF40556E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCF5E7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFF176B42),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF52657B),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGareSelectionCard() {
    if (loadingGareList) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: const Center(
          child: StopwatchLoading(label: 'Carico le gare disponibili...'),
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
            key: ValueKey('package-selector-${selectedPackage?.stableKey}'),
            initialValue: selectedPackage?.stableKey,
            items: pacchettiDisponibili
                .map(
                  (package) => DropdownMenuItem(
                    value: package.stableKey,
                    child: Text(
                      _packageDisplayLabel(package),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final package = pacchettiDisponibili.firstWhere(
                (entry) => entry.stableKey == value,
                orElse: () {
                  return pacchettiDisponibili.first;
                },
              );
              _selectPackage(package);
            },
            decoration: const InputDecoration(
              labelText: 'Evento o gara',
              helperText: 'Scegli l’evento per cui devi fare il rapportino.',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            hint: const Text('Tocca qui per scegliere'),
          ),
          if (selectedPackage?.isPackage == true) ...[
            const SizedBox(height: 18),
            const Text(
              'Cosa vuoi compilare?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              selectedPackage!.suggested
                  ? 'Le gare sembrano collegate. Controlla le date e scegli.'
                  : 'Questo evento comprende più giornate.',
              style: const TextStyle(color: Color(0xFF52657B), fontSize: 15),
            ),
            if (selectedPackage!.suggested) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5DF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0D49C)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF855B00)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Pacchetto suggerito: verifica che le giornate '
                        'appartengano davvero allo stesso evento.',
                        style: TextStyle(
                          color: Color(0xFF6D4C00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _scopeOption(
              selected: wholePackage,
              icon: Icons.event_repeat_rounded,
              title: 'Tutto l’evento',
              subtitle: '${selectedPackage!.activeDates.length} giornate: '
                  '${_packageDatesLabel(selectedPackage!)}',
              badge: selectedPackage!.isConfirmedPackage ? 'CONSIGLIATO' : null,
              onTap: _selectWholePackage,
            ),
            const SizedBox(height: 10),
            _scopeOption(
              selected: !wholePackage,
              icon: Icons.today_rounded,
              title: 'Una sola giornata',
              subtitle: 'Crea il rapportino soltanto per la data scelta.',
              onTap: () =>
                  _selectSingleGara(selectedGara ?? selectedPackage!.primary),
            ),
            if (!wholePackage) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('day-selector-${selectedGara?.id}'),
                initialValue: selectedGara?.id,
                items: selectedPackage!.gare
                    .map(
                      (gara) => DropdownMenuItem(
                        value: gara.id,
                        child: Text(
                          _garaDisplayLabel(gara),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final gara = selectedPackage!.gare.firstWhere(
                    (entry) => entry.id == value,
                    orElse: () => selectedPackage!.primary,
                  );
                  _selectSingleGara(gara);
                },
                decoration: const InputDecoration(
                  labelText: 'Scegli la giornata',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedGaraInfo() {
    final package = _selectedReportPackage;
    if (package == null) return const SizedBox.shrink();
    final gara = package.primary;

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
                  package.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 2),
          Text(
            package.isPackage
                ? '${package.activeDates.length} giornate incluse'
                : 'Una giornata inclusa',
            style: const TextStyle(
              color: Color(0xFF176B42),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text('Date: ${_packageDatesLabel(package)}'),
          Text("Luogo: ${gara.localita.isEmpty ? '-' : gara.localita}"),
          if (gara.organizzatore.isNotEmpty)
            Text("Organizzatore: ${gara.organizzatore}"),
          if (gara.sport.isNotEmpty) Text("Sport: ${gara.sport}"),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: prefilling ? null : _restoreOriginalData,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Ripristina dati gara'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
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
            onSportChanged: (_) {},
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
          child: CronometristiForm(
            key: cronometristiKey,
            onDataChanged: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Apparecchiatura',
          icon: Icons.precision_manufacturing,
          child: ApparecchiaturaForm(
            key: apparecchiaturaKey,
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCFE2F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _savingDraft
                        ? Icons.sync_rounded
                        : Icons.cloud_done_rounded,
                    color: const Color(0xFF0A66C2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _savingDraft
                          ? 'Salvataggio della bozza...'
                          : _lastDraftSavedAt == null
                              ? 'Salvataggio automatico attivo'
                              : 'Bozza salvata alle '
                                  '${DateFormat('HH:mm').format(_lastDraftSavedAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF24415F),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Gli allegati non vengono conservati nella bozza.',
                style: TextStyle(color: Color(0xFF52657B), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _savingDraft
                ? null
                : () => _saveCurrentDraft(showMessage: true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Salva bozza'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A66C2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              final gareSelezionate = _selectedReportGare;
              final reportPackage = _selectedReportPackage;
              if (gareSelezionate.isEmpty || reportPackage == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seleziona prima una gara'),
                  ),
                );
                return;
              }

              if (!await _confirmReportValidation(reportPackage)) return;

              final gara = garaKey.currentState?.getData() ?? {};
              final cronos = cronometristiKey.currentState?.getData() ?? [];
              final orariGiornata =
                  garaKey.currentState?.getOrariGiornata() ?? {};
              final app = apparecchiaturaKey.currentState?.getData() ?? [];
              final danni = danniKey.currentState?.getData() ?? '';
              final immagini = allegatiKey.currentState?.getImages() ?? [];
              final payload = _buildRapportinoPayload(
                gareSelezionate: gareSelezionate,
                reportPackage: reportPackage,
                gara: gara,
                cronos: cronos,
                orariGiornata: orariGiornata,
                app: app,
                danni: danni,
                immagini: immagini,
              );

              try {
                await _saveDraft(
                  garaId: _draftKey,
                  payload: payload,
                );
                final reportFilename = _notionReportFilename(reportPackage);
                late final _ReportArchiveResult archiveResult;
                late final XFile reportFile;
                if (kIsWeb) {
                  final pdfBytes = await generaPdfBytesConDati(payload);
                  archiveResult = await _archiveReport(
                    pdfBytes: pdfBytes,
                    gare: gareSelezionate,
                    filename: reportFilename,
                  );
                  reportFile = XFile.fromData(
                    pdfBytes,
                    mimeType: 'application/pdf',
                    name: 'rapporto_servizio.pdf',
                  );
                  _showArchiveWarning(archiveResult);
                } else {
                  final file = await generaPdfConDati(
                    payload,
                    salvaLocalmente: true,
                  );
                  archiveResult = await _archiveReport(
                    pdfBytes: await file.readAsBytes(),
                    gare: gareSelezionate,
                    filename: reportFilename,
                  );
                  reportFile = XFile(file.path);
                  _showArchiveWarning(archiveResult);
                }
                if (!archiveResult.uploaded) return;
                for (final gara in gareSelezionate) {
                  await notion.updateGaraStatus(
                    gara.id,
                    RaceStatuses.reportReceived,
                  );
                }
                await _draftService.deleteDraft(_draftKey);
                if (mounted) {
                  setState(() => _lastDraftSavedAt = null);
                }
                await _showReportSendOptions(
                  file: reportFile,
                  reportPackage: reportPackage,
                );
                await _loadGareDsc();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Errore durante il salvataggio del rapportino: $e',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Salva e invia'),
          ),
        ),
      ],
    );
  }

  String _notionReportFilename(GaraPackage reportPackage) {
    final date = reportPackage.startDate == null
        ? ''
        : DateFormat('yyyy-MM-dd').format(reportPackage.startDate!);
    final datedTitle =
        date.isEmpty ? reportPackage.title : '$date - ${reportPackage.title}';
    return 'Rapporto servizio - $datedTitle.pdf';
  }

  Future<_ReportArchiveResult> _archiveReport({
    required List<int> pdfBytes,
    required List<Gara> gare,
    required String filename,
  }) async {
    final sizeMb = pdfBytes.length / (1024 * 1024);
    if (pdfBytes.length > AppConfig.maxNotionPdfBytes) {
      return _ReportArchiveResult.failure(
        'Il PDF pesa ${sizeMb.toStringAsFixed(1)} MB e supera il limite di '
        '${(AppConfig.maxNotionPdfBytes / (1024 * 1024)).toStringAsFixed(1)} MB. '
        'Riduci il numero di foto e riprova.',
      );
    }
    try {
      final uploaded = await notion.archiveReportPdf(
        pdfBytes: pdfBytes,
        pageIds: gare.map((gara) => gara.id).toList(),
        filename: filename,
      );
      return uploaded
          ? const _ReportArchiveResult.success()
          : const _ReportArchiveResult.failure(
              'Notion non ha confermato il caricamento del PDF.',
            );
    } catch (error) {
      return _ReportArchiveResult.failure(error.toString());
    }
  }

  void _showArchiveWarning(_ReportArchiveResult result) {
    if (result.uploaded || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'PDF generato, ma non archiviato in Notion. ${result.error} '
          'La bozza è stata mantenuta.',
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFillForm = selectedGara != null;

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Crono Valtellinesi'),
          actions: standardAppBarActions(
            context,
            helpTitle: 'Rapportini',
            helpContent: HelpContent.rapportini,
            onRefresh: () async {
              await _savePendingChangesIfAny();
              if (mounted) await _loadGareDsc();
            },
            refreshEnabled: !loadingGareList && !prefilling,
            onHome: () async {
              await _savePendingChangesIfAny();
              if (!context.mounted) return;
              setState(() => _allowPop = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
          ),
        ),
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF3FF),
                  Color(0xFFF7FBFF),
                  Color(0xFFFFFFFF)
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      ),
    );
  }
}

class _ReportArchiveResult {
  final bool uploaded;
  final String? error;

  const _ReportArchiveResult.success()
      : uploaded = true,
        error = null;

  const _ReportArchiveResult.failure(this.error) : uploaded = false;
}

enum _ReportDelivery { email, whatsApp }
