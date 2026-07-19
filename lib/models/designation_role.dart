import 'gara.dart';

enum DesignationRole {
  serviceManager('DSC'),
  secretaryPc('PC Segreteria'),
  timekeeper('Cronometrista'),
  viewer('Visualizzazione');

  const DesignationRole(this.label);

  final String label;
}

DesignationRole designationRoleFor(Gara gara, String? userId) {
  final normalizedId = userId?.trim() ?? '';
  if (normalizedId.isEmpty) return DesignationRole.viewer;
  if (gara.dscIds.contains(normalizedId)) {
    return DesignationRole.serviceManager;
  }
  if (gara.pcSegreteriaIds.contains(normalizedId)) {
    return DesignationRole.secretaryPc;
  }
  if (gara.kronosIds.contains(normalizedId)) {
    return DesignationRole.timekeeper;
  }
  return DesignationRole.viewer;
}
