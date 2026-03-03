import 'package:flutter/material.dart';

class DanniForm extends StatefulWidget {
  const DanniForm({Key? key}) : super(key: key);

  @override
  DanniFormState createState() => DanniFormState();
}

class DanniFormState extends State<DanniForm> {
  String note = '';

  String getData() => note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Note / Malfunzionamenti",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Annota eventuali problemi/malfunzionamenti o note di servizio.",
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.25)),
          ),
          child: TextFormField(
            maxLines: 5,
            initialValue: note,
            onChanged: (val) => setState(() => note = val),
            decoration: InputDecoration(
              labelText: "Scrivi qui eventuali problemi o osservazioni",
              alignLabelWithHint: true,
              filled: true,
              fillColor: colorScheme.surface.withOpacity(0.95),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
