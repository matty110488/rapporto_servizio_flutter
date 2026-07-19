import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/designation_role.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../utils/notion_user.dart';
import '../widgets/stopwatch_loading.dart';

class DettaglioGara extends StatefulWidget {
  final Gara gara;
  final Map<String, dynamic> loggedUser;
  final NotionService? notionService;

  const DettaglioGara({
    super.key,
    required this.gara,
    required this.loggedUser,
    this.notionService,
  });

  @override
  State<DettaglioGara> createState() => _DettaglioGaraState();
}

class _DettaglioGaraState extends State<DettaglioGara> {
  final GlobalKey _passBoundaryKey = GlobalKey();
  List<String> kronos = [];
  List<String> pcSegreteria = [];
  String dsc = '';
  bool loadingPeople = true;
  bool sharingPass = false;
  String? errorMessage;

  late final NotionService notion;

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  String get _loggedUserName {
    final value = extractNotionUserName(widget.loggedUser).trim();
    return value.isEmpty ? 'Cronometrista' : value;
  }

  DesignationRole get _role => designationRoleFor(widget.gara, _loggedUserId);

  @override
  void initState() {
    super.initState();
    notion = widget.notionService ??
        NotionService(databaseId: AppConfig.primaryRaceDatabaseId);
    loadPeople();
  }

  Future<void> loadPeople() async {
    try {
      final results = await Future.wait([
        _fetchNames(widget.gara.kronosIds),
        _fetchNames(widget.gara.pcSegreteriaIds),
        if (widget.gara.dscIds.isNotEmpty)
          notion.fetchNameFromPage(widget.gara.dscIds.first)
        else
          Future.value(''),
      ]);
      if (!mounted) return;
      setState(() {
        kronos = results[0] as List<String>;
        pcSegreteria = results[1] as List<String>;
        dsc = results[2] as String;
        loadingPeople = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingPeople = false;
        errorMessage = 'Impossibile caricare tutti i nominativi.';
      });
    }
  }

  Future<List<String>> _fetchNames(List<String> ids) async {
    if (ids.isEmpty) return [];
    final names = await Future.wait(ids.map(notion.fetchNameFromPage));
    return names.where((name) => name.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      appBar: AppBar(
        title: const Text('Cockpit gara'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: loadPeople,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _buildMissionHeader(),
            const SizedBox(height: 14),
            _buildProgressCard(),
            const SizedBox(height: 14),
            _buildQuickActions(),
            const SizedBox(height: 20),
            _sectionTitle(
              eyebrow: 'DESIGNAZIONE DIGITALE',
              title: 'Il tuo pass',
              subtitle: 'Mostralo, salvalo o condividilo con un tocco.',
            ),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: RepaintBoundary(
                  key: _passBoundaryKey,
                  child: _buildUniversalPass(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sharingPass ? null : _sharePass,
                    icon: sharingPass
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(
                      sharingPass
                          ? 'Preparazione pass...'
                          : 'Condividi o salva pass',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(
              eyebrow: 'EQUIPAGGIO',
              title: 'Squadra di servizio',
              subtitle: 'Tutti i ruoli della designazione in un solo posto.',
            ),
            const SizedBox(height: 10),
            if (loadingPeople)
              const _CockpitPanel(
                child: StopwatchLoading(label: 'Caricamento squadra...'),
              )
            else
              _buildCrewPanel(),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              _buildErrorBox(errorMessage!),
            ],
            const SizedBox(height: 14),
            _buildEquipmentPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionHeader() {
    final gara = widget.gara;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071E3D), Color(0xFF0A4C8A), Color(0xFF0A72C8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330A4C8A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'RACE CONTROL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _darkStatusChip(gara.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _timingLabel(),
            style: const TextStyle(
              color: Color(0xFF8FD4FF),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gara.titolo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroFact(Icons.calendar_month_rounded, _formatDateRange(gara)),
              if (_locationLabel(gara) != '-')
                _heroFact(Icons.location_on_rounded, _locationLabel(gara)),
              if (gara.sport.isNotEmpty)
                _heroFact(Icons.sports_rounded, gara.sport),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF47B6FF),
                  child: Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loggedUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _role.label,
                        style: const TextStyle(color: Color(0xFFB8DBF6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFact(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFBFE6FF), size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    const labels = ['Designazione', 'Servizio', 'Rapportino'];
    final reached = _progressStage();
    return _CockpitPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avanzamento missione',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(labels.length, (index) {
              final active = index <= reached;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF0A66C2)
                                  : const Color(0xFFE6ECF3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              active
                                  ? Icons.check_rounded
                                  : Icons.circle_outlined,
                              size: 18,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF8290A1),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFF123E69)
                                  : const Color(0xFF7A8795),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < labels.length - 1)
                      Container(
                        width: 18,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 24),
                        color: index < reached
                            ? const Color(0xFF0A66C2)
                            : const Color(0xFFDCE4ED),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final phone = _organizerPhone();
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.navigation_rounded,
            label: 'Indicazioni',
            onTap: _openDirections,
          ),
        ),
        if (phone != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.call_rounded,
              label: 'Chiama',
              onTap: () => _callOrganizer(phone),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.badge_rounded,
            label: 'Mostra pass',
            onTap: _scrollToPassHint,
          ),
        ),
      ],
    );
  }

  Widget _buildUniversalPass() {
    final date = DateTime.tryParse(widget.gara.dataGara);
    final day = date == null ? '--' : DateFormat('dd').format(date);
    const months = [
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
    final month = date == null ? 'DATA' : months[date.month - 1];
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 9)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF061A35), Color(0xFF0B5AA2)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child:
                          Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRONO VALTELLINESI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'DESIGNAZIONE · SERVICE PASS',
                          style: TextStyle(
                            color: Color(0xFFA9D9FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded, color: Colors.white70),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _PassLabel('EVENTO'),
                            Text(
                              widget.gara.titolo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0B2340),
                                fontSize: 20,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                color: Color(0xFF075CA8),
                                fontSize: 25,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              month,
                              style: const TextStyle(
                                color: Color(0xFF075CA8),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                          child: _passValue('CRONOMETRISTA', _loggedUserName)),
                      const SizedBox(width: 12),
                      Expanded(child: _passValue('RUOLO', _role.label)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child:
                              _passValue('LUOGO', _locationLabel(widget.gara))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _passValue(
                          'DISCIPLINA',
                          widget.gara.sport.isEmpty ? '-' : widget.gara.sport,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD8E1EB)),
                    ),
                    child: QrImageView(
                      data: _passDeepLink(),
                      version: QrVersions.auto,
                      size: 84,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF071E3D),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF071E3D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _PassLabel('PASS ID'),
                        Text(
                          _shortPassId(),
                          style: const TextStyle(
                            color: Color(0xFF0B2340),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Gara.statusLabel(widget.gara.status).toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF087348),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Scansiona per aprire il cockpit',
                          style:
                              TextStyle(color: Color(0xFF667789), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PassLabel(label),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1B344F),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCrewPanel() {
    return _CockpitPanel(
      child: Column(
        children: [
          _crewGroup(
              'DSC', Icons.badge_rounded, dsc.isEmpty ? const [] : [dsc]),
          const Divider(height: 24),
          _crewGroup('Cronometristi', Icons.groups_rounded, kronos),
          const Divider(height: 24),
          _crewGroup('PC Segreteria', Icons.computer_rounded, pcSegreteria),
        ],
      ),
    );
  }

  Widget _crewGroup(String title, IconData icon, List<String> values) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0A66C2), size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(
                values.isEmpty ? 'Non assegnato' : values.join(' · '),
                style: TextStyle(
                  color: values.isEmpty
                      ? const Color(0xFF7E8B99)
                      : const Color(0xFF344E68),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentPanel() {
    final items = widget.gara.apparecchiature;
    return _CockpitPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded,
                  color: Color(0xFF0A66C2)),
              SizedBox(width: 9),
              Text(
                'Apparecchiatura prevista',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'Nessuna apparecchiatura indicata.',
              style: TextStyle(color: Color(0xFF718093)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => Chip(
                      avatar: const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text(item),
                      backgroundColor: const Color(0xFFEAF7F1),
                      side: const BorderSide(color: Color(0xFFC9EADB)),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF0A66C2),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Color(0xFF647587))),
      ],
    );
  }

  Widget _darkStatusChip(String status) {
    final value = status.trim().isEmpty ? 'N/D' : Gara.statusLabel(status);
    return Container(
      constraints: const BoxConstraints(maxWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C8B61),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD2D2)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB23636))),
    );
  }

  int _progressStage() {
    final status = widget.gara.status.trim().toUpperCase();
    if (status == RaceStatuses.reportReceived) return 2;
    if (status == RaceStatuses.completed || status == RaceStatuses.sicWinOk) {
      return 1;
    }
    if (status == RaceStatuses.designationSent) return 0;
    return -1;
  }

  String _timingLabel() {
    final date = DateTime.tryParse(widget.gara.dataGara);
    if (date == null) return 'MISSIONE PROGRAMMATA';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final raceDay = DateTime(date.year, date.month, date.day);
    final days = raceDay.difference(today).inDays;
    if (days == 0) return 'OGGI · È IL GIORNO DELLA GARA';
    if (days == 1) return 'DOMANI · PREPARATI ALLA MISSIONE';
    if (days > 1) return 'TRA $days GIORNI';
    return 'SERVIZIO DEL ${DateFormat('dd/MM/yyyy').format(date)}';
  }

  String _formatDateRange(Gara gara) {
    final start = _fmtDate(gara.dataGara);
    final end =
        gara.dataGaraFine.isNotEmpty ? _fmtDate(gara.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start – $end';
    return start ?? end ?? '-';
  }

  String _locationLabel(Gara gara) {
    final localita = gara.localita.trim();
    final sito = gara.sitoGara.trim();
    if (localita.isNotEmpty && sito.isNotEmpty) return '$localita · $sito';
    if (localita.isNotEmpty) return localita;
    if (sito.isNotEmpty) return sito;
    return '-';
  }

  String? _fmtDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? null : DateFormat('dd/MM/yyyy').format(date);
  }

  String _passDeepLink() {
    return Uri.base
        .replace(queryParameters: {'garaId': widget.gara.id}).toString();
  }

  String _shortPassId() {
    final clean = widget.gara.id.replaceAll('-', '').toUpperCase();
    return clean.length <= 10 ? clean : clean.substring(clean.length - 10);
  }

  String _safePassFilename() {
    final date = widget.gara.dataGara.replaceAll(RegExp(r'[^0-9]'), '');
    final title = widget.gara.titolo
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'pass_designazione_${date.isEmpty ? 'gara' : date}_${title.isEmpty ? 'crono' : title}.png';
  }

  Future<void> _sharePass() async {
    final box = context.findRenderObject() as RenderBox?;
    setState(() => sharingPass = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _passBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Pass non disponibile');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Impossibile creare il pass');
      final bytes = data.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          title: 'Designazione ${widget.gara.titolo}',
          text: 'La mia designazione per ${widget.gara.titolo}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: _safePassFilename(),
            ),
          ],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Non riesco a condividere il pass. Riprova.')),
      );
    } finally {
      if (mounted) setState(() => sharingPass = false);
    }
  }

  Future<void> _openDirections() async {
    final query = _locationLabel(widget.gara);
    if (query == '-') {
      _showMessage('Nessun luogo disponibile per questa gara.');
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Non riesco ad aprire le indicazioni.');
    }
  }

  String? _organizerPhone() {
    final match = RegExp(r'(?:\+\d[\d\s().-]{6,}\d|\b\d[\d\s().-]{7,}\d\b)')
        .firstMatch(widget.gara.organizzatore);
    if (match == null) return null;
    final raw = match.group(0)!;
    final sanitized = raw.replaceAll(RegExp(r'[^\d+]'), '');
    return sanitized.length >= 8 ? sanitized : null;
  }

  Future<void> _callOrganizer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _showMessage('Non riesco ad avviare la chiamata.');
    }
  }

  void _scrollToPassHint() {
    final passContext = _passBoundaryKey.currentContext;
    if (passContext != null) {
      Scrollable.ensureVisible(
        passContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CockpitPanel extends StatelessWidget {
  const _CockpitPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7F1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8E5F2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF0A66C2)),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassLabel extends StatelessWidget {
  const _PassLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF718093),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child:
              const CircleAvatar(radius: 8, backgroundColor: Color(0xFFF3F7FC)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dots = (constraints.maxWidth / 10).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  dots,
                  (_) => const SizedBox(
                    width: 4,
                    height: 1,
                    child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFCAD4DF))),
                  ),
                ),
              );
            },
          ),
        ),
        Transform.translate(
          offset: const Offset(8, 0),
          child:
              const CircleAvatar(radius: 8, backgroundColor: Color(0xFFF3F7FC)),
        ),
      ],
    );
  }
}
