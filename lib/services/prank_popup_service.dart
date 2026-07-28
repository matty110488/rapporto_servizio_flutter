import 'dart:math';

import 'package:flutter/material.dart';

class PrankPopupService {
  static final Random _random = Random();
  static DateTime? _lastShownAt;

  static const Duration _minInterval = Duration(seconds: 45);
  static const Duration _checkeredFlagDuration = Duration(milliseconds: 2400);
  static const Set<String> _targetUsernames = {};
  static const List<String> _targetNameFragments = [];
  static const String _legendaryModeTitle =
      'Modalità cronometrista leggendario';
  static const String _checkeredFlagMessage =
      'Keep timing, keep racing! 🏁\n\nHai appena sbloccato la bandiera a scacchi!';
  static const List<String> _phrases = [
    "Se lo rifai, dovrai cronometrare con una cipolla. Di Tropea.",
    "Master o Rei?",
    "Sei un cronometrista leggendario, ma non dimenticare di respirare!",
    "Hai appena sbloccato la bandiera a scacchi! 🏁",
    "Keep timing, keep racing! 🏁",
    "Ma sei sicuro di voler continuare a cronometrare? Potresti diventare un cronometrista leggendario!",
    "Chi ha bisogno di un cronometrista leggendario quando ci sei tu? Continua così!",
    "CHi te lo fa fare di cronometrare così bene? Sei un cronometrista leggendario!",
  ];

  static void showLegendaryMode(BuildContext context) {
    final phrase = _phrases[_random.nextInt(_phrases.length)];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.emoji_events_outlined, size: 38),
        title: const Text(_legendaryModeTitle),
        content: Text(phrase),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tempo preso!'),
          ),
        ],
      ),
    );
  }

  static void showCheckeredFlag(BuildContext context) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    var removed = false;

    void removeEntry() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: removeEntry,
          child: ColoredBox(
            color: const Color(0x55000000),
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                tween: Tween(begin: 0.75, end: 1),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value.clamp(0, 1), child: child),
                ),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_score,
                        size: 64,
                        color: Color(0xFF0A66C2),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _checkeredFlagMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1A2B40),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(_checkeredFlagDuration, removeEntry);
  }

  static bool isPrankUser(Map<String, dynamic> loggedUser) {
    final name = _extractName(loggedUser).toLowerCase().trim();
    final username = _extractUsername(loggedUser).toLowerCase().trim();
    return _targetUsernames.contains(username) ||
        _targetNameFragments.any(name.contains);
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
