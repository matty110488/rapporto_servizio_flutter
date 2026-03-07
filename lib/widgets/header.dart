import 'package:flutter/material.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/logo.png',
          height: 100,
          errorBuilder: (context, error, stack) => const Icon(
            Icons.timer,
            size: 80,
            color: Color(0xFF003366),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Rapporto di Servizio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
        Text(
          'ASD Cronometristi Valtellinesi',
          style: TextStyle(fontSize: 16),
        ),
        Divider(thickness: 2, height: 32),
      ],
    );
  }
}
