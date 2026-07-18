import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gara.dart';
import '../screens/archivio_screen.dart';
import '../services/notion_service.dart';
import '../services/prank_popup_service.dart';
import '../services/push_notification_service.dart';
import '../utils/notion_user.dart';
import 'dettaglio_gara.dart';
import 'designazioni_page.dart';
import 'gare_page.dart';
import 'notifications_page.dart';
import 'root_screen.dart';
import 'settings_page.dart';
import 'statistiche_page.dart';

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
  static const _layoutVersion = 'Home layout 2026.07.18';
  // Cambia qui la frequenza di aggiornamento automatico del banner Home.
  static const _dashboardAutoRefreshInterval = Duration(minutes: 5);

  late final NotionService _notion;
  bool _loadingDashboard = true;
  bool _refreshingDashboard = false;
  String? _dashboardError;
  _DashboardData _dashboard = const _DashboardData();
  int _unreadNotifications = 0;
  Timer? _dashboardRefreshTimer;
  Timer? _notificationPollingTimer;

  @override
  void initState() {
    super.initState();
    _notion = NotionService(databaseId: _db2025);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrankPopupService.maybeShow(context, widget.loggedUser);
    });
    _loadDashboard();
    _dashboardRefreshTimer = Timer.periodic(_dashboardAutoRefreshInterval, (_) {
      unawaited(_loadDashboard(showLoading: false));
    });
    unawaited(_syncDesignationNotifications());
    unawaited(_loadNotificationBadge());
    _notificationPollingTimer =
        Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_syncDesignationNotifications());
      unawaited(_loadNotificationBadge());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final garaId = Uri.base.queryParameters['garaId'];
      if (garaId != null && garaId.isNotEmpty) {
        unawaited(_openGaraFromNotification(garaId));
      }
    });
  }

  @override
  void dispose() {
    _dashboardRefreshTimer?.cancel();
    _notificationPollingTimer?.cancel();
    super.dispose();
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _extractUserName() {
    return extractNotionUserName(widget.loggedUser);
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  Future<void> _syncDesignationNotifications() async {
    try {
      await _notion.notifyDesignationsForSentStatus();
    } catch (_) {
      // Silent by design: notification sync must not block the home page.
    }
  }

  Future<void> _loadNotificationBadge() async {
    final userId = _loggedUserId;
    if (userId == null) return;
    try {
      final notifications = await fetchPushNotifications(userId);
      if (!mounted) return;
      setState(() {
        _unreadNotifications =
            notifications.where((notice) => !notice.read).length;
      });
    } catch (_) {
      // Silent: badge refresh must not block the home page.
    }
  }

  Future<void> _openGaraFromNotification(String garaId) async {
    try {
      final page = await _notion.retrievePage(garaId);
      final gara = Gara.fromNotion(page);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DettaglioGara(gara: gara)),
      );
    } catch (_) {
      if (!mounted) return;
      _openPage(context, GarePage(loggedUser: widget.loggedUser));
    }
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    if (_refreshingDashboard || (!showLoading && _loadingDashboard)) return;
    setState(() {
      if (showLoading) {
        _loadingDashboard = true;
      } else {
        _refreshingDashboard = true;
      }
      _dashboardError = null;
    });

    try {
      final userId = _loggedUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _dashboard = const _DashboardData();
          _loadingDashboard = false;
          _refreshingDashboard = false;
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
        _dashboard = _DashboardData(nextServices: prossimiDue);
        _loadingDashboard = false;
        _refreshingDashboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = e.toString();
        _loadingDashboard = false;
        _refreshingDashboard = false;
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
    if (upcoming.isNotEmpty) return upcoming.take(limit).toList();
    if (withDate.isNotEmpty) return withDate.take(limit).toList();
    return services.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userName = _extractUserName();
    final notificationItem = _HomeNavData(
      icon: Icons.mark_email_unread_outlined,
      label: 'Notifiche',
      subtitle: _unreadNotifications > 0
          ? '$_unreadNotifications nuove notifiche'
          : 'Visualizza le notifiche',
      badgeCount: _unreadNotifications,
      onTap: () => _openPage(
        context,
        NotificationsPage(
          loggedUser: widget.loggedUser,
          onNotificationsChanged: _loadNotificationBadge,
        ),
      ),
    );
    void openSettings() => _openPage(
          context,
          SettingsPage(
            loggedUser: widget.loggedUser,
            onNotificationsChanged: _loadNotificationBadge,
          ),
        );
    final navItems = [
      _HomeNavData(
        icon: Icons.flag,
        label: 'Calendario gare',
        subtitle: 'Consulta eventi e disponibilità',
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
        subtitle: 'Compila e invia il Rapporto di Servizio',
        onTap: () =>
            _openPage(context, RootScreen(loggedUser: widget.loggedUser)),
      ),
      _HomeNavData(
        icon: Icons.folder,
        label: 'Rapportini completati',
        subtitle: 'Apri e modifica Rapporti di Servizio già inviati',
        onTap: () => _openPage(
          context,
          ArchivioScreen(loggedUser: widget.loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.insights,
        label: 'Statistiche interessanti',
        subtitle: 'Numeri personali su servizi, sport ed Elaborazione Dati',
        onTap: () => _openPage(
          context,
          StatistichePage(loggedUser: widget.loggedUser),
        ),
      ),
      notificationItem,
      _HomeNavData(
        icon: Icons.settings_outlined,
        label: 'Impostazioni',
        subtitle: 'Notifiche, sicurezza e password',
        onTap: openSettings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: useSidebar
              ? null
              : AppBar(
                  automaticallyImplyLeading: false,
                  title: SizedBox(
                    height: 42,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: openSettings,
                      tooltip: 'Impostazioni',
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF3FF),
                  Color(0xFFF7FBFF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
            child: SafeArea(
              child: useSidebar
                  ? Row(
                      children: [
                        _HomeSidebar(
                          userName: userName,
                          navItems: navItems,
                          onLogout: widget.onLogout,
                        ),
                        Expanded(
                          child: _homeContent(
                            userName: userName,
                            navItems: navItems,
                            onOpenNotifications: notificationItem.onTap,
                            compact: false,
                          ),
                        ),
                      ],
                    )
                  : _homeContent(
                      userName: userName,
                      navItems: navItems,
                      onOpenNotifications: notificationItem.onTap,
                      compact: true,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _homeContent({
    required String userName,
    required List<_HomeNavData> navItems,
    required VoidCallback onOpenNotifications,
    required bool compact,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 720 : 980),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            compact ? 12 : 28,
            compact ? 16 : 28,
            24,
          ),
          children: [
            _hero(userName),
            const SizedBox(height: 18),
            if (compact) ...[
              const Text(
                'Menu principale',
                style: TextStyle(
                  color: Color(0xFF1A2B40),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...navItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HomeActionTile(item: item),
                ),
              ),
              const SizedBox(height: 10),
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
            ] else
              _DesktopSummaryCard(
                notificationsCount: _unreadNotifications,
                onOpenNotifications: onOpenNotifications,
              ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                _layoutVersion,
                style: TextStyle(
                  color: Color(0xFF7B8EA3),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
    final refreshButton = IconButton(
      tooltip: 'Aggiorna servizi',
      onPressed: _loadingDashboard || _refreshingDashboard
          ? null
          : () => unawaited(_loadDashboard(showLoading: false)),
      icon: _refreshingDashboard
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh, color: Colors.white),
    );

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Prossimi servizi da svolgere',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    refreshButton,
                  ],
                ),
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
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
                  onPressed: _refreshingDashboard
                      ? null
                      : () => unawaited(_loadDashboard(showLoading: false)),
                  child: const Text(
                    'Riprova',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                refreshButton,
              ],
            )
          else
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Prossimi servizi da svolgere',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      refreshButton,
                    ],
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
  final int badgeCount;
  final VoidCallback onTap;

  _HomeNavData({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.badgeCount = 0,
    required this.onTap,
  });
}

class _HomeSidebar extends StatelessWidget {
  final String userName;
  final List<_HomeNavData> navItems;
  final VoidCallback onLogout;

  const _HomeSidebar({
    required this.userName,
    required this.navItems,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE8F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(
              'assets/logo.png',
              height: 58,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Ciao, $userName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1A2B40),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scegli una sezione dal menu.',
            style: TextStyle(
              color: Color(0xFF49627E),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            _HomePageState._layoutVersion,
            style: TextStyle(
              color: Color(0xFF7B8EA3),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _HomeMenuTile(item: navItems[index]);
              },
            ),
          ),
          const Divider(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: const Color(0xFF0A66C2),
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _HomeMenuTile extends StatelessWidget {
  final _HomeNavData item;

  const _HomeMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: item.badgeCount > 0 ? const Color(0xFFFFF1F1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.badgeCount > 0
                  ? const Color(0xFFFFB4B4)
                  : const Color(0xFFE2ECF8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.badgeCount > 0
                      ? Colors.red
                      : const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: item.badgeCount > 0
                      ? Colors.white
                      : const Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2B40),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.badgeCount > 0
                            ? Colors.red
                            : const Color(0xFF49627E),
                        fontSize: 12,
                        fontWeight: item.badgeCount > 0
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.badgeCount > 0) ...[
                const SizedBox(width: 8),
                Badge.count(
                  count: item.badgeCount,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final _HomeNavData item;

  const _HomeActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return _HomeMenuTile(item: item);
  }
}

class _DesktopSummaryCard extends StatelessWidget {
  final int notificationsCount;
  final VoidCallback onOpenNotifications;

  const _DesktopSummaryCard({
    required this.notificationsCount,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE8F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: notificationsCount > 0
                  ? const Color(0xFFFFE7E7)
                  : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              notificationsCount > 0
                  ? Icons.mark_email_unread_outlined
                  : Icons.dashboard_outlined,
              color:
                  notificationsCount > 0 ? Colors.red : const Color(0xFF0A66C2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Color(0xFF1A2B40),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notificationsCount > 0
                      ? '$notificationsCount notifiche non lette'
                      : 'Usa il menu laterale per aprire le sezioni operative.',
                  style: TextStyle(
                    color: notificationsCount > 0
                        ? Colors.red
                        : const Color(0xFF49627E),
                    fontSize: 13,
                    fontWeight: notificationsCount > 0
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (notificationsCount > 0)
            FilledButton(
              onPressed: onOpenNotifications,
              child: const Text('Apri notifiche'),
            ),
        ],
      ),
    );
  }
}
