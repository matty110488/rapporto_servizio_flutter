import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gara.dart';
import '../services/auth_service.dart';
import '../services/notion_service.dart';
import '../services/prank_popup_service.dart';
import '../services/push_notification_service.dart';
import '../utils/notion_user.dart';
import '../screens/archivio_screen.dart';
import 'designazioni_page.dart';
import 'gare_page.dart';
import 'root_screen.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.loggedUser,
    required this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';

  late final NotionService _notion;
  bool _loadingDashboard = true;
  String? _dashboardError;
  _DashboardData _dashboard = const _DashboardData();
  bool _registeringPasskey = false;
  bool _enablingNotifications = false;
  bool _notificationsEnabled = false;
  StreamSubscription<PushNotice>? _pushNoticeSubscription;

  @override
  void initState() {
    super.initState();
    _notion = NotionService(
      databaseId: _db2025,
    );
    _pushNoticeSubscription = foregroundPushNotices.listen((notice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (notice.body.isNotEmpty) Text(notice.body),
            ],
          ),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrankPopupService.maybeShow(context, widget.loggedUser);
    });
    _loadDashboard();
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    _pushNoticeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final enabled = await notificationsAreEnabled();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      // Lo stato resta disattivato se il browser non espone ancora il permesso.
    }
  }

  Future<void> _enableNotifications() async {
    final userId = _loggedUserId;
    if (userId == null || userId.isEmpty) return;
    setState(() => _enablingNotifications = true);
    try {
      await enableNotificationsForUser(userId);
      if (!mounted) return;
      setState(() => _notificationsEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Notifiche attivate su questo dispositivo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non è stato possibile attivare le notifiche. Controlla i permessi del browser o del dispositivo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enablingNotifications = false);
    }
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _enablePasskey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attiva accesso biometrico'),
        content: const Text(
          'Il telefono creerà una passkey protetta da Face ID, impronta '
          'digitale o codice del dispositivo. Username e password resteranno '
          'disponibili come metodo di recupero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Attiva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _registeringPasskey = true);
    try {
      await AuthService().registerPasskey();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Accesso biometrico attivato. Dal prossimo login potrai usare Face ID o impronta.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non è stato possibile attivare l’accesso biometrico su questo dispositivo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _registeringPasskey = false);
    }
  }

  String _extractUserName() {
    return extractNotionUserName(widget.loggedUser);
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });

    try {
      final userId = _loggedUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _dashboard = const _DashboardData();
          _loadingDashboard = false;
        });
        return;
      }

      final rows =
          await _notion.fetchGare(additionalDatabaseIds: const [_db2026]);
      final gare = rows.map((e) => Gara.fromNotion(e)).toList();

      const prossimiServiziStatuses = {
        'DESIGNAZIONE INVIATA',
      };

      final conUtente =
          gare.where((g) => g.kronosIds.contains(userId)).toList();
      final prossimiServizi = conUtente
          .where((g) =>
              prossimiServiziStatuses.contains(g.status.trim().toUpperCase()))
          .toList();

      final prossimiDue = _pickNextServices(prossimiServizi, limit: 2);

      if (!mounted) return;
      setState(() {
        _dashboard = _DashboardData(
          nextServices: prossimiDue,
        );
        _loadingDashboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = e.toString();
        _loadingDashboard = false;
      });
    }
  }

  List<Gara> _pickNextServices(List<Gara> services, {int limit = 2}) {
    if (services.isEmpty) return const [];

    DateTime? parseStart(Gara g) {
      final parsed = DateTime.tryParse(g.dataGara);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final withDate = services.where((g) => parseStart(g) != null).toList();
    withDate.sort((a, b) => parseStart(a)!.compareTo(parseStart(b)!));

    final upcoming = withDate.where((g) {
      final start = parseStart(g)!;
      return start.isAfter(today) || isSameDay(start, today);
    }).toList();
    if (upcoming.isNotEmpty) {
      return upcoming.take(limit).toList();
    }

    if (withDate.isNotEmpty) {
      return withDate.take(limit).toList();
    }
    return services.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userName = _extractUserName();
    final navItems = [
      _HomeNavData(
        icon: Icons.flag,
        label: 'Calendario gare',
        subtitle: 'Consulta eventi e disponibilita',
        onTap: () =>
            _openPage(context, GarePage(loggedUser: widget.loggedUser)),
      ),
      _HomeNavData(
        icon: Icons.assignment_turned_in,
        label: 'Le tue designazioni',
        subtitle: 'Vedi servizi assegnati e conclusi',
        onTap: () => _openPage(
          context,
          DesignazioniPage(loggedUser: widget.loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.assignment,
        label: 'Rapporti di Servizio',
        subtitle: 'Compila e invia il rapportino gara',
        onTap: () =>
            _openPage(context, RootScreen(loggedUser: widget.loggedUser)),
      ),
      _HomeNavData(
        icon: Icons.folder,
        label: 'Rapportini completati',
        subtitle: 'Apri e modifica rapportini gia inviati',
        onTap: () => _openPage(
          context,
          ArchivioScreen(loggedUser: widget.loggedUser),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 170,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SizedBox(
            width: 170,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _enablingNotifications ? null : _enableNotifications,
            tooltip:
                _notificationsEnabled ? 'Notifiche attive' : 'Attiva notifiche',
            icon: _enablingNotifications
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
          ),
          IconButton(
            onPressed: _registeringPasskey ? null : _enablePasskey,
            tooltip: 'Attiva Face ID o impronta',
            icon: _registeringPasskey
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(userName),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    itemCount: navItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      return _HomeCard(
                        icon: item.icon,
                        label: item.label,
                        subtitle: item.subtitle,
                        onTap: item.onTap,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A66C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(String userName) {
    String formatDate(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return '-';
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }

    final prossimi = _dashboard.nextServices;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Benvenuto',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingDashboard)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          else if (_dashboardError != null)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dashboard non disponibile',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _loadDashboard,
                  child: const Text(
                    'Riprova',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          else ...[
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prossimi servizi da svolgere',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (prossimi.isEmpty)
                    const Text(
                      'Nessun servizio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    ...prossimi.map((g) {
                      final statusLabel = Gara.statusLabel(g.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatDate(g.dataGara)} - ${g.titolo}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Stato: $statusLabel',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (prossimi.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Mostrati i prossimi 2 servizi',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardData {
  final List<Gara> nextServices;

  const _DashboardData({
    this.nextServices = const [],
  });
}

class _HomeNavData {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  _HomeNavData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE8F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0A66C2)),
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2B40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF49627E),
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
