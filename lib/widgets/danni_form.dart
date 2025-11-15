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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Note / Malfunzionamenti",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          maxLines: 5,
          initialValue: note,
          onChanged: (val) => setState(() => note = val),
          decoration: const InputDecoration(
            labelText: "Scrivi qui eventuali problemi o osservazioni",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
