import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/notion_user.dart';
import '../widgets/app_ui.dart';
import 'admin_dashboard_page.dart';
import 'designazioni_page.dart';
import 'gare_page.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'service_reports_page.dart';
import 'settings_page.dart';
import 'statistiche_page.dart';

enum MainNavigationSection {
  home,
  calendar,
  designations,
  reports,
  more,
}

typedef MainSectionBuilder = Widget Function(
  MainNavigationSection section,
  ValueChanged<MainNavigationSection> onSelectSection,
);

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.loggedUser,
    required this.onLogout,
    this.initialSection = MainNavigationSection.home,
    this.sectionBuilder,
  });

  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;
  final MainNavigationSection initialSection;
  @visibleForTesting
  final MainSectionBuilder? sectionBuilder;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const _desktopBreakpoint = 900.0;

  late MainNavigationSection _selectedSection;
  late final List<Widget?> _sections;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _sections = List<Widget?>.filled(MainNavigationSection.values.length, null);
    _ensureSection(_selectedSection);
  }

  void _ensureSection(MainNavigationSection section) {
    final index = section.index;
    _sections[index] ??= widget.sectionBuilder?.call(section, _selectSection) ??
        _buildDefaultSection(section);
  }

  void _selectSection(MainNavigationSection section) {
    if (_selectedSection == section) return;
    setState(() {
      _ensureSection(section);
      _selectedSection = section;
    });
  }

  Widget _buildDefaultSection(MainNavigationSection section) {
    switch (section) {
      case MainNavigationSection.home:
        return HomePage(
          loggedUser: widget.loggedUser,
          onLogout: widget.onLogout,
          showDesktopSidebar: false,
          onOpenCalendar: () => _selectSection(MainNavigationSection.calendar),
          onOpenDesignations: () =>
              _selectSection(MainNavigationSection.designations),
          onOpenReports: () => _selectSection(MainNavigationSection.reports),
        );
      case MainNavigationSection.calendar:
        return GarePage(
          loggedUser: widget.loggedUser,
          onOpenHome: () => _selectSection(MainNavigationSection.home),
        );
      case MainNavigationSection.designations:
        return DesignazioniPage(
          loggedUser: widget.loggedUser,
          onOpenHome: () => _selectSection(MainNavigationSection.home),
        );
      case MainNavigationSection.reports:
        return ServiceReportsPage(
          loggedUser: widget.loggedUser,
          onOpenHome: () => _selectSection(MainNavigationSection.home),
        );
      case MainNavigationSection.more:
        return MorePage(
          loggedUser: widget.loggedUser,
          onLogout: widget.onLogout,
        );
    }
  }

  List<Widget> _stackChildren() {
    return List<Widget>.generate(_sections.length, (index) {
      final page = _sections[index] ?? const SizedBox.shrink();
      return TickerMode(
        enabled: index == _selectedSection.index,
        child: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _selectedSection == MainNavigationSection.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedSection != MainNavigationSection.home) {
          _selectSection(MainNavigationSection.home);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useSidebar = constraints.maxWidth >= _desktopBreakpoint;
          final content = IndexedStack(
            index: _selectedSection.index,
            children: _stackChildren(),
          );

          return Scaffold(
            body: useSidebar
                ? SafeArea(
                    child: Row(
                      children: [
                        _MainNavigationSidebar(
                          selectedSection: _selectedSection,
                          onSelectSection: _selectSection,
                          loggedUser: widget.loggedUser,
                          onLogout: widget.onLogout,
                        ),
                        Expanded(child: content),
                      ],
                    ),
                  )
                : content,
            bottomNavigationBar: useSidebar
                ? null
                : _MainBottomNavigation(
                    selectedSection: _selectedSection,
                    onSelectSection: _selectSection,
                  ),
          );
        },
      ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData({
    required this.section,
    required this.icon,
    required this.label,
  });

  final MainNavigationSection section;
  final IconData icon;
  final String label;
}

const _mainDestinations = [
  _NavigationDestinationData(
    section: MainNavigationSection.home,
    icon: Icons.home_rounded,
    label: 'Home',
  ),
  _NavigationDestinationData(
    section: MainNavigationSection.calendar,
    icon: Icons.calendar_month_rounded,
    label: 'Calendario',
  ),
  _NavigationDestinationData(
    section: MainNavigationSection.designations,
    icon: Icons.assignment_turned_in_rounded,
    label: 'Designazioni',
  ),
  _NavigationDestinationData(
    section: MainNavigationSection.reports,
    icon: Icons.description_rounded,
    label: 'Rapportini',
  ),
  _NavigationDestinationData(
    section: MainNavigationSection.more,
    icon: Icons.more_horiz_rounded,
    label: 'Altro',
  ),
];

class _MainBottomNavigation extends StatelessWidget {
  const _MainBottomNavigation({
    required this.selectedSection,
    required this.onSelectSection,
  });

  final MainNavigationSection selectedSection;
  final ValueChanged<MainNavigationSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('main-bottom-navigation'),
      color: AppColors.surface,
      elevation: 3,
      shadowColor: const Color(0x1A17263C),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: SizedBox(
          key: const ValueKey('main-navigation-destinations'),
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final destination in _mainDestinations)
                Expanded(
                  child: _BottomNavigationDestination(
                    data: destination,
                    selected: selectedSection == destination.section,
                    onTap: () => onSelectSection(destination.section),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationDestination extends StatelessWidget {
  const _BottomNavigationDestination({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavigationDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: Tooltip(
        message: data.label,
        child: InkWell(
          key: ValueKey('main-navigation-${data.section.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: AppSpacing.xxs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Icon(
                    data.icon,
                    size: 22,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.1,
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

class _MainNavigationSidebar extends StatelessWidget {
  const _MainNavigationSidebar({
    required this.selectedSection,
    required this.onSelectSection,
    required this.loggedUser,
    required this.onLogout,
  });

  final MainNavigationSection selectedSection;
  final ValueChanged<MainNavigationSection> onSelectSection;
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(loggedUser: loggedUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = extractNotionUserName(loggedUser);
    return Container(
      key: const ValueKey('main-navigation-sidebar'),
      width: 268,
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
                onPressed: () => _openSettings(context),
                tooltip: 'Impostazioni',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: ListView.separated(
              itemCount: _mainDestinations.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final destination = _mainDestinations[index];
                final selected = destination.section == selectedSection;
                return AppCard(
                  variant: AppCardVariant.outlined,
                  onTap: () => onSelectSection(destination.section),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: Icon(
                          destination.icon,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          destination.label,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
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

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.loggedUser,
    required this.onLogout,
  });

  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_MoreEntry>[
      _MoreEntry(
        icon: Icons.insights_rounded,
        title: 'Statistiche',
        subtitle: 'Consulta i dati sui servizi e sulle designazioni.',
        onTap: () => _open(
          context,
          StatistichePage(loggedUser: loggedUser),
        ),
      ),
      _MoreEntry(
        icon: Icons.notifications_rounded,
        title: 'Notifiche',
        subtitle: 'Visualizza comunicazioni e aggiornamenti.',
        onTap: () => _open(
          context,
          NotificationsPage(loggedUser: loggedUser),
        ),
      ),
      _MoreEntry(
        icon: Icons.settings_rounded,
        title: 'Impostazioni',
        subtitle: 'Gestisci notifiche, aggiornamenti e preferenze.',
        onTap: () => _open(
          context,
          SettingsPage(loggedUser: loggedUser),
        ),
      ),
      if (isNotionAdmin(loggedUser))
        _MoreEntry(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Centro di controllo Admin',
          subtitle: 'Accedi alle funzioni riservate agli amministratori.',
          onTap: () => _open(
            context,
            AdminDashboardPage(loggedUser: loggedUser),
          ),
        ),
      _MoreEntry(
        icon: Icons.logout_rounded,
        title: 'Logout',
        subtitle: 'Esci in modo sicuro dal tuo account.',
        onTap: onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Altro'),
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return AppCard(
              variant: AppCardVariant.outlined,
              onTap: entry.onTap,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(entry.icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          entry.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
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
            );
          },
        ),
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
