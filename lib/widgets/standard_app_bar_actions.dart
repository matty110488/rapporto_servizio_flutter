import 'dart:async';

import 'package:flutter/material.dart';

import 'help_dialog.dart';

List<Widget> standardAppBarActions(
  BuildContext context, {
  required String helpTitle,
  required List<String> helpContent,
  required FutureOr<void> Function() onRefresh,
  FutureOr<void> Function()? onHome,
  bool refreshEnabled = true,
}) {
  return [
    IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Aiuto',
      onPressed: () => showHelpDialog(
        context,
        helpTitle,
        helpContent,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Aggiorna',
      onPressed: refreshEnabled
          ? () async {
              await onRefresh();
            }
          : null,
    ),
    TextButton.icon(
      onPressed: () async {
        if (onHome != null) {
          await onHome();
        } else if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      icon: const Icon(Icons.home),
      label: const Text('Home'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
    ),
  ];
}
