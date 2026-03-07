import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AllegatiForm extends StatefulWidget {
  const AllegatiForm({super.key});

  @override
  AllegatiFormState createState() => AllegatiFormState();
}

class AllegatiFormState extends State<AllegatiForm> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> immagini = [];

  List<XFile> getImages() => immagini;

  Future<void> aggiungiFoto() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta una foto'),
              onTap: () async {
                Navigator.pop(context);
                final foto = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 75);
                if (foto != null) {
                  setState(() => immagini.add(foto));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleziona dalla galleria'),
              onTap: () async {
                Navigator.pop(context);
                final scelte = await _picker.pickMultiImage(imageQuality: 75);
                if (scelte.isNotEmpty) {
                  setState(() => immagini.addAll(scelte));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void rimuoviFoto(int index) {
    setState(() => immagini.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Allegati (foto)", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Aggiungi allegati",
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.25)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < immagini.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(immagini[i].path),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => rimuoviFoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              GestureDetector(
                onTap: aggiungiFoto,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded,
                          color: colorScheme.primary.withOpacity(0.8)),
                      const SizedBox(height: 6),
                      Text(
                        "Aggiungi",
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
