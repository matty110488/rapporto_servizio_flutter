import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/help_content.dart';
import '../screens/archivio_screen.dart';
import '../services/rapportino_draft_service.dart';
import '../widgets/help_dialog.dart';
import 'root_screen.dart';

class ServiceReportsPage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const ServiceReportsPage({super.key, required this.loggedUser});

  @override
  State<ServiceReportsPage> createState() => _ServiceReportsPageState();
}

class _ServiceReportsPageState extends State<ServiceReportsPage> {
  final _draftService = RapportinoDraftService();
  int _draftCount = 0;

  String? get _userId {
    final value = widget.loggedUser['id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  void initState() {
    super.initState();
    _refreshDraftCount();
  }

  Future<void> _refreshDraftCount() async {
    final drafts = await _draftService.listDrafts(userId: _userId);
    if (!mounted) return;
    setState(() => _draftCount = drafts.length);
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refreshDraftCount();
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE8F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 31),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF52657B),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapporti di servizio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Rapporti di servizio',
              HelpContent.rapportini,
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
              colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Cosa vuoi fare?',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Scegli una delle tre sezioni. Puoi sempre tornare qui.',
                style: TextStyle(color: Color(0xFF52657B), fontSize: 16),
              ),
              const SizedBox(height: 20),
              _actionCard(
                icon: Icons.note_add_rounded,
                color: const Color(0xFF0A66C2),
                title: 'Nuovo rapportino',
                subtitle: 'Scegli una gara o un evento e inizia a compilare.',
                onTap: () => _open(RootScreen(loggedUser: widget.loggedUser)),
              ),
              const SizedBox(height: 14),
              _actionCard(
                icon: Icons.edit_note_rounded,
                color: const Color(0xFFB76A00),
                title: 'Le mie bozze',
                subtitle:
                    'Continua un rapportino iniziato su questo dispositivo.',
                badge: '$_draftCount',
                onTap: () => _open(
                  RapportinoDraftsPage(loggedUser: widget.loggedUser),
                ),
              ),
              const SizedBox(height: 14),
              _actionCard(
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF176B42),
                title: 'Archivio inviati',
                subtitle: 'Consulta i rapportini già inviati e registrati.',
                onTap: () => _open(
                  ArchivioScreen(loggedUser: widget.loggedUser),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RapportinoDraftsPage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const RapportinoDraftsPage({super.key, required this.loggedUser});

  @override
  State<RapportinoDraftsPage> createState() => _RapportinoDraftsPageState();
}

class _RapportinoDraftsPageState extends State<RapportinoDraftsPage> {
  final _draftService = RapportinoDraftService();
  List<RapportinoDraftSummary> _drafts = const [];
  bool _loading = true;

  String? get _userId {
    final value = widget.loggedUser['id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final drafts = await _draftService.listDrafts(userId: _userId);
    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _loading = false;
    });
  }

  Future<void> _openDraft(RapportinoDraftSummary draft) async {
    if (draft.primaryGaraId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questa vecchia bozza non è riapribile.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RootScreen(
          loggedUser: widget.loggedUser,
          initialGaraId: draft.primaryGaraId,
          initialWholePackage: draft.wholePackage,
          includeSentReports: true,
          initialRaceYear: draft.raceYear,
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteDraft(RapportinoDraftSummary draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare questa bozza?'),
        content:
            Text('La bozza “${draft.title}” verrà eliminata dal dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _draftService.deleteDraft(draft.draftId);
    await _load();
  }

  String _savedLabel(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) return 'Data non disponibile';
    return 'Salvata il ${DateFormat('dd/MM/yyyy').format(value)} '
        'alle ${DateFormat('HH:mm').format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Le mie bozze')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 64),
                        SizedBox(height: 12),
                        Text(
                          'Nessuna bozza salvata',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Le bozze create su questo dispositivo compariranno qui.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFDCE8F6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (draft.dateLabel.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(draft.dateLabel),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              _savedLabel(draft.updatedAt),
                              style: const TextStyle(color: Color(0xFF52657B)),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openDraft(draft),
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('Continua'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  onPressed: () => _deleteDraft(draft),
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                  tooltip: 'Elimina bozza',
                                ),
                              ],
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
