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
      cronometristiDbId: "29ade089ef9580899f56f9afb8352470",
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
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(labelText: "Username"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),
            SizedBox(height: 20),
            if (loading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: doLogin,
                child: Text("Accedi"),
              ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(errorMsg!, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
