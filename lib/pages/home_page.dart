import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../models/gara.dart';
import '../services/app_update_exception.dart';
import '../services/app_update_service.dart';
import '../services/app_preferences_service.dart';
import '../services/notion_service.dart';
import '../services/prank_popup_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/notion_user.dart';
import '../widgets/app_ui.dart';
import 'admin_dashboard_page.dart';
import 'dettaglio_gara.dart';
import 'designazioni_page.dart';
import 'gare_page.dart';
import 'notifications_page.dart';
import 'service_reports_page.dart';
import 'settings_page.dart';
import 'statistiche_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;
  final NotionService? notionService;
  @visibleForTesting
  final int initialUnreadNotifications;

  const HomePage({
    super.key,
    required this.loggedUser,
    required this.onLogout,
    this.notionService,
    this.initialUnreadNotifications = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NotionService _notion;
  String _appVersionLabel = 'App version - MT88';
  bool _loadingDashboard = true;
  bool _refreshingDashboard = false;
  String? _dashboardError;
  _DashboardData _dashboard = const _DashboardData();
  int _unreadNotifications = 0;
  late final PageController _raceControlController;
  int _raceControlIndex = 0;
  Timer? _dashboardRefreshTimer;
  Timer? _notificationPollingTimer;
  Timer? _versionTapResetTimer;
  int _versionTapCount = 0;
  _HomeMenuMode _menuMode = _HomeMenuMode.list;

  @override
  void initState() {
    super.initState();
    _raceControlController = PageController(viewportFraction: 0.87);
    _unreadNotifications = widget.initialUnreadNotifications;
    unawaited(_loadMenuPreference());
    _notion = widget.notionService ??
        NotionService(databaseId: AppConfig.currentRaceDatabaseId);
    unawaited(_loadAppVersion());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrankPopupService.maybeShow(context, widget.loggedUser);
      unawaited(_showAvailableAppUpdate());
    });
    _loadDashboard();
    _dashboardRefreshTimer =
        Timer.periodic(AppConfig.dashboardRefreshInterval, (_) {
      unawaited(_loadDashboard(showLoading: false));
    });
    unawaited(_loadNotificationBadge());
    _notificationPollingTimer =
        Timer.periodic(AppConfig.notificationBadgeRefreshInterval, (_) {
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

  Future<void> _loadMenuPreference() async {
    try {
      final gridEnabled = await AppPreferencesService.loadHomeMenuGridEnabled();
      if (!mounted) return;
      setState(() {
        _menuMode = gridEnabled ? _HomeMenuMode.grid : _HomeMenuMode.list;
      });
    } catch (_) {
      // Elenco resta il fallback quando lo storage locale non è disponibile.
    }
  }

  void _setMenuMode(_HomeMenuMode mode) {
    if (_menuMode == mode) return;
    setState(() => _menuMode = mode);
    unawaited(
      AppPreferencesService.saveHomeMenuGridEnabled(
        mode == _HomeMenuMode.grid,
      ),
    );
  }

  @override
  void dispose() {
    _dashboardRefreshTimer?.cancel();
    _notificationPollingTimer?.cancel();
    _versionTapResetTimer?.cancel();
    _raceControlController.dispose();
    super.dispose();
  }

  void _handleVersionTap() {
    _versionTapResetTimer?.cancel();
    _versionTapCount += 1;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      PrankPopupService.showLegendaryMode(context);
      return;
    }
    _versionTapResetTimer = Timer(const Duration(seconds: 3), () {
      _versionTapCount = 0;
    });
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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      if (!mounted || version.isEmpty) return;
      setState(() {
        _appVersionLabel = 'App version $version - MT88';
      });
    } catch (_) {
      // The version label is decorative and must never block the home page.
    }
  }

  Future<void> _showAvailableAppUpdate() async {
    final AppUpdateInfo? update;
    try {
      update = await checkForAppUpdate();
    } catch (_) {
      return;
    }
    final availableUpdate = update;
    if (availableUpdate == null || !mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded),
        title: const Text('Aggiornamento disponibile'),
        content: Text(
          'È disponibile la versione ${availableUpdate.latestVersionLabel}. '
          'L’aggiornamento richiede solo pochi secondi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Più tardi'),
          ),
          FilledButton.icon(
            key: const ValueKey('confirm-app-update'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('AGGIORNA'),
          ),
        ],
      ),
    );
    if (shouldUpdate != true || !mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 20),
          content: Text(
            'Download dell’aggiornamento in corso. Non chiudere l’app…',
          ),
        ),
      );
      await forceAppUpdate();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppUpdateException
                ? error.userMessage
                : 'Non è stato possibile aggiornare l’app. '
                    'Riprova da Impostazioni.',
          ),
        ),
      );
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
        MaterialPageRoute(
          builder: (_) => DettaglioGara(
            gara: gara,
            loggedUser: widget.loggedUser,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _openPage(context, GarePage(loggedUser: widget.loggedUser));
    }
  }

  Future<void> _loadDashboard({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
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

      final rows = await _notion.fetchGare(forceRefresh: forceRefresh);
      final gare = rows.map((e) => Gara.fromNotion(e)).toList();

      final conUtente = gare
          .where(
            (g) =>
                g.kronosIds.contains(userId) ||
                g.dscIds.contains(userId) ||
                g.pcSegreteriaIds.contains(userId),
          )
          .toList();
      final prossimiServizi = conUtente
          .where((g) =>
              g.status.trim().toUpperCase() == RaceStatuses.designationSent)
          .toList();

      final raceControls = _pickNextServices(
        prossimiServizi,
        limit: prossimiServizi.length,
      );

      if (!mounted) return;
      setState(() {
        _dashboard = _DashboardData(nextServices: raceControls);
        _raceControlIndex = 0;
        _loadingDashboard = false;
        _refreshingDashboard = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _raceControlController.hasClients) {
          _raceControlController.jumpToPage(0);
        }
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
    final past = withDate.where((g) {
      final start = parseStart(g)!;
      return start.isBefore(today);
    }).toList()
      ..sort((a, b) => parseStart(b)!.compareTo(parseStart(a)!));
    final withoutDate = services.where((g) => parseStart(g) == null);
    return [...upcoming, ...past, ...withoutDate].take(limit).toList();
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
      if (isNotionAdmin(widget.loggedUser))
        _HomeNavData(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Centro di controllo Admin',
          subtitle: 'Criticità, gare e rapportini da gestire',
          onTap: () => _openPage(
            context,
            AdminDashboardPage(
              loggedUser: widget.loggedUser,
              notionService: _notion,
            ),
          ),
        ),
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
        subtitle: 'Nuovi rapportini, bozze e archivio inviati',
        onTap: () => _openPage(
          context,
          ServiceReportsPage(loggedUser: widget.loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.insights,
        label: 'Statistiche',
        subtitle: 'I tuoi numeri su servizi e designazioni',
        onTap: () => _openPage(
          context,
          StatistichePage(loggedUser: widget.loggedUser),
        ),
      ),
      notificationItem,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: useSidebar
              ? null
              : AppBar(
                  automaticallyImplyLeading: false,
                  toolbarHeight: 62,
                  titleSpacing: 16,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0.5,
                  shadowColor: const Color(0x1A17263C),
                  systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: AppColors.surface,
                    systemStatusBarContrastEnforced: false,
                  ),
                  title: SizedBox(
                    height: 40,
                    width: 168,
                    child: Image.asset(
                      'assets/logo.png',
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: openSettings,
                      tooltip: 'Impostazioni',
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
          body: SafeArea(
            child: useSidebar
                ? Row(
                    children: [
                      _HomeSidebar(
                        userName: userName,
                        appVersionLabel: _appVersionLabel,
                        navItems: navItems,
                        onOpenSettings: openSettings,
                        onLogout: widget.onLogout,
                        onVersionTap: _handleVersionTap,
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
            const SizedBox(height: AppSpacing.xxs),
            if (compact) ...[
              _mainMenu(navItems),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ),
            ] else
              _DesktopSummaryCard(
                notificationsCount: _unreadNotifications,
                onOpenNotifications: onOpenNotifications,
              ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleVersionTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    _appVersionLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainMenu(List<_HomeNavData> navItems) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Menu principale',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _menuModeSelector(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _menuMode == _HomeMenuMode.list
              ? Column(
                  key: const ValueKey(_HomeMenuMode.list),
                  children: navItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xs,
                          ),
                          child: _HomeMenuTile(item: item),
                        ),
                      )
                      .toList(),
                )
              : KeyedSubtree(
                  key: const ValueKey(_HomeMenuMode.grid),
                  child: _gridMenu(navItems),
                ),
        ),
      ],
    );
  }

  Widget _menuModeSelector() {
    return SegmentedButton<_HomeMenuMode>(
      key: const ValueKey('home-menu-mode-selector'),
      showSelectedIcon: false,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
        minimumSize: const WidgetStatePropertyAll(Size(44, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.cardOutline,
          ),
        ),
      ),
      segments: [
        ButtonSegment(
          value: _HomeMenuMode.list,
          tooltip: 'Elenco',
          icon: Semantics(
            label: 'Visualizzazione elenco',
            child: const Icon(Icons.view_list_rounded, size: 20),
          ),
        ),
        ButtonSegment(
          value: _HomeMenuMode.grid,
          tooltip: 'Griglia',
          icon: Semantics(
            label: 'Visualizzazione griglia',
            child: const Icon(Icons.grid_view_rounded, size: 19),
          ),
        ),
      ],
      selected: {_menuMode},
      onSelectionChanged: (selection) => _setMenuMode(selection.first),
    );
  }

  Widget _gridMenu(List<_HomeNavData> navItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns =
            constraints.maxWidth >= 340 && textScale <= 1.25 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: navItems
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _HomeGridTile(item: item),
                  ),
                )
                .toList(),
          );
        }
        final rows = <Widget>[];
        for (var index = 0; index < navItems.length; index += 2) {
          final second = index + 1;
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _HomeGridTile(item: navItems[index])),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: second < navItems.length
                          ? _HomeGridTile(item: navItems[second])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _hero(String userName) {
    String formatDate(String iso) {
      return formatItalianIsoDate(iso) ?? '-';
    }

    final prossimi = _dashboard.nextServices;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Buongiorno'
        : now.hour < 18
            ? 'Buon pomeriggio'
            : 'Buonasera';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: '$greeting, ',
            children: [
              TextSpan(
                text: userName,
                style: const TextStyle(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          _longItalianDate(now),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(
              Icons.sports_score_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.xs),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le tue prossime attività',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Race Control',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Aggiorna servizi',
              onPressed: _loadingDashboard || _refreshingDashboard
                  ? null
                  : () => unawaited(
                        _loadDashboard(
                          showLoading: false,
                          forceRefresh: true,
                        ),
                      ),
              icon: _refreshingDashboard
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_loadingDashboard)
          const AppCard(
            variant: AppCardVariant.outlined,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Caricamento delle prossime attività…'),
                ),
              ],
            ),
          )
        else if (_dashboardError != null)
          AppCard(
            variant: AppCardVariant.outlined,
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Impossibile caricare le prossime attività.'),
                ),
                TextButton(
                  onPressed: _refreshingDashboard
                      ? null
                      : () => unawaited(
                            _loadDashboard(
                              showLoading: false,
                              forceRefresh: true,
                            ),
                          ),
                  child: const Text('Riprova'),
                ),
              ],
            ),
          )
        else if (prossimi.isEmpty)
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nessuna designazione in programma',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Consulta il calendario per comunicare la tua disponibilità.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                  ),
                  onPressed: () => _openPage(
                    context,
                    GarePage(loggedUser: widget.loggedUser),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Vai al calendario'),
                ),
              ],
            ),
          )
        else if (prossimi.length == 1)
          _raceControlCard(prossimi.first, formatDate)
        else
          _raceControlCarousel(prossimi, formatDate),
      ],
    );
  }

  String _longItalianDate(DateTime date) {
    const weekdays = [
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica',
    ];
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }

  Widget _raceControlCarousel(
    List<Gara> prossimi,
    String Function(String) formatDate,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _raceControlCarouselHeight(
          context,
          prossimi,
          constraints.maxWidth,
        );
        return Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.swipe_rounded,
                  color: AppColors.textSecondary,
                  size: 17,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Scorri per vedere le altre gare',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${_raceControlIndex + 1}/${prossimi.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: height,
              child: PageView.builder(
                key: const ValueKey('race-control-carousel'),
                controller: _raceControlController,
                padEnds: false,
                itemCount: prossimi.length,
                onPageChanged: (index) {
                  setState(() => _raceControlIndex = index);
                },
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    right: index == prossimi.length - 1 ? 0 : AppSpacing.xs,
                  ),
                  child: _raceControlCard(prossimi[index], formatDate),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                prossimi.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _raceControlIndex ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _raceControlIndex
                        ? AppColors.primary
                        : const Color(0xFFBBD8F1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _raceControlCarouselHeight(
    BuildContext context,
    List<Gara> gare,
    double availableWidth,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final cardWidth =
        (availableWidth * 0.87) - AppSpacing.xs - 2 * AppSpacing.md;
    double textHeight(
      String text,
      TextStyle style, {
      double? maxWidth,
    }) {
      if (text.isEmpty) return 0;
      return (TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: (maxWidth ?? cardWidth).clamp(80, 680)))
          .height;
    }

    var tallestCard = 0.0;
    for (final gara in gare) {
      final metadata = [
        if (gara.sport.trim().isNotEmpty) gara.sport.trim(),
        if (gara.localita.trim().isNotEmpty) gara.localita.trim(),
      ].join(' · ');
      final dateHeight = textHeight(
        formatItalianIsoDate(gara.dataGara) ?? '-',
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        maxWidth: cardWidth - 19,
      );
      final titleHeight = textHeight(
        gara.titolo,
        const TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w700),
      );
      final metadataHeight = textHeight(
        metadata,
        const TextStyle(fontSize: 12),
      );
      final buttonLabelHeight = textHeight(
        'Apri dettagli gara',
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        maxWidth: cardWidth - 50,
      );
      final buttonHeight =
          (buttonLabelHeight + 16).clamp(44, double.infinity).toDouble();
      final cardHeight = 2 * AppSpacing.md +
          dateHeight +
          6 +
          titleHeight +
          6 +
          metadataHeight +
          AppSpacing.sm +
          buttonHeight;
      if (cardHeight > tallestCard) tallestCard = cardHeight;
    }
    final scaledControlAllowance = (textScaler.scale(1) - 1).clamp(0, 1) * 90;
    return tallestCard + AppSpacing.sm + scaledControlAllowance;
  }

  Widget _raceControlCard(Gara gara, String Function(String) formatDate) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  formatDate(gara.dataGara),
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            gara.titolo,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (gara.sport.trim().isNotEmpty) gara.sport.trim(),
              if (gara.localita.trim().isNotEmpty) gara.localita.trim(),
            ].join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
            ),
            onPressed: () => _openPage(
              context,
              DettaglioGara(
                gara: gara,
                loggedUser: widget.loggedUser,
                notionService: _notion,
              ),
            ),
            icon: const Icon(Icons.sports_score_rounded, size: 18),
            label: const Text('Apri dettagli gara'),
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

enum _HomeMenuMode { list, grid }

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
  final String appVersionLabel;
  final List<_HomeNavData> navItems;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final VoidCallback onVersionTap;

  const _HomeSidebar({
    required this.userName,
    required this.appVersionLabel,
    required this.navItems,
    required this.onOpenSettings,
    required this.onLogout,
    required this.onVersionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.cardOutline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17263C),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(
              'assets/logo.png',
              height: 52,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ciao, $userName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onOpenSettings,
                tooltip: 'Impostazioni',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Scegli una sezione dal menu.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onVersionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                appVersionLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                return _HomeMenuTile(item: navItems[index]);
              },
            ),
          ),
          const Divider(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              alignment: Alignment.centerLeft,
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
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
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: item.onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (item.badgeCount > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Badge.count(count: item.badgeCount),
          ],
          const SizedBox(width: AppSpacing.xxs),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _HomeGridTile extends StatelessWidget {
  final _HomeNavData item;

  const _HomeGridTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: item.onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 21),
              ),
              const Spacer(),
              if (item.badgeCount > 0) Badge.count(count: item.badgeCount),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              notificationsCount > 0
                  ? Icons.mark_email_unread_outlined
                  : Icons.dashboard_outlined,
              color:
                  notificationsCount > 0 ? AppColors.error : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  notificationsCount > 0
                      ? '$notificationsCount notifiche non lette'
                      : 'Usa il menu laterale per aprire le sezioni operative.',
                  style: TextStyle(
                    color: notificationsCount > 0
                        ? AppColors.error
                        : AppColors.textSecondary,
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
