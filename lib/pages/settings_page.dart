import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_environment.dart';
import '../services/app_preferences_service.dart';
import '../services/app_update_service.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback? onNotificationsChanged;

  const SettingsPage({
    super.key,
    required this.loggedUser,
    this.onNotificationsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _biometricEnabled = false;
  bool _notificationBusy = false;
  bool _biometricBusy = false;
  bool _appUpdateBusy = false;
  String _appVersion = '';

  String? get _userId {
    final id = widget.loggedUser['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var notificationsEnabled = false;
    var biometricEnabled =
        await AppPreferencesService.loadBiometricLoginEnabled();
    var appVersion = '';
    try {
      if (appUpdateSupported) {
        appVersion = currentAppVersionLabel;
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
        if (packageInfo.buildNumber.trim().isNotEmpty) {
          appVersion += ' (${packageInfo.buildNumber})';
        }
      }
    } catch (_) {
      appVersion = '';
    }
    try {
      notificationsEnabled = await pushNotificationsAppEnabled() &&
          await notificationsAreEnabled();
    } catch (_) {
      notificationsEnabled = false;
    }
    try {
      biometricEnabled = await AuthService().passkeysEnabled();
      await AppPreferencesService.saveBiometricLoginEnabled(
        biometricEnabled,
      );
    } catch (_) {
      // Mantiene la preferenza locale se lo stato remoto non è disponibile.
    }
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _biometricEnabled = biometricEnabled;
      _appVersion = appVersion;
      _loading = false;
    });
  }

  Future<void> _updateApp() async {
    if (_appUpdateBusy) return;
    setState(() => _appUpdateBusy = true);
    try {
      await forceAppUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _appUpdateBusy = false);
      _showMessage('Non è stato possibile aggiornare l’app. Riprova tra poco.');
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    final userId = _userId;
    if (userId == null || _notificationBusy) return;
    setState(() => _notificationBusy = true);
    try {
      if (enabled) {
        await enableNotificationsForUser(userId);
      } else {
        await disableNotificationsForUser(userId);
      }
      if (!mounted) return;
      setState(() => _notificationsEnabled = enabled);
      widget.onNotificationsChanged?.call();
      _showMessage(
        enabled ? 'Notifiche attivate.' : 'Notifiche disattivate.',
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is PushNotificationSetupException
          ? error.userMessage
          : 'Non è stato possibile aggiornare le notifiche.';
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    if (_biometricBusy) return;
    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disattivare Face ID?'),
          content: const Text(
            'Le passkey associate all’account verranno rimosse. Potrai '
            'riattivare l’accesso biometrico in qualsiasi momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disattiva'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _biometricBusy = true);
    try {
      if (enabled) {
        await AuthService().registerPasskey();
      } else {
        await AuthService().disablePasskeys();
      }
      await AppPreferencesService.saveBiometricLoginEnabled(enabled);
      if (!mounted) return;
      setState(() => _biometricEnabled = enabled);
      _showMessage(
        enabled
            ? 'Accesso con Face ID o impronta attivato.'
            : 'Accesso biometrico disattivato.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        enabled
            ? 'Non è stato possibile attivare l’accesso biometrico.'
            : 'Non è stato possibile disattivare l’accesso biometrico.',
      );
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  String _savedEmail() {
    final firebaseEmail =
        FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (firebaseEmail.isNotEmpty) return firebaseEmail;
    final properties = widget.loggedUser['properties'];
    if (properties is! Map) return '';
    for (final key in const ['EMAIL', 'E-MAIL', 'MAIL']) {
      final field = properties[key];
      if (field is! Map) continue;
      final email = field['email'];
      if (email is String && email.trim().isNotEmpty) return email.trim();
      final items = field['rich_text'];
      if (items is List) {
        final text = items
            .whereType<Map>()
            .map((item) => item['plain_text']?.toString() ?? '')
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController(text: _savedEmail());
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambia password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riceverai un link sicuro per scegliere una nuova password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Invia email'),
          ),
        ],
      ),
    );
    final email = controller.text.trim();
    controller.dispose();
    if (send != true || !mounted) return;
    if (!email.contains('@')) {
      _showMessage('Inserisci un indirizzo email valido.');
      return;
    }
    try {
      await AuthService().sendPasswordReset(email);
      if (!mounted) return;
      _showMessage('Email inviata. Controlla anche la cartella Spam.');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Se l’indirizzo è registrato, riceverai un link per cambiare password.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Preferenze'),
                Card(
                  child: Column(
                    children: [
                      _switchTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifiche',
                        subtitle: 'Avvisi per designazioni e aggiornamenti',
                        value: _notificationsEnabled,
                        busy: _notificationBusy,
                        onChanged: _setNotifications,
                      ),
                      const Divider(height: 1),
                      _switchTile(
                        icon: Icons.fingerprint,
                        title: 'Face ID / impronta',
                        subtitle: 'Accesso rapido protetto dal dispositivo',
                        value: _biometricEnabled,
                        busy: _biometricBusy,
                        onChanged: _setBiometric,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Sicurezza'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Cambia password'),
                    subtitle:
                        const Text('Ricevi il link di modifica via email'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: _changePassword,
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Applicazione'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.info_outline_rounded),
                          title: Text(appDisplayName),
                          subtitle: Text(
                            _appVersion.isEmpty
                                ? 'Versione non disponibile'
                                : 'Versione $_appVersion',
                          ),
                        ),
                        if (appUpdateSupported)
                          FilledButton.icon(
                            key: const ValueKey('update-app-button'),
                            onPressed: _appUpdateBusy ? null : _updateApp,
                            icon: _appUpdateBusy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.system_update_alt_rounded),
                            label: Text(
                              _appUpdateBusy
                                  ? 'Aggiornamento…'
                                  : 'Aggiorna app',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool busy,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CupertinoSwitch(
              value: value,
              activeTrackColor: const Color(0xFF007AFF),
              onChanged: onChanged,
            ),
    );
  }
}
