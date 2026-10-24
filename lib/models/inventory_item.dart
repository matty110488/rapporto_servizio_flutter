class InventoryAttachment {
  const InventoryAttachment({required this.name, required this.url});

  final String name;
  final String url;
}

class InventoryItem {
  const InventoryItem({
    this.pageId,
    this.id = '',
    this.type = '',
    this.brand = '',
    this.model = '',
    this.serialNumber = '',
    this.ownership = 'NOSTRO',
    this.purchaseDate,
    this.lastMaintenanceDate,
    this.retired = false,
    this.notes = '',
    this.attachments = const [],
  });

  final String? pageId;
  final String id;
  final String type;
  final String brand;
  final String model;
  final String serialNumber;
  final String ownership;
  final DateTime? purchaseDate;
  final DateTime? lastMaintenanceDate;
  final bool retired;
  final String notes;
  final List<InventoryAttachment> attachments;

  String get displayName {
    final description =
        [brand, model].where((value) => value.isNotEmpty).join(' ');
    if (description.isNotEmpty) return description;
    return type.isNotEmpty ? type : 'Apparecchiatura $id';
  }

  factory InventoryItem.fromNotion(Map<String, dynamic> json) {
    final properties = Map<String, dynamic>.from(
      json['properties'] as Map? ?? const <String, dynamic>{},
    );

    Map<String, dynamic>? property(List<String> candidates) {
      String normalize(String value) =>
          value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final wanted = candidates.map(normalize).toSet();
      for (final entry in properties.entries) {
        if (wanted.contains(normalize(entry.key)) && entry.value is Map) {
          return Map<String, dynamic>.from(entry.value as Map);
        }
      }
      return null;
    }

    String text(Map<String, dynamic>? field) {
      if (field == null) return '';
      for (final key in const ['title', 'rich_text']) {
        final values = field[key];
        if (values is List) {
          final result = values
              .whereType<Map>()
              .map((item) => item['plain_text']?.toString() ?? '')
              .join()
              .trim();
          if (result.isNotEmpty) return result;
        }
      }
      final selected = field['select'] ?? field['status'];
      if (selected is Map && selected['name'] != null) {
        return selected['name'].toString().trim();
      }
      if (field['number'] != null) return field['number'].toString();
      final uniqueId = field['unique_id'];
      if (uniqueId is Map) {
        final prefix = uniqueId['prefix']?.toString() ?? '';
        final number = uniqueId['number']?.toString() ?? '';
        return '$prefix$number';
      }
      return '';
    }

    DateTime? date(Map<String, dynamic>? field) {
      final raw = field?['date'];
      return raw is Map
          ? DateTime.tryParse(raw['start']?.toString() ?? '')
          : null;
    }

    final fileField = property(const ['Documentazione', 'Documnetazione']);
    final rawFiles = fileField?['files'];
    final attachments = <InventoryAttachment>[];
    if (rawFiles is List) {
      for (final raw in rawFiles.whereType<Map>()) {
        final file = raw['file'];
        final external = raw['external'];
        final url = file is Map
            ? file['url']?.toString()
            : external is Map
                ? external['url']?.toString()
                : null;
        if (url != null && url.isNotEmpty) {
          attachments.add(
            InventoryAttachment(
              name: raw['name']?.toString() ?? 'Allegato',
              url: url,
            ),
          );
        }
      }
    }

    return InventoryItem(
      pageId: json['id']?.toString(),
      id: text(property(const ['ID'])),
      type: text(property(const ['Tipologia', 'Tipo'])),
      brand: text(property(const ['Marca'])),
      model: text(property(const ['Modello'])),
      serialNumber: text(property(const ['Numero seriale', 'Seriale'])),
      ownership: text(property(const ['Proprietà', 'Proprieta'])),
      purchaseDate: date(property(const ['Data acquisto'])),
      lastMaintenanceDate: date(
          property(const ['Data Ultima Manutenzione', 'Ultima manutenzione'])),
      retired: property(const ['Radiato'])?['checkbox'] == true,
      notes: text(property(const ['Note'])),
      attachments: attachments,
    );
  }

  Map<String, dynamic> toPayload() => {
        'type': type.trim(),
        'brand': brand.trim(),
        'model': model.trim(),
        'serialNumber': serialNumber.trim(),
        'ownership': ownership,
        'purchaseDate': _dateOnly(purchaseDate),
        'lastMaintenanceDate': _dateOnly(lastMaintenanceDate),
        'retired': retired,
        'notes': notes.trim(),
      };

  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

class InventoryData {
  const InventoryData({required this.items, this.typeOptions = const []});

  final List<InventoryItem> items;
  final List<String> typeOptions;
}
