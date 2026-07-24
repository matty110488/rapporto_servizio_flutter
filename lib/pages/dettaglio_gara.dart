import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/designation_role.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/notion_user.dart';
import '../widgets/stopwatch_loading.dart';
import '../widgets/standard_app_bar_actions.dart';

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
  List<String> kronos = [];
  List<String> pcSegreteria = [];
  String dsc = '';
  String dscPhone = '';
  bool loadingPeople = true;
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
  bool get _isAdmin => isNotionAdmin(widget.loggedUser);
  bool get _canCallOrganizer =>
      _isAdmin || _role == DesignationRole.serviceManager;
  bool get _canContactDsc => _isAdmin || _role != DesignationRole.viewer;

  @override
  void initState() {
    super.initState();
    notion = widget.notionService ??
        NotionService(databaseId: AppConfig.currentRaceDatabaseId);
    loadPeople();
  }

  Future<void> loadPeople() async {
    try {
      final results = await Future.wait([
        _fetchNames(widget.gara.kronosIds),
        _fetchNames(widget.gara.pcSegreteriaIds),
        if (widget.gara.dscIds.isNotEmpty)
          notion.fetchPersonContactFromPage(widget.gara.dscIds.first)
        else
          Future.value(const NotionPersonContact(name: '', phone: '')),
      ]);
      if (!mounted) return;
      setState(() {
        kronos = results[0] as List<String>;
        pcSegreteria = results[1] as List<String>;
        final dscContact = results[2] as NotionPersonContact;
        dsc = dscContact.name;
        dscPhone = dscContact.phone;
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
        actions: standardAppBarActions(
          context,
          helpTitle: 'Dettaglio gara',
          helpContent: HelpContent.dettaglioGara,
          onRefresh: loadPeople,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadPeople,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _buildMissionHeader(),
            const SizedBox(height: 14),
            _buildQuickActions(),
            const SizedBox(height: 20),
            _sectionTitle(
              eyebrow: 'ORGANIZZATORE',
              title: 'Contatto organizzatore',
              subtitle: 'Riferimento della società che organizza la gara.',
            ),
            const SizedBox(height: 10),
            _buildOrganizerPanel(),
            const SizedBox(height: 20),
            _sectionTitle(
              eyebrow: 'DESIGNAZIONE',
              title: 'Equipe di Cronometraggio',
              subtitle: 'DSC, cronometristi ed Elaborazione Dati.',
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
          if (_role != DesignationRole.viewer) ...[
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

  Widget _buildQuickActions() {
    return _CockpitPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Azioni rapide',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openDirections,
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('INDICAZIONI'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerPanel() {
    final displayPhone = _organizerPhoneDisplay();
    final dialPhone = _organizerPhone();
    return _CockpitPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organizzatore',
                      style: TextStyle(
                        color: Color(0xFF647587),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _organizerName(),
                      style: const TextStyle(
                        color: Color(0xFF1B344F),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_canCallOrganizer &&
              displayPhone != null &&
              dialPhone != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _callOrganizer(dialPhone),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.call_rounded),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        children: [
                          const Text('CHIAMA ORGANIZZATORE'),
                          Text(
                            displayPhone,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrewPanel() {
    return _CockpitPanel(
      child: Column(
        children: [
          _crewGroup(
            'DSC',
            Icons.badge_rounded,
            dsc.isEmpty ? const [] : [dsc],
            phone: _canContactDsc ? dscPhone : '',
          ),
          const Divider(height: 24),
          _crewGroup('Cronometristi', Icons.groups_rounded, kronos),
          const Divider(height: 24),
          _crewGroup('Elaborazione Dati', Icons.computer_rounded, pcSegreteria),
        ],
      ),
    );
  }

  Widget _crewGroup(
    String title,
    IconData icon,
    List<String> values, {
    String phone = '',
  }) {
    final dialPhone = _sanitizePhone(phone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
        ),
        if (dialPhone != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(dialPhone),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('TELEFONA'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F9D55),
                  ),
                  onPressed: () => _openWhatsApp(dialPhone),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WHATSAPP'),
                ),
              ),
            ],
          ),
        ],
      ],
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

  String _timingLabel() {
    final date = DateTime.tryParse(widget.gara.dataGara);
    if (date == null) return 'MISSIONE PROGRAMMATA';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final raceDay = DateTime(date.year, date.month, date.day);
    final days = raceDay.difference(today).inDays;
    if (days == 0) return 'OGGI · È IL GIORNO DELLA GARA';
    if (days == 1) return 'DOMANI';
    if (days > 1) return 'TRA $days GIORNI';
    return 'SERVIZIO DEL ${formatItalianDate(date)}';
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
    return formatItalianIsoDate(iso);
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
    final match = _organizerPhoneMatch();
    if (match == null) return null;
    final raw = match.group(0)!;
    final sanitized = raw.replaceAll(RegExp(r'[^\d+]'), '');
    return sanitized.length >= 8 ? sanitized : null;
  }

  String? _organizerPhoneDisplay() {
    final value = _organizerPhoneMatch()?.group(0)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  RegExpMatch? _organizerPhoneMatch() {
    return RegExp(r'(?:\+\d[\d\s().-]{6,}\d|\b\d[\d\s().-]{7,}\d\b)')
        .firstMatch(widget.gara.organizzatore);
  }

  String _organizerName() {
    var value = widget.gara.organizzatore.trim();
    final match = _organizerPhoneMatch();
    if (match != null) {
      value = value.replaceRange(match.start, match.end, ' ');
    }
    value = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,;:/|\-]+|[\s,;:/|\-]+$'), '')
        .trim();
    return value.isEmpty ? 'Non indicato' : value;
  }

  Future<void> _callOrganizer(String phone) async {
    await _callPhone(phone);
  }

  String? _sanitizePhone(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[^\d+]'), '');
    return sanitized.replaceAll('+', '').length >= 8 ? sanitized : null;
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _showMessage('Non riesco ad avviare la chiamata.');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Non riesco ad aprire WhatsApp.');
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
