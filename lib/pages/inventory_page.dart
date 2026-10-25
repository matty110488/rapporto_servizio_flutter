import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/inventory_item.dart';
import '../services/notion_service.dart';
import '../utils/notion_user.dart';
import '../widgets/standard_app_bar_actions.dart';

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
        actions: standardAppBarActions(
          context,
          helpTitle: 'Inventario apparecchiature',
          helpContent: HelpContent.inventario,
          onRefresh: _load,
          refreshEnabled: !_loading,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-inventory-item'),
        onPressed: _loading ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildBody(items),
          ),
        ),
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
    final allItems = _data?.items ?? const <InventoryItem>[];
    final retired = allItems.where((item) => item.retired).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 980 ? 28.0 : 16.0;
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 96),
          children: [
            _InventoryHeader(
              total: allItems.length,
              active: allItems.length - retired,
              retired: retired,
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Cerca nell’inventario',
                    hintText: 'ID, tipologia, marca, modello o seriale',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _query.trim().isEmpty
                        ? 'Tutte le apparecchiature'
                        : 'Risultati della ricerca',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: Color(0xFF52657B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const _InventoryEmptyView()
            else if (columns == 1)
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InventoryCard(
                    item: item,
                    onTap: () => _openEditor(item),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 148,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) => _InventoryCard(
                  item: items[index],
                  onTap: () => _openEditor(items[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.total,
    required this.active,
    required this.retired,
  });

  final int total;
  final int active;
  final int retired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B70), Color(0xFF0A66C2)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A66C2),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Parco apparecchiature',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Consulta disponibilità, proprietà e stato degli strumenti.',
            style: TextStyle(color: Color(0xFFDCEBFA), fontSize: 15),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderMetric(label: 'Totali', value: total),
              _HeaderMetric(label: 'In servizio', value: active),
              _HeaderMetric(label: 'Radiati', value: retired),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InventoryEmptyView extends StatelessWidget {
  const _InventoryEmptyView();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nessuna apparecchiatura trovata',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Modifica la ricerca oppure aggiungi un nuovo strumento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF52657B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final numericId = item.id.replaceAll(RegExp(r'[^0-9]'), '');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE8F6)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  numericId.isEmpty ? '—' : numericId,
                  style: TextStyle(
                    color: primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        item.type,
                        if (item.serialNumber.isNotEmpty)
                          'S/N ${item.serialNumber}',
                      ].where((value) => value.isNotEmpty).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF52657B)),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _InventoryBadge(label: item.ownership),
                        if (item.retired)
                          const _InventoryBadge(
                            label: 'RADIATO',
                            warning: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryBadge extends StatelessWidget {
  const _InventoryBadge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFB3261E) : const Color(0xFF176B42);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
            : 'Modifica apparecchiatura'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                  children: [
                    if (widget.item?.id.isNotEmpty == true) ...[
                      _InventoryIdBanner(id: widget.item!.id),
                      const SizedBox(height: 14),
                    ],
                    _FormSection(
                      icon: Icons.precision_manufacturing_rounded,
                      title: 'Dati apparecchiatura',
                      subtitle: 'Identificazione e caratteristiche principali',
                      children: [
                        if (options.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: options.contains(_type.text)
                                ? _type.text
                                : null,
                            decoration:
                                const InputDecoration(labelText: 'Tipologia *'),
                            items: options
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) => _type.text = value ?? '',
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Seleziona una tipologia'
                                    : null,
                          )
                        else
                          TextFormField(
                            controller: _type,
                            decoration:
                                const InputDecoration(labelText: 'Tipologia *'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Inserisci la tipologia'
                                    : null,
                          ),
                        const SizedBox(height: 12),
                        _field(_brand, 'Marca'),
                        const SizedBox(height: 12),
                        _field(_model, 'Modello'),
                        const SizedBox(height: 12),
                        _field(_serial, 'Numero seriale'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Gestione',
                      subtitle: 'Proprietà, date e stato dello strumento',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _ownership,
                          decoration:
                              const InputDecoration(labelText: 'Proprietà'),
                          items: const [
                            DropdownMenuItem(
                                value: 'FICR', child: Text('FICR')),
                            DropdownMenuItem(
                                value: 'NOSTRO', child: Text('NOSTRO')),
                          ],
                          onChanged: (value) =>
                              setState(() => _ownership = value ?? 'NOSTRO'),
                        ),
                        const SizedBox(height: 8),
                        _dateTile(
                            'Data acquisto',
                            _purchaseDate,
                            dateFormat,
                            () => _pickDate(false),
                            () => setState(() => _purchaseDate = null)),
                        const Divider(height: 1),
                        _dateTile(
                            'Data ultima manutenzione',
                            _maintenanceDate,
                            dateFormat,
                            () => _pickDate(true),
                            () => setState(() => _maintenanceDate = null)),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Radiato'),
                          subtitle: const Text(
                              'Attiva solo se lo strumento non è più in servizio'),
                          value: _retired,
                          onChanged: (value) =>
                              setState(() => _retired = value),
                        ),
                        const SizedBox(height: 8),
                        _field(_notes, 'Note', maxLines: 4),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      icon: Icons.folder_copy_rounded,
                      title: 'Documentazione',
                      subtitle: 'Foto, fatture e documenti dello strumento',
                      children: [
                        if (widget.item?.attachments.isNotEmpty == true)
                          ...widget.item!.attachments.map((file) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.description_outlined),
                                title: Text(file.name),
                                trailing: const Icon(Icons.open_in_new_rounded),
                                onTap: () => launchUrl(Uri.parse(file.url),
                                    mode: LaunchMode.externalApplication),
                              )),
                        ..._pending.indexed.map((entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.cloud_upload_outlined),
                              title: Text(entry.$2.name),
                              subtitle: const Text('Pronto per il caricamento'),
                              trailing: IconButton(
                                tooltip: 'Rimuovi',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _pending.removeAt(entry.$1)),
                              ),
                            )),
                        if (widget.item?.attachments.isEmpty != false &&
                            _pending.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              'Nessun documento allegato.',
                              style: TextStyle(color: Color(0xFF52657B)),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text('Scatta foto')),
                            OutlinedButton.icon(
                                onPressed: _pickPhotos,
                                icon: const Icon(Icons.photo_library_rounded),
                                label: const Text('Galleria')),
                            OutlinedButton.icon(
                                onPressed: _pickDocuments,
                                icon: const Icon(Icons.attach_file_rounded),
                                label: const Text('Documento')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 10,
        child: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 788),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('save-inventory-item'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label:
                      Text(_saving ? 'Salvataggio…' : 'Salva apparecchiatura'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
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

class _InventoryIdBanner extends StatelessWidget {
  const _InventoryIdBanner({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag_rounded, color: primary),
          const SizedBox(width: 10),
          const Text(
            'Identificativo inventario',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            id,
            style: TextStyle(
              color: primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF52657B),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PendingAttachment {
  const _PendingAttachment(this.name, this.contentType, this.bytes);
  final String name;
  final String contentType;
  final List<int> bytes;
}
