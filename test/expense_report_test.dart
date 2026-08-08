import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/expense_report.dart';
import 'package:rapporto_servizio/pages/expense_reports_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeNotionService extends NotionService {
  _FakeNotionService(this.rows) : super(databaseId: 'test');

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchAdminExpenseReports() async => rows;
}

Map<String, dynamic> _snapshot() => {
      'racePageId': 'race-1',
      'tariffVersion': 'ficr-2026',
      'total': 123.45,
      'requiresManualReview': false,
      'warnings': <String>[],
      'race': {
        'title': 'Meeting di prova',
        'sport': 'Nuoto',
        'startDate': '2026-08-01',
        'endDate': '2026-08-01',
        'location': 'Sondrio',
      },
      'totalsByCategory': {'personnel': 123.45},
      'lines': <Map<String, dynamic>>[],
    };

void main() {
  test('parses a frozen expense snapshot', () {
    final report = ExpenseReportSnapshot.fromJson({
      'racePageId': 'race-1',
      'tariffVersion': 'ficr-2026',
      'total': 123.45,
      'requiresManualReview': true,
      'warnings': ['Verificare Rally'],
      'race': {
        'title': 'Gara test',
        'sport': 'Rally',
        'startDate': '2026-08-01',
        'endDate': '2026-08-02',
        'location': 'Sondrio',
      },
      'totalsByCategory': {'personnel': 100, 'travel': 23.45},
      'lines': [
        {
          'category': 'personnel',
          'label': 'Indennità ordinaria',
          'date': '2026-08-01',
          'quantity': 5,
          'unit': 'ore',
          'amount': 36,
        },
      ],
    });

    expect(report.title, 'Gara test');
    expect(report.total, 123.45);
    expect(report.requiresManualReview, isTrue);
    expect(report.lines.single.amount, 36);
  });

  testWidgets('shows expense summaries to administrators', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseReportsPage(
          loggedUser: const {
            'id': 'admin-1',
            'properties': {
              'ADMIN': {'checkbox': true},
            },
          },
          notionService: _FakeNotionService([_snapshot()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Note spese'), findsOneWidget);
    expect(find.text('Meeting di prova'), findsOneWidget);
    expect(find.textContaining('123,45'), findsWidgets);
  });

  testWidgets('blocks the expense page for non-admin users', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseReportsPage(
          loggedUser: const {'id': 'user-1', 'properties': {}},
          notionService: _FakeNotionService(const []),
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
