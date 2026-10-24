import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/inventory_item.dart';
import 'package:rapporto_servizio/pages/inventory_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeInventoryService extends NotionService {
  _FakeInventoryService() : super(databaseId: 'test');

  @override
  Future<InventoryData> fetchInventory() async => InventoryData(
        typeOptions: const ['Cronometro', 'Fotocellula'],
        items: [
          InventoryItem(
            pageId: 'page-1',
            id: 'INV-12',
            type: 'Cronometro',
            brand: 'Acme',
            model: 'Fast',
            serialNumber: 'ABC123',
            ownership: 'NOSTRO',
            purchaseDate: DateTime(2025, 4, 10),
          ),
          const InventoryItem(
            pageId: 'page-2',
            id: 'INV-13',
            type: 'Fotocellula',
            brand: 'Timing',
            model: 'Beam',
            ownership: 'FICR',
            retired: true,
          ),
        ],
      );
}

Map<String, dynamic> _adminUser() => {
      'id': 'admin-1',
      'properties': {
        'ADMIN': {'checkbox': true},
      },
    };

void main() {
  testWidgets('inventory follows the app layout on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          loggedUser: _adminUser(),
          notionService: _FakeInventoryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parco apparecchiature'), findsOneWidget);
    expect(find.text('In servizio  1'), findsOneWidget);
    expect(find.text('Radiati  1'), findsOneWidget);
    expect(find.text('Acme Fast'), findsOneWidget);
    expect(find.byTooltip('Aiuto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor uses grouped cards consistent with the app',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          loggedUser: _adminUser(),
          notionService: _FakeInventoryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Fast'));
    await tester.pumpAndSettle();

    expect(find.text('Identificativo inventario'), findsOneWidget);
    expect(find.text('Dati apparecchiatura'), findsOneWidget);
    expect(find.text('Gestione'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Documentazione'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Documentazione'), findsOneWidget);
    expect(find.text('Salva apparecchiatura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
