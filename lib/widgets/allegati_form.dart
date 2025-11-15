import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AllegatiForm extends StatefulWidget {
  const AllegatiForm({Key? key}) : super(key: key);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Allegati (foto)", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < immagini.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(immagini[i].path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => rimuoviFoto(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            GestureDetector(
              onTap: aggiungiFoto,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
