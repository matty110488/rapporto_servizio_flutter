import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/inventory_item.dart';

void main() {
  test('reads inventory fields and attachments from a Notion page', () {
    final item = InventoryItem.fromNotion({
      'id': 'page-1',
      'properties': {
        'ID': {
          'type': 'unique_id',
          'unique_id': {'prefix': 'INV-', 'number': 12},
        },
        'Tipologia': {
          'select': {'name': 'Fotocellula'},
        },
        'Marca': {
          'rich_text': [
            {'plain_text': 'Acme'},
          ],
        },
        'Modello': {
          'title': [
            {'plain_text': 'Fast 2'},
          ],
        },
        'Proprietà': {
          'select': {'name': 'FICR'},
        },
        'Data acquisto': {
          'date': {'start': '2026-01-20'},
        },
        'Radiato': {'checkbox': true},
        'Documnetazione': {
          'files': [
            {
              'name': 'fattura.pdf',
              'file': {'url': 'https://example.test/fattura.pdf'},
            }
          ],
        },
      },
    });

    expect(item.pageId, 'page-1');
    expect(item.id, 'INV-12');
    expect(item.type, 'Fotocellula');
    expect(item.displayName, 'Acme Fast 2');
    expect(item.ownership, 'FICR');
    expect(item.purchaseDate, DateTime(2026, 1, 20));
    expect(item.retired, isTrue);
    expect(item.attachments.single.name, 'fattura.pdf');
  });

  test('serializes editable inventory values', () {
    final payload = InventoryItem(
      type: 'Cronometro',
      ownership: 'NOSTRO',
      purchaseDate: DateTime(2025, 3, 4),
      retired: false,
    ).toPayload();

    expect(payload['type'], 'Cronometro');
    expect(payload['purchaseDate'], '2025-03-04');
    expect(payload['retired'], isFalse);
  });
}
