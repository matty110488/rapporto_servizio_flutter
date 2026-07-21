import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/designation_role.dart';
import 'package:rapporto_servizio/models/gara.dart';

void main() {
  Gara gara({
    List<String> kronos = const [],
    List<String> dsc = const [],
    List<String> pc = const [],
  }) {
    return Gara(
      id: 'gara-id',
      titolo: 'Gara test',
      sport: 'Sci',
      dataGara: '2026-01-01',
      dataGaraFine: '',
      localita: 'Sondrio',
      sitoGara: '',
      organizzatore: '',
      idSicWin: '',
      dataRichiesta: '',
      kronosIds: kronos,
      dscIds: dsc,
      pcSegreteriaIds: pc,
      apparecchiature: const [],
      tipologia: '',
      status: 'DESIGNAZIONE INVIATA',
    );
  }

  test('resolves the role assigned to the logged user', () {
    expect(
      designationRoleFor(gara(dsc: const ['user']), 'user'),
      DesignationRole.serviceManager,
    );
    expect(
      designationRoleFor(gara(pc: const ['user']), 'user'),
      DesignationRole.secretaryPc,
    );
    expect(
      designationRoleFor(gara(kronos: const ['user']), 'user'),
      DesignationRole.timekeeper,
    );
    expect(DesignationRole.secretaryPc.label, 'Elaborazione Dati');
  });

  test('DSC wins when a user has more than one role', () {
    expect(
      designationRoleFor(
        gara(dsc: const ['user'], kronos: const ['user']),
        'user',
      ),
      DesignationRole.serviceManager,
    );
  });

  test('uses view-only role for users outside the designation', () {
    expect(
      designationRoleFor(gara(kronos: const ['other']), 'user'),
      DesignationRole.viewer,
    );
  });
}
