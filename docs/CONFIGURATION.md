# Configurazione applicativa e database Notion

Questa guida descrive dove si trovano i parametri dell'applicazione, come viene
letto ogni database annuale e quale procedura seguire quando viene creato il
database dell'anno successivo.

## Principio generale

La configurazione e separata in tre categorie:

1. **Parametri Flutter non segreti** in `lib/config/app_config.dart`.
2. **Allowlist backend non segreta** in `api/notion-config.js`.
3. **Segreti e valori specifici dell'ambiente** nelle variabili Vercel, GitHub
   e Firebase. Token, password e chiavi private non devono mai essere copiati
   nei due file di configurazione versionati.

Flutter e Node.js sono eseguiti in ambienti diversi e non possono importare lo
stesso file sorgente. Per questo gli ID annuali sono presenti una volta nel
client e una volta nel backend. I test automatici controllano formato e valori
di base; la checklist annuale sottostante ricorda di aggiornare entrambi.

## Database annuali

Nel client la sorgente centrale e:

```dart
AppConfig.raceDatabaseIds
```

La mappa associa l'anno al database Notion:

```dart
static const Map<int, String> raceDatabaseIds = {
  2025: 'ID_2025',
  2026: 'ID_2026',
};
```

Le schermate Home, Designazioni, Rapporti di servizio, Archivio e Statistiche
caricano automaticamente tutti i database presenti nella mappa. Il Calendario
gare usa le chiavi della stessa mappa per costruire il selettore dell'anno.

Il backend autorizza soltanto i database elencati in
`DEFAULT_RACE_DATABASE_IDS` dentro `api/notion-config.js`, oltre agli eventuali
ID presenti nella variabile Vercel `ALLOWED_DATABASE_IDS`. Questa allowlist
impedisce a un client di usare il token server per interrogare database Notion
arbitrari.

## Procedura per aggiungere un nuovo anno

Esempio: database 2027 clonato dal 2026.

1. Verificare che il clone mantenga proprietà, tipi e relazioni descritti nella
   sezione successiva.
2. Condividere il database con la stessa integrazione Notion usata dall'app.
3. Copiare l'ID del nuovo database dalla pagina Notion.
4. Aggiungere `2027: 'ID_2027'` a `AppConfig.raceDatabaseIds`, mantenendo
   l'ordine crescente degli anni.
5. Aggiungere lo stesso ID a `DEFAULT_RACE_DATABASE_IDS` nel backend.
6. Se si usa anche `ALLOWED_DATABASE_IDS` in Vercel, verificare i progetti
   `rapporto-servizio-flutter-test` e `rapporto-servizio-flutter`. La variabile
   non deve contraddire la configurazione versionata; gli ID duplicati sono
   innocui perché il backend li converte in un insieme.
7. Aprire una pull request verso `develop` e attendere il deploy TEST.
8. Creare una gara 2027 di prova e verificare:
   - comparsa nel Calendario 2027;
   - comparsa in Home e Designazioni per un crono assegnato;
   - compilazione e ripresa della bozza;
   - generazione del PDF;
   - stato `RAPPORTINO RICEVUTO`;
   - PDF nella proprietà `Files & media`.
9. Eliminare o archiviare la gara fittizia soltanto dopo il controllo.
10. Promuovere `develop` in `main` quando il TEST e stato approvato.

Non e necessario modificare servizi o schermate per ogni nuovo anno.

## Contratto dello schema Notion

I nomi centrali sono dichiarati in `NotionRaceProperties`. Il clone annuale
deve conservare almeno queste proprietà e i relativi tipi:

| Proprietà | Tipo atteso | Utilizzo |
| --- | --- | --- |
| `GARA` | Titolo | Nome evento |
| `DATA GARA` | Data | Calendario e giornate multiple |
| `STATUS` | Status oppure select | Flusso designazione/rapportino |
| `KRONOS DESIGNATI` | Relazione | Personale assegnato |
| `DSC` | Relazione | Responsabile autorizzato al rapportino |
| `PC SEGRETERIA` | Relazione | Personale Elaborazione Dati |
| `APPARECCHIATURA` | Multi-select | Materiale previsto |
| `TIPOLOGIA` | Select | Tipo di gara |
| `ID SIC WIN` | Testo/valore leggibile | Pacchetti di più giornate |
| `Files & media` | Files | Archiviazione PDF |
| `SITO GARA` | Testo | Sede |
| `ORGANIZZATORE` | Testo | Contatto organizzativo |
| `DATA RICHIESTA` | Data | Informazioni amministrative |

Le varianti gia supportate per località, sport e stato servono a leggere dati
storici, ma i nuovi database devono mantenere i nomi standard del 2026.

Gli stati applicativi sono raccolti in `RaceStatuses`. I valori principali
sono `DESIGNAZIONE INVIATA`, `GARA COMPLETATA`, `SICWIN OK` e
`RAPPORTINO RICEVUTO`. Se un valore viene rinominato in Notion, deve essere
aggiornato nella configurazione e verificato in TEST.

## Parametri operativi Flutter

`AppConfig` contiene anche i parametri che possono essere regolati senza
cercarli nelle singole schermate:

| Parametro | Valore attuale | Effetto |
| --- | --- | --- |
| `dashboardRefreshInterval` | 5 minuti | Aggiornamento Home |
| `notificationBadgeRefreshInterval` | 45 secondi | Badge notifiche Home |
| `notificationsPageRefreshInterval` | 30 secondi | Elenco notifiche |
| `reportDraftAutosaveInterval` | 4 secondi | Salvataggio bozza locale |
| `maxNotionPdfBytes` | 4.500.000 byte | Limite invio PDF a Notion |

Questi valori non richiedono configurazione Vercel. Ogni modifica deve essere
provata in TEST perché intervalli troppo brevi aumentano le richieste a Notion.

## Variabili protette e ambienti

Restano fuori dal codice:

- `NOTION_TOKEN`
- `DATABASE_ID` del database utenti
- `SESSION_SECRET`
- credenziali Firebase
- `TEST_API_URL`

`DATABASE_ID` non e un database gare annuale: identifica gli utenti e serve
all'autenticazione. Non deve essere sostituito con l'ID del database 2027.

TEST e PROD usano attualmente gli stessi dati Notion ma backend e frontend
separati. Le modifiche vanno sempre unite prima in `develop`; `main` viene
aggiornato soltanto dopo la verifica manuale.

## Controlli automatici

I file `test/app_config_test.dart` e
`test_backend/notion-config.test.js` verificano che gli ID configurati siano
validi, univoci e visibili ai due livelli dell'applicazione. GitHub esegue
inoltre analyzer, test, build web e controlli di sintassi backend su ogni pull
request.
