import 'dart:math';

import 'package:flutter/material.dart';

class PrankPopupService {
  static final Random _random = Random();
  static DateTime? _lastShownAt;

  static const Duration _minInterval = Duration(seconds: 45);
  static const List<String> _phrases = [
    "Senti un po'...eh....ci siete su voi al Palu per la gara?",
    "Ueee ciao sono Valentino, sabato faccio na gara. Ci sei?",
    "Mi prendo 7 Master e 3 ReiPro per andare al Fanoni, non si sa mai.",
    "Mi fai na birra?",
    "Poccod.....",
    "Voglio la camera a Madesimo.",
    "Sondrio - Bormio: 230km + mancato pasto",
  ];

  static bool isPrankUser(Map<String, dynamic> loggedUser) {
    final name = _extractName(loggedUser).toLowerCase().trim();
    final username = _extractUsername(loggedUser).toLowerCase().trim();
    return name.contains('jacopo') || username == 'jacopo';
  }

  static void maybeShow(BuildContext context, Map<String, dynamic> loggedUser) {
    if (!isPrankUser(loggedUser)) return;

    final now = DateTime.now();
    final last = _lastShownAt;
    if (last != null && now.difference(last) < _minInterval) return;
    if (_random.nextDouble() > 0.65) return;

    final delay = Duration(seconds: 2 + _random.nextInt(6));
    Future<void>.delayed(delay, () {
      if (!context.mounted) return;

      final nowAfterDelay = DateTime.now();
      final lastAfterDelay = _lastShownAt;
      if (lastAfterDelay != null &&
          nowAfterDelay.difference(lastAfterDelay) < _minInterval) {
        return;
      }

      _lastShownAt = nowAfterDelay;
      final phrase = _phrases[_random.nextInt(_phrases.length)];
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Comunicazione di servizio - Prestare attenzione!'),
          content: Text(phrase),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    });
  }

  static String _extractUsername(Map<String, dynamic> loggedUser) {
    final username = loggedUser['username'];
    if (username is String) return username;
    final user = loggedUser['user'];
    if (user is String) return user;
    return '';
  }

  static String _extractName(Map<String, dynamic> loggedUser) {
    final props = loggedUser['properties'];
    if (props is! Map<String, dynamic>) return '';

    for (final value in props.values) {
      if (value is! Map<String, dynamic>) continue;
      final type = value['type'];
      if (type == 'title') {
        final list = value['title'] as List<dynamic>? ?? const [];
        if (list.isNotEmpty) {
          final first = list.first;
          if (first is Map<String, dynamic>) {
            final plain = first['plain_text'];
            if (plain is String && plain.isNotEmpty) return plain;
          }
        }
      }
      if (type == 'rich_text') {
        final list = value['rich_text'] as List<dynamic>? ?? const [];
        if (list.isNotEmpty) {
          final first = list.first;
          if (first is Map<String, dynamic>) {
            final plain = first['plain_text'];
            if (plain is String && plain.isNotEmpty) return plain;
          }
        }
      }
    }
    return '';
  }
}
