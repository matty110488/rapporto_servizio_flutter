import 'package:flutter/material.dart';
import '../models/gara.dart';

class DettaglioGara extends StatelessWidget {
  final Gara gara;

  const DettaglioGara({super.key, required this.gara});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(gara.titolo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Data: ${gara.dataGara}"),
          Text("Luogo: ${gara.localita}"),
          Text("Sito: ${gara.sitoGara}"),
          Text("Sport: ${gara.sport}"),
          Text("Organizzatore: ${gara.organizzatore}"),
          Text("Tipologia: ${gara.tipologia}"),
          Divider(),
          Text("DSC: ${gara.dsc}", style: TextStyle(fontWeight: FontWeight.bold)),
          Divider(),
          Text("Kronos designati:"),
          for (final k in gara.kronosDesignati) Text("• $k"),
          Divider(),
          Text("PC Segreteria:"),
          for (final p in gara.pcSegreteria) Text("• $p"),
          Divider(),
          Text("Apparecchiature:"),
          for (final a in gara.apparecchiature) Text("• $a"),
          Divider(),
          Text("Status: ${gara.status}"),
        ],
      ),
    );
  }
}
