import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../models/gara.dart';
import '../services/app_update_exception.dart';
import '../services/app_update_service.dart';
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

@immutable
class HomeWelcomePhoto {
  final String assetName;
  final Alignment alignment;

  const HomeWelcomePhoto({
    required this.assetName,
    this.alignment = Alignment.center,
  });
}

const _defaultWelcomePhotos = <HomeWelcomePhoto>[
  HomeWelcomePhoto(
    assetName: 'assets/home-valtellina-header.webp',
    alignment: Alignment.centerLeft,
  ),
  HomeWelcomePhoto(assetName: 'assets/sci-piste.webp'),
  HomeWelcomePhoto(assetName: 'assets/panorama-inverno.webp'),
  HomeWelcomePhoto(
    assetName: 'assets/gara-sci.webp',
    alignment: Alignment(0, -0.35),
  ),
];

class HomePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;
  final NotionService? notionService;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenDesignations;
  final VoidCallback? onOpenReports;
  final bool showDesktopSidebar;
  @visibleForTesting
  final int initialUnreadNotifications;
  @visibleForTesting
  final List<PushNotice>? initialNotifications;
  @visibleForTesting
  final List<HomeWelcomePhoto> welcomePhotos;
  @visibleForTesting
  final Duration welcomePhotoInterval;
  @visibleForTesting
  final Duration welcomePhotoFadeDuration;

  const HomePage({
    super.key,
    required this.loggedUser,
    required this.onLogout,
    this.notionService,
    this.onOpenCalendar,
    this.onOpenDesignations,
    this.onOpenReports,
    this.showDesktopSidebar = true,
    this.initialUnreadNotifications = 0,
    this.initialNotifications,
    this.welcomePhotos = _defaultWelcomePhotos,
    this.welcomePhotoInterval = const Duration(seconds: 7),
    this.welcomePhotoFadeDuration = const Duration(milliseconds: 800),
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
  List<PushNotice> _notifications = const [];
  bool _notificationsLoaded = false;
  bool _loadingNotifications = true;
  late final PageController _raceControlController;
  int _raceControlIndex = 0;
  Timer? _dashboardRefreshTimer;
  Timer? _notificationPollingTimer;
  Timer? _versionTapResetTimer;
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();
    _raceControlController = PageController(viewportFraction: 0.87);
    _unreadNotifications = widget.initialUnreadNotifications;
    _notifications = widget.initialNotifications ?? const [];
    _notificationsLoaded = widget.initialNotifications != null;
    _loadingNotifications = widget.initialNotifications == null;
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

  void _openCalendar() {
    final callback = widget.onOpenCalendar;
    if (callback != null) {
      callback();
      return;
    }
    _openPage(context, GarePage(loggedUser: widget.loggedUser));
  }

  void _openDesignations() {
    final callback = widget.onOpenDesignations;
    if (callback != null) {
      callback();
      return;
    }
    _openPage(context, DesignazioniPage(loggedUser: widget.loggedUser));
  }

  void _openReports() {
    final callback = widget.onOpenReports;
    if (callback != null) {
      callback();
      return;
    }
    _openPage(context, ServiceReportsPage(loggedUser: widget.loggedUser));
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
        _notifications = notifications;
        _unreadNotifications =
            notifications.where((notice) => !notice.read).length;
        _notificationsLoaded = true;
        _loadingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNotifications = false);
      // Silent: notification refresh must not block the home page.
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
      _openCalendar();
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
        onTap: _openCalendar,
      ),
      _HomeNavData(
        icon: Icons.assignment_turned_in,
        label: 'Le tue designazioni',
        subtitle: 'Vedi servizi assegnati e conclusi',
        onTap: _openDesignations,
      ),
      _HomeNavData(
        icon: Icons.assignment,
        label: 'Rapporti di Servizio',
        subtitle: 'Nuovi rapportini, bozze e archivio inviati',
        onTap: _openReports,
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
        final desktopLayout = constraints.maxWidth >= 900;
        final useSidebar = desktopLayout && widget.showDesktopSidebar;
        return Scaffold(
          appBar: desktopLayout
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
                          onOpenNotifications: notificationItem.onTap,
                        ),
                      ),
                    ],
                  )
                : _homeContent(
                    userName: userName,
                    onOpenNotifications: notificationItem.onTap,
                  ),
          ),
        );
      },
    );
  }

  Widget _homeContent({
    required String userName,
    required VoidCallback onOpenNotifications,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            _welcomePanorama(userName),
            const SizedBox(height: AppSpacing.lg),
            _raceControlSection(),
            const SizedBox(height: AppSpacing.lg),
            _identityBanner(),
            const SizedBox(height: AppSpacing.lg),
            _notificationsPreview(onOpenNotifications),
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

  Widget _welcomePanorama(String userName) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Buongiorno'
        : now.hour < 18
            ? 'Buon pomeriggio'
            : 'Buonasera';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = textScale > 1.2 ? 220.0 : 186.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: SizedBox(
        key: const ValueKey('home-alpine-panorama'),
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _HomePhotoCarousel(
              photos: widget.welcomePhotos,
              rotationInterval: widget.welcomePhotoInterval,
              fadeDuration: widget.welcomePhotoFadeDuration,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                key: ValueKey('home-welcome-photo-overlay'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF5F8FCFF),
                      Color(0xCFEAF4FC),
                      Color(0x42FFFFFF),
                      Color(0x0AFFFFFF),
                    ],
                    stops: [0, 0.36, 0.72, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: '$greeting, ',
                      children: [
                        TextSpan(
                          text: userName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _longItalianDate(now),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _raceControlSection() {
    String formatDate(String iso) {
      return formatItalianIsoDate(iso) ?? '-';
    }

    final prossimi = _dashboard.nextServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  onPressed: _openCalendar,
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

  Widget _identityBanner() {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = textScale > 1.2 ? 340.0 : 190.0;
    return Semantics(
      label: 'Cronometristi Valtellinesi. Precisione, Servizio, Passione.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: SizedBox(
          key: const ValueKey('home-identity-banner'),
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(painter: _HomeIdentityBannerPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Cronometristi\nValtellinesi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 0.95,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.7,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'PRECISIONE · SERVIZIO · PASSIONE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.05,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: const [
                        _TricolorSegment(color: Color(0xFF168451)),
                        _TricolorSegment(color: Colors.white),
                        _TricolorSegment(color: Color(0xFFDC2626)),
                      ],
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

  Widget _notificationsPreview(VoidCallback onOpenNotifications) {
    final latest = _notifications.isEmpty ? null : _notifications.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.xs),
            const Expanded(
              child: Text(
                'Notifiche',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenNotifications,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              label: const Text('Vedi tutte'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_loadingNotifications)
          const AppCard(
            variant: AppCardVariant.outlined,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Caricamento notifiche…')),
              ],
            ),
          )
        else if (latest != null)
          AppCard(
            key: const ValueKey('home-notification-preview'),
            variant: AppCardVariant.outlined,
            onTap: onOpenNotifications,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: latest.read
                        ? AppColors.primarySoft
                        : const Color(0xFFE5F6EC),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(
                    latest.read
                        ? Icons.notifications_none_rounded
                        : Icons.mark_email_unread_rounded,
                    color: latest.read ? AppColors.primary : AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              latest.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: latest.read
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!latest.read) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Badge(label: Text('Nuova')),
                          ],
                        ],
                      ),
                      if (latest.body.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          latest.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _notificationDate(latest.receivedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          )
        else if (_notificationsLoaded)
          AppCard(
            variant: AppCardVariant.outlined,
            onTap: onOpenNotifications,
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Al momento non ci sono notifiche da mostrare.'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _notificationDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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

class _TricolorSegment extends StatelessWidget {
  const _TricolorSegment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 34, height: 4, color: color);
  }
}

class _HomePhotoCarousel extends StatefulWidget {
  final List<HomeWelcomePhoto> photos;
  final Duration rotationInterval;
  final Duration fadeDuration;

  const _HomePhotoCarousel({
    required this.photos,
    required this.rotationInterval,
    required this.fadeDuration,
  }) : assert(photos.length > 0);

  @override
  State<_HomePhotoCarousel> createState() => _HomePhotoCarouselState();
}

class _HomePhotoCarouselState extends State<_HomePhotoCarousel>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  final Set<String> _preparedAssets = <String>{};
  Timer? _rotationTimer;
  int _currentIndex = 0;
  bool _isVisible = true;
  bool _reduceMotion = false;
  bool _appIsActive = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isVisible = TickerMode.of(context);
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _restartRotationTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareNextPhoto();
    });
  }

  @override
  void didUpdateWidget(covariant _HomePhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.photos, widget.photos)) {
      _currentIndex = 0;
      _preparedAssets.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
        _prepareNextPhoto();
      });
    }
    _restartRotationTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _restartRotationTimer();
  }

  void _restartRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    if (widget.photos.length < 2 ||
        !_isVisible ||
        !_appIsActive ||
        _reduceMotion) {
      return;
    }
    _rotationTimer = Timer(widget.rotationInterval, _showNextPhoto);
  }

  void _showNextPhoto() {
    if (!mounted) return;
    final nextIndex = (_currentIndex + 1) % widget.photos.length;
    _selectPhoto(nextIndex);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(nextIndex);
    }
  }

  void _selectPhoto(int index) {
    if (!mounted || index == _currentIndex) {
      _restartRotationTimer();
      return;
    }
    setState(() => _currentIndex = index);
    _prepareNextPhoto();
    _restartRotationTimer();
  }

  void _prepareNextPhoto() {
    if (!mounted || widget.photos.length < 2) return;
    final nextIndex = (_currentIndex + 1) % widget.photos.length;
    final assetName = widget.photos[nextIndex].assetName;
    if (!_preparedAssets.add(assetName)) return;
    unawaited(
      precacheImage(
        AssetImage(assetName),
        context,
        onError: (_, __) => _preparedAssets.remove(assetName),
      ),
    );
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];
    final effectiveFadeDuration =
        _reduceMotion ? Duration.zero : widget.fadeDuration;

    return Stack(
      key: const ValueKey('home-photo-carousel'),
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedSwitcher(
            duration: effectiveFadeDuration,
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: SizedBox.expand(
              key: ValueKey(photo.assetName),
              child: Image.asset(
                photo.assetName,
                key: ValueKey('home-welcome-photo-$_currentIndex'),
                fit: BoxFit.cover,
                alignment: photo.alignment,
                filterQuality: FilterQuality.high,
                semanticLabel:
                    'Panorama Valtellina ${_currentIndex + 1} di ${widget.photos.length}',
                errorBuilder: (context, error, stackTrace) => const CustomPaint(
                  painter: _HomeAlpinePanoramaPainter(),
                ),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          PageView.builder(
            key: const ValueKey('home-photo-swipe-area'),
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: _selectPhoto,
            itemBuilder: (context, index) => const SizedBox.expand(),
          ),
        if (widget.photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (index) {
                  final selected = index == _currentIndex;
                  return AnimatedContainer(
                    key: ValueKey('home-photo-indicator-$index'),
                    duration: effectiveFadeDuration,
                    width: selected ? 15 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(99),
                      border: selected
                          ? null
                          : Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeAlpinePanoramaPainter extends CustomPainter {
  const _HomeAlpinePanoramaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF9FCFF),
            Color(0xFFEAF4FD),
            Color(0xFFD7EAF9),
          ],
        ).createShader(bounds),
    );

    void mountainLayer({
      required double baseline,
      required Color color,
      required List<Offset> peaks,
    }) {
      final path = Path()..moveTo(0, baseline);
      for (final peak in peaks) {
        path.lineTo(size.width * peak.dx, size.height * peak.dy);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    mountainLayer(
      baseline: size.height * 0.72,
      color: const Color(0x66C7DFF3),
      peaks: const [
        Offset(0.08, 0.68),
        Offset(0.24, 0.47),
        Offset(0.34, 0.61),
        Offset(0.50, 0.30),
        Offset(0.61, 0.54),
        Offset(0.76, 0.22),
        Offset(0.88, 0.49),
        Offset(1, 0.33),
      ],
    );
    mountainLayer(
      baseline: size.height * 0.82,
      color: const Color(0x889ABFDD),
      peaks: const [
        Offset(0.00, 0.76),
        Offset(0.17, 0.61),
        Offset(0.30, 0.72),
        Offset(0.45, 0.49),
        Offset(0.58, 0.69),
        Offset(0.73, 0.43),
        Offset(0.86, 0.66),
        Offset(1.00, 0.51),
      ],
    );
    mountainLayer(
      baseline: size.height,
      color: const Color(0xB06E9BC1),
      peaks: const [
        Offset(0.00, 0.86),
        Offset(0.20, 0.73),
        Offset(0.36, 0.82),
        Offset(0.55, 0.66),
        Offset(0.70, 0.80),
        Offset(0.88, 0.62),
        Offset(1.00, 0.72),
      ],
    );

    final mistBounds =
        Rect.fromLTWH(0, size.height * 0.54, size.width, size.height * 0.46);
    canvas.drawRect(
      mistBounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xB8F5FAFF)],
        ).createShader(mistBounds),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeAlpinePanoramaPainter oldDelegate) => false;
}

class _HomeIdentityBannerPainter extends CustomPainter {
  const _HomeIdentityBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064A78), Color(0xFF0875B8), Color(0xFF68B4E4)],
        ).createShader(bounds),
    );

    final rear = Path()
      ..moveTo(0, size.height * 0.62)
      ..lineTo(size.width * 0.16, size.height * 0.42)
      ..lineTo(size.width * 0.28, size.height * 0.57)
      ..lineTo(size.width * 0.45, size.height * 0.27)
      ..lineTo(size.width * 0.58, size.height * 0.53)
      ..lineTo(size.width * 0.74, size.height * 0.32)
      ..lineTo(size.width * 0.88, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.39)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(rear, Paint()..color = const Color(0xA8D7ECF8));

    final valley = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.58,
        size.width * 0.52,
        size.height * 0.79,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.60,
        size.width,
        size.height * 0.70,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(valley, Paint()..color = const Color(0xCC315F79));

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xB3073154), Color(0x20073154)],
          stops: [0, 0.78],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeIdentityBannerPainter oldDelegate) => false;
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
