import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/pages/expense_estimate_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeNotionService extends NotionService {
  _FakeNotionService() : super(databaseId: 'test');

  Map<String, dynamic>? submittedReport;

  @override
  Future<Map<String, dynamic>> calculateExpenseEstimate({
    required Map<String, dynamic> report,
  }) async {
    submittedReport = report;
    return {
      'tariffVersion': 'FICr-2026-04-01',
      'total': 150.0,
      'requiresManualReview': false,
      'warnings': <String>[],
      'race': {
        'title': 'Preventivo',
        'sport': 'Corsa',
        'startDate': '2026-08-01',
        'endDate': '2026-08-01',
        'location': '',
      },
      'totalsByCategory': {'personnel': 100, 'organization': 50},
      'lines': [
        {
          'category': 'organization',
          'label': 'Contributo organizzativo · Corsa',
          'date': '',
          'quantity': 1,
          'unit': 'giorni',
          'unitRate': 50,
          'amount': 50,
        },
      ],
    };
  }
}

Map<String, dynamic> _admin() => {
      'id': 'admin-1',
      'properties': {
        'ADMIN': {'checkbox': true},
      },
    };

void main() {
  testWidgets('an admin can calculate an expense estimate', (tester) async {
    final notion = _FakeNotionService();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseEstimatePage(
          loggedUser: _admin(),
          notionService: notion,
        ),
      ),
    );

    expect(find.text('Preventivi'), findsOneWidget);
    expect(find.text('Personale e trasferta'), findsOneWidget);
    await tester.ensureVisible(find.text('Calcola preventivo'));
    await tester.tap(find.text('Calcola preventivo'));
    await tester.pumpAndSettle();

    expect(notion.submittedReport, isNotNull);
    expect(find.text('TOTALE PREVENTIVO'), findsOneWidget);
    expect(find.textContaining('150,00'), findsOneWidget);
    expect(find.text('Simulazione non salvata in Notion'), findsOneWidget);
  });

  testWidgets('the estimate page is hidden from non-admin users',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseEstimatePage(
          loggedUser: const {'id': 'user-1', 'properties': {}},
          notionService: _FakeNotionService(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Sezione riservata agli amministratori.'),
      findsOneWidget,
    );
  });
}
