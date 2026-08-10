/**
 * Central non-secret configuration for the Vercel backend.
 *
 * Keep the annual database IDs aligned with lib/config/app_config.dart.
 * Additional IDs can be authorized without a code change through the Vercel
 * ALLOWED_DATABASE_IDS environment variable.
 */
export const DEFAULT_RACE_DATABASE_IDS = [
  '2afde089ef9580e2b0e7d19d44f3a3f6',
  '2b1de089ef9580729622ff9543046cbc',
];

export const NOTION_RACE_PROPERTIES = Object.freeze({
  status: 'STATUS',
  files: 'Files & media',
  serviceManager: 'DSC',
  expenseReport: 'NOTA SPESE APP',
});

export const RACE_STATUSES = Object.freeze({
  designationSent: 'DESIGNAZIONE INVIATA',
  reportReceived: 'RAPPORTINO RICEVUTO',
});

export function allowedRaceDatabaseIds(environmentValue = '') {
  return [
    ...DEFAULT_RACE_DATABASE_IDS,
    ...String(environmentValue)
      .split(',')
      .map((id) => id.trim())
      .filter(Boolean),
  ];
}
