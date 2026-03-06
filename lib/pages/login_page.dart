import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
  String? errorMsg;

  late AuthService auth;

  @override
  void initState() {
    super.initState();
    auth = AuthService(
      apiKey: "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",
      cronometristiDbId: "2afde089ef9580a0ad6dd2b6155384ed",
    );
  }

  Future<void> doLogin() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    final user = await auth.login(
      userCtrl.text.trim(),
      passCtrl.text.trim(),
    );
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
                decoration: InputDecoration(labelText: "Username"),
              ),
              SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: "Password"),
              ),
              SizedBox(height: 24),
              if (loading)
                Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: doLogin,
                  child: Text("Accedi"),
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
