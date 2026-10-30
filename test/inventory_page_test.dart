import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/inventory_item.dart';
import 'package:rapporto_servizio/pages/inventory_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeInventoryService extends NotionService {
  _FakeInventoryService() : super(databaseId: 'test');

  String? deletedPageId;

  @override
  Future<void> deleteInventoryItem(String pageId) async {
    deletedPageId = pageId;
  }

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
            ficrCode: 'FICR-44',
            status: 'Funzionante',
            ownership: 'FICR',
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
    expect(find.text('Funzionante'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-type-filter')), findsOneWidget);
    expect(find.byIcon(Icons.category_rounded), findsWidgets);
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
    await tester.ensureVisible(find.text('Acme Fast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Fast'));
    await tester.pumpAndSettle();

    expect(find.text('Identificativo inventario'), findsOneWidget);
    expect(find.text('Dati apparecchiatura'), findsOneWidget);
    expect(find.text('Codice FICR'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-inventory-item')), findsOneWidget);
    expect(find.text('Gestione'), findsNothing);
    expect(find.byKey(const ValueKey('Proprietà-FICR')), findsOneWidget);
    expect(find.byKey(const ValueKey('Stato-Funzionante')), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('Proprietà-NOSTRO'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('Proprietà-NOSTRO')));
    await tester.pumpAndSettle();
    expect(find.text('Codice FICR'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('Proprietà-FICR')));
    await tester.pumpAndSettle();
    expect(find.text('Codice FICR'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Documentazione'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Documentazione'), findsOneWidget);
    expect(find.text('Salva apparecchiatura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters inventory by equipment type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          loggedUser: _adminUser(),
          notionService: _FakeInventoryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('inventory-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotocellula').last);
    await tester.pumpAndSettle();

    expect(find.text('Acme Fast'), findsNothing);
    expect(find.text('Timing Beam'), findsOneWidget);
    expect(find.text('Risultati filtrati'), findsOneWidget);
  });

  testWidgets('deletes an inventory item after confirmation', (tester) async {
    final service = _FakeInventoryService();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          loggedUser: _adminUser(),
          notionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Acme Fast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Fast'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-inventory-item')));
    await tester.pumpAndSettle();
    expect(find.text('Cancellare l’apparecchiatura?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancella'));
    await tester.pumpAndSettle();

    expect(service.deletedPageId, 'page-1');
    expect(find.text('Inventario apparecchiature'), findsOneWidget);
  });
}
