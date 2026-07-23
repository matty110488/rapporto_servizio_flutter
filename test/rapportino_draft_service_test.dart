import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/pages/service_reports_page.dart';
import 'package:rapporto_servizio/services/rapportino_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lists local drafts for the current user newest first', () async {
    final service = RapportinoDraftService();
    await service.saveDraft('gara-1', {
      'title': 'Gara uno',
      'dateLabel': '12/08/2026',
      'primaryGaraId': 'gara-1',
      'wholePackage': false,
      'userId': 'user-a',
      'updatedAt': '2026-08-12T10:00:00.000',
      'gara': {'nome': 'Gara uno'},
    });
    await service.saveDraft('package:42', {
      'title': 'Meeting alpino',
      'dateLabel': '13/08/2026, 14/08/2026',
      'primaryGaraId': 'gara-2',
      'wholePackage': true,
      'userId': 'user-a',
      'updatedAt': '2026-08-13T11:00:00.000',
      'gara': {'nome': 'Meeting alpino', 'data': '2026-08-13'},
    });
    await service.saveDraft('gara-other', {
      'title': 'Altra gara',
      'userId': 'user-b',
      'updatedAt': '2026-08-14T11:00:00.000',
    });

    final drafts = await service.listDrafts(userId: 'user-a');

    expect(drafts, hasLength(2));
    expect(drafts.first.draftId, 'package:42');
    expect(drafts.first.primaryGaraId, 'gara-2');
    expect(drafts.first.wholePackage, isTrue);
    expect(drafts.first.raceYear, 2026);
  });

  test('deletes a local draft', () async {
    final service = RapportinoDraftService();
    await service.saveDraft('gara-1', {
      'title': 'Gara uno',
      'userId': 'user-a',
      'updatedAt': '2026-08-12T10:00:00.000',
    });

    await service.deleteDraft('gara-1');

    expect(await service.loadDraft('gara-1'), isNull);
    expect(await service.listDrafts(userId: 'user-a'), isEmpty);
  });

  testWidgets('service reports hub exposes the three clear entry points',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ServiceReportsPage(loggedUser: {'id': 'user-a'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nuovo rapportino'), findsOneWidget);
    expect(find.text('Le mie bozze'), findsOneWidget);
    expect(find.text('Archivio inviati'), findsOneWidget);
  });
}
