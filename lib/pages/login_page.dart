import 'package:flutter/material.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../widgets/stopwatch_loading.dart';

class LoginPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool biometricLoginEnabled = true;
  String? errorMsg;

  late AuthService auth;

  @override
  void initState() {
    super.initState();
    auth = AuthService();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final enabled = await AppPreferencesService.loadBiometricLoginEnabled();
    if (!mounted) return;
    setState(() => biometricLoginEnabled = enabled);
  }

  Future<void> doLogin() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    Map<String, dynamic>? user;
    try {
      final identifier = userCtrl.text.trim();
      user = identifier.contains('@')
          ? await auth.loginWithFirebase(identifier, passCtrl.text)
          : await auth.login(identifier, passCtrl.text);
    } catch (_) {
      user = null;
    }
    if (!mounted) return;

    if (user == null) {
      setState(() {
        loading = false;
        errorMsg = "Credenziali errate";
      });
      return;
    }

    widget.onLogin(user); // restituisco l'utente alla app
  }

  Future<void> _showFirstAccess() async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Primo accesso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Inserisci lo username e la stessa email registrata in segreteria.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
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
    if (submitted != true || !mounted) {
      usernameCtrl.dispose();
      emailCtrl.dispose();
      return;
    }
    final username = usernameCtrl.text;
    final email = emailCtrl.text;
    usernameCtrl.dispose();
    emailCtrl.dispose();
    setState(() => loading = true);
    try {
      await auth.startFirstAccess(username, email);
      if (!mounted) return;
      _showInfo(
        'Controlla la tua email',
        'Se username ed email coincidono con i dati registrati, riceverai un link per scegliere la tua password.'
            'NB: verifica nella cartella SPAM / Posta Indesiderata se non hai ricevuto la mail',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMsg = 'Servizio momentaneamente non disponibile.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password dimenticata'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
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
    final email = emailCtrl.text;
    emailCtrl.dispose();
    if (submitted != true || !mounted) return;
    try {
      await auth.sendPasswordReset(email);
    } catch (_) {
      // The message stays generic to avoid revealing registered accounts.
    }
    if (!mounted) return;
    _showInfo(
      'Controlla la posta',
      'Se l’indirizzo è registrato, riceverai un link per scegliere una nuova password.'
          'NB: verifica nella cartella SPAM / Posta Indesiderata se non hai ricevuto la mail',
    );
  }

  Future<void> _showInfo(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> doPasskeyLogin() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final user = await auth.loginWithPasskey();
      if (!mounted) return;
      widget.onLogin(user);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg =
            'Accesso biometrico non riuscito. Puoi usare username e password.';
      });
    }
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login Cronometristi")),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 24),
              TextField(
                controller: userCtrl,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: "Password"),
              ),
              SizedBox(height: 24),
              if (loading)
                const Center(
                    child: StopwatchLoading(label: 'Accesso in corso...'))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: doLogin,
                      child: const Text('Accedi'),
                    ),
                    if (biometricLoginEnabled) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: doPasskeyLogin,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Accedi con Face ID o impronta'),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _showFirstAccess,
                      child:
                          const Text('Primo accesso: scegli la tua password'),
                    ),
                    TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text('Password dimenticata?'),
                    ),
                  ],
                ),
              if (errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    errorMsg!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
