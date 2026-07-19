const _productionApiUrl =
    'https://rapporto-servizio-flutter.vercel.app/api/notion-query';

/// Configurazione scelta al momento della build con --dart-define.
///
/// Le build normali restano di produzione. Il workflow TEST imposta invece:
///   APP_ENV=test
///   API_URL=https://...vercel.app/api/notion-query
const appEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'prod',
);

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: _productionApiUrl,
);

const isTestEnvironment = appEnvironment == 'test';

const appDisplayName =
    isTestEnvironment ? 'Crono Valtellinesi TEST' : 'Crono Valtellinesi';
