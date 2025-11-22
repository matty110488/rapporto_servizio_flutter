import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../constants/help_content.dart';
import '../widgets/help_dialog.dart';

class ArchivioScreen extends StatefulWidget {
  @override
  State<ArchivioScreen> createState() => _ArchivioScreenState();
}

class _ArchivioScreenState extends State<ArchivioScreen> {
  List<FileSystemEntity> files = [];

  @override
  void initState() {
    super.initState();
    caricaFiles();
  }

  Future<void> caricaFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final allFiles =
        dir.listSync().where((f) => f.path.endsWith('.pdf')).toList();
    setState(() {
      files = allFiles;
    });
  }

  Future<void> eliminaFile(File file) async {
    await file.delete();
    caricaFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Archivio PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Archivio',
              HelpContent.archivio,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Home'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: files.isEmpty
          ? Center(child: Text('Nessun PDF salvato.'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final nome = file.path.split('/').last;
                return ListTile(
                  title: Text(nome),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => eliminaFile(File(file.path)),
                  ),
                  onTap: () => OpenFile.open(file.path),
                );
              },
            ),
    );
  }
}
