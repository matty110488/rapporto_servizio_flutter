import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../services/push_notification_service.dart';
import '../utils/italian_date_formatter.dart';
import '../widgets/standard_app_bar_actions.dart';
import 'dettaglio_gara.dart';

class NotificationsPage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback? onNotificationsChanged;

  const NotificationsPage({
    super.key,
    required this.loggedUser,
    this.onNotificationsChanged,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  String _statusText = 'Controllo stato notifiche...';
  List<PushNotice> _notifications = const [];
  StreamSubscription<PushNotice>? _foregroundSubscription;
  Timer? _pollingTimer;
  late final NotionService _notion;

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _notion = NotionService(databaseId: AppConfig.currentRaceDatabaseId);
    _foregroundSubscription = foregroundPushNotices.listen((notice) {
      if (!mounted) return;
      setState(() {
        _notifications = [notice, ..._notifications].take(50).toList();
      });
      widget.onNotificationsChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${notice.title}: ${notice.body}')),
      );
      _loadNotifications(silent: true);
    });
    _loadAll();
    _pollingTimer =
        Timer.periodic(AppConfig.notificationsPageRefreshInterval, (_) {
      unawaited(_loadNotifications(silent: true));
    });
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadStatus(),
      _loadNotifications(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStatus() async {
    try {
      final permissionEnabled = await notificationsAreEnabled();
      final appEnabled = await pushNotificationsAppEnabled();
      if (!mounted) return;
      setState(() {
        _enabled = permissionEnabled && appEnabled;
        _statusText = _enabled
            ? 'Attive su questo dispositivo'
            : permissionEnabled
                ? 'Disattivate nell’app'
                : 'Non attive su questo dispositivo';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _statusText = 'Stato non leggibile su questo browser/dispositivo';
      });
    }
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    final userId = _loggedUserId;
    if (userId == null) return;
    try {
      final notifications = await fetchPushNotifications(userId);
      if (!mounted) return;
      setState(() => _notifications = notifications);
      if (notifications.any((notice) => !notice.read)) {
        await markPushNotificationsRead(userId);
        if (!mounted) return;
        setState(() {
          _notifications = _notifications
              .map(
                (notice) => PushNotice(
                  id: notice.id,
                  title: notice.title,
                  body: notice.body,
                  type: notice.type,
                  garaId: notice.garaId,
                  read: true,
                  receivedAt: notice.receivedAt,
                ),
              )
              .toList(growable: false);
        });
        widget.onNotificationsChanged?.call();
      }
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lettura notifiche non riuscita: $e')),
      );
    }
  }

  Future<void> _setEnabled(bool value) async {
    final userId = _loggedUserId;
    if (userId == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        await enableNotificationsForUser(userId);
      } else {
        await disableNotificationsForUser(userId);
      }
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _statusText =
            value ? 'Attive e registrate sul server' : 'Disattivate nell’app';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Notifiche attivate su questo dispositivo.'
              : 'Notifiche disattivate su questo dispositivo.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is PushNotificationSetupException
          ? e.userMessage
          : 'Operazione notifiche non riuscita: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteNotification(PushNotice notice) async {
    final userId = _loggedUserId;
    final id = notice.id;
    if (userId == null || id == null || id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await deletePushNotification(userId, id);
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.where((entry) => entry.id != id).toList();
      });
      widget.onNotificationsChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eliminazione notifica non riuscita: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGara(PushNotice notice) async {
    if (notice.garaId.isEmpty) return;
    try {
      final page = await _notion.retrievePage(notice.garaId);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apertura gara non riuscita: $e')),
      );
    }
  }

  String _formatTimestamp(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${formatItalianDate(value, includeYear: false)} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: standardAppBarActions(
          context,
          helpTitle: 'Notifiche',
          helpContent: HelpContent.notifiche,
          onRefresh: _loadAll,
          refreshEnabled: !_loading,
        ),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _settingsCard(),
                    const SizedBox(height: 14),
                    _historyHeader(),
                    const SizedBox(height: 8),
                    if (_notifications.isEmpty)
                      _emptyHistory()
                    else
                      ..._notifications.map(_notificationTile),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: Color(0xFF0A66C2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifiche push',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B40),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF49627E),
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            CupertinoSwitch(
              value: _enabled,
              activeTrackColor: const Color(0xFF007AFF),
              onChanged: _setEnabled,
            ),
        ],
      ),
    );
  }

  Widget _historyHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Notifiche ricevute',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B40),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _loadAll,
          icon: const Icon(Icons.refresh),
          label: const Text('Aggiorna'),
        ),
      ],
    );
  }

  Widget _emptyHistory() {
    return _card(
      child: const Text(
        'Nessuna notifica registrata. Le nuove notifiche compariranno qui anche se l’app era chiusa.',
        style: TextStyle(color: Color(0xFF49627E)),
      ),
    );
  }

  Widget _notificationTile(PushNotice notice) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: notice.garaId.isEmpty ? null : () => _openGara(notice),
          leading: const Icon(
            Icons.mark_email_unread_outlined,
            color: Color(0xFF0A66C2),
          ),
          title: Text(
            notice.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.body.isNotEmpty) Text(notice.body),
              const SizedBox(height: 4),
              Text(
                notice.garaId.isEmpty
                    ? _formatTimestamp(notice.receivedAt)
                    : '${_formatTimestamp(notice.receivedAt)} - Tocca per aprire la gara',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            tooltip: 'Elimina notifica',
            onPressed: _busy ? null : () => _deleteNotification(notice),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCE8F6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}
