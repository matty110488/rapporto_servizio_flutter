import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/inventory_item.dart';
import '../services/notion_service.dart';
import '../utils/notion_user.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.loggedUser,
    this.notionService,
  });

  final Map<String, dynamic> loggedUser;
  final NotionService? notionService;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final NotionService _notion;
  InventoryData? _data;
  Object? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _notion = widget.notionService ??
        NotionService(databaseId: AppConfig.currentRaceDatabaseId);
    if (isNotionAdmin(widget.loggedUser)) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _notion.fetchInventory();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([InventoryItem? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryEditorPage(
          item: item,
          typeOptions: _data?.typeOptions ?? const [],
          notionService: _notion,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNotionAdmin(widget.loggedUser)) {
      return const Scaffold(
        body: Center(child: Text('Sezione riservata agli amministratori.')),
      );
    }
    final normalizedQuery = _query.trim().toLowerCase();
    final items = (_data?.items ?? const <InventoryItem>[]).where((item) {
      if (normalizedQuery.isEmpty) return true;
      return [item.id, item.type, item.brand, item.model, item.serialNumber]
          .join(' ')
          .toLowerCase()
          .contains(normalizedQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario apparecchiature'),
        actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-inventory-item'),
        onPressed: _loading ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(items),
      ),
    );
  }

  Widget _buildBody(List<InventoryItem> items) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52),
          const SizedBox(height: 12),
          Text('Impossibile caricare l’inventario.\n$_error',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
              child:
                  FilledButton(onPressed: _load, child: const Text('Riprova'))),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Cerca per ID, tipo, marca, modello o seriale',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Nessuna apparecchiatura trovata.',
                textAlign: TextAlign.center),
          )
        else
          ...items.map((item) =>
              _InventoryCard(item: item, onTap: () => _openEditor(item))),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(item.id.isEmpty
              ? '–'
              : item.id.replaceAll(RegExp(r'[^0-9]'), '')),
        ),
        title: Text(item.displayName),
        subtitle: Text([
          item.type,
          if (item.serialNumber.isNotEmpty) 'S/N ${item.serialNumber}',
          item.ownership,
        ].where((value) => value.isNotEmpty).join(' • ')),
        trailing: item.retired
            ? const Tooltip(
                message: 'Radiato', child: Icon(Icons.block, color: Colors.red))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class InventoryEditorPage extends StatefulWidget {
  const InventoryEditorPage({
    super.key,
    this.item,
    required this.typeOptions,
    required this.notionService,
  });

  final InventoryItem? item;
  final List<String> typeOptions;
  final NotionService notionService;

  @override
  State<InventoryEditorPage> createState() => _InventoryEditorPageState();
}

class _InventoryEditorPageState extends State<InventoryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _type;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _notes;
  late String _ownership;
  DateTime? _purchaseDate;
  DateTime? _maintenanceDate;
  bool _retired = false;
  bool _saving = false;
  String? _savedPageId;
  final List<_PendingAttachment> _pending = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _savedPageId = item?.pageId;
    _type = TextEditingController(text: item?.type ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _model = TextEditingController(text: item?.model ?? '');
    _serial = TextEditingController(text: item?.serialNumber ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _ownership = item?.ownership == 'FICR' ? 'FICR' : 'NOSTRO';
    _purchaseDate = item?.purchaseDate;
    _maintenanceDate = item?.lastMaintenanceDate;
    _retired = item?.retired ?? false;
  }

  @override
  void dispose() {
    _type.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool maintenance) async {
    final current = maintenance ? _maintenanceDate : _purchaseDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (maintenance) {
        _maintenanceDate = selected;
      } else {
        _purchaseDate = selected;
      }
    });
  }

  Future<void> _takePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    _addPending(photo.name, 'image/jpeg', bytes);
  }

  Future<void> _pickPhotos() async {
    final photos = await _imagePicker.pickMultiImage(
      imageQuality: 72,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    for (final photo in photos) {
      _addPending(
          photo.name, _contentType(photo.name), await photo.readAsBytes());
    }
  }

  Future<void> _pickDocuments() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'webp'
      ],
    );
    for (final file in files) {
      final bytes = await file.readAsBytes();
      _addPending(file.name, _contentType(file.name), bytes);
    }
  }

  void _addPending(String name, String contentType, List<int> bytes) {
    if (!mounted) return;
    if (bytes.length > AppConfig.maxInventoryAttachmentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name supera il limite di 4,5 MB.')),
      );
      return;
    }
    setState(() => _pending.add(_PendingAttachment(name, contentType, bytes)));
  }

  String _contentType(String filename) {
    switch (filename.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.notionService.saveInventoryItem(
        InventoryItem(
          pageId: _savedPageId,
          id: widget.item?.id ?? '',
          type: _type.text,
          brand: _brand.text,
          model: _model.text,
          serialNumber: _serial.text,
          ownership: _ownership,
          purchaseDate: _purchaseDate,
          lastMaintenanceDate: _maintenanceDate,
          retired: _retired,
          notes: _notes.text,
        ),
      );
      _savedPageId = saved.pageId;
      for (final attachment in _pending) {
        await widget.notionService.uploadInventoryAttachment(
          pageId: saved.pageId!,
          filename: attachment.name,
          contentType: attachment.contentType,
          bytes: attachment.bytes,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final options =
        {...widget.typeOptions, if (_type.text.isNotEmpty) _type.text}.toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.item == null
              ? 'Nuova apparecchiatura'
              : 'Modifica apparecchiatura')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (widget.item?.id.isNotEmpty == true)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ID'),
                  subtitle: Text(widget.item!.id)),
            if (options.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: options.contains(_type.text) ? _type.text : null,
                decoration: const InputDecoration(
                    labelText: 'Tipologia *', border: OutlineInputBorder()),
                items: options
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => _type.text = value ?? '',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Seleziona una tipologia'
                    : null,
              )
            else
              TextFormField(
                controller: _type,
                decoration: const InputDecoration(
                    labelText: 'Tipologia *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Inserisci la tipologia'
                    : null,
              ),
            const SizedBox(height: 12),
            _field(_brand, 'Marca'),
            const SizedBox(height: 12),
            _field(_model, 'Modello'),
            const SizedBox(height: 12),
            _field(_serial, 'Numero seriale'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ownership,
              decoration: const InputDecoration(
                  labelText: 'Proprietà', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'FICR', child: Text('FICR')),
                DropdownMenuItem(value: 'NOSTRO', child: Text('NOSTRO')),
              ],
              onChanged: (value) =>
                  setState(() => _ownership = value ?? 'NOSTRO'),
            ),
            const SizedBox(height: 12),
            _dateTile(
                'Data acquisto',
                _purchaseDate,
                dateFormat,
                () => _pickDate(false),
                () => setState(() => _purchaseDate = null)),
            _dateTile(
                'Data ultima manutenzione',
                _maintenanceDate,
                dateFormat,
                () => _pickDate(true),
                () => setState(() => _maintenanceDate = null)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Radiato'),
              subtitle:
                  const Text('Attiva solo se lo strumento è stato radiato'),
              value: _retired,
              onChanged: (value) => setState(() => _retired = value),
            ),
            _field(_notes, 'Note', maxLines: 4),
            const SizedBox(height: 20),
            Text('Documentazione',
                style: Theme.of(context).textTheme.titleMedium),
            if (widget.item?.attachments.isNotEmpty == true)
              ...widget.item!.attachments.map((file) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(file.name),
                    onTap: () => launchUrl(Uri.parse(file.url),
                        mode: LaunchMode.externalApplication),
                  )),
            ..._pending.indexed.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.upload_file),
                  title: Text(entry.$2.name),
                  subtitle: const Text('Da caricare'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _pending.removeAt(entry.$1)),
                  ),
                )),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scatta foto')),
                OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galleria')),
                OutlinedButton.icon(
                    onPressed: _pickDocuments,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Documento')),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const ValueKey('save-inventory-item'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_saving ? 'Salvataggio…' : 'Salva'),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _dateTile(String label, DateTime? value, DateFormat format,
      VoidCallback pick, VoidCallback clear) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(value == null ? 'Non impostata' : format.format(value)),
      trailing: value == null
          ? null
          : IconButton(onPressed: clear, icon: const Icon(Icons.close)),
      onTap: pick,
    );
  }
}

class _PendingAttachment {
  const _PendingAttachment(this.name, this.contentType, this.bytes);
  final String name;
  final String contentType;
  final List<int> bytes;
}
