# Rapporto di servizio - Crono Valtellinesi

Applicazione Flutter per consultare gare e designazioni, compilare rapporti di
servizio, generare PDF e inviare notifiche agli amministratori.

## Struttura

- `lib/`: applicazione Flutter per web, Android e altre piattaforme.
- `api/notion-query.js`: backend Vercel che accede a Notion e Firebase.
- `web/`: manifest PWA, icone e service worker Firebase.
- `.github/workflows/`: controlli automatici e pubblicazione GitHub Pages.

Il client non contiene il token Notion. Tutte le richieste passano dal backend,
che rilascia dopo il login una sessione firmata valida sette giorni. Le pagine
utente restituite al client non includono la proprietà `PASSWORD`.

## Face ID, Touch ID e impronta Android

L'app supporta passkey WebAuthn sulla PWA installata dalla schermata Home sia su
iOS sia su Android. Dopo un normale login, l'utente preme l'icona dell'impronta
nella pagina iniziale e conferma la creazione della passkey. Nei login successivi
può usare **Accedi con Face ID o impronta**.

La biometria resta sul dispositivo: Notion conserva nella proprietà `PASSKEYS`
soltanto chiavi pubbliche e metadati non segreti. Se la proprietà non esiste, il
backend prova a crearla automaticamente nel database utenti. Username e password
restano disponibili come recupero.

Le passkey sono legate al dominio `matty110488.github.io`. Le build native da
App Store o Play Store richiederebbero inoltre Apple Associated Domains e Android
Digital Asset Links; la versione distribuita come icona web non richiede questa
configurazione aggiuntiva.

## Avvio locale

Requisiti: Flutter 3.38.3 e un browser supportato.

```powershell
flutter pub get
flutter run -d chrome
```

Il backend usato dall'app è quello pubblicato su Vercel. Per eseguire anche il
backend localmente occorre configurare le variabili descritte sotto.

## Controlli

Prima di pubblicare una modifica:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter build web --release --no-pub --base-href /rapporto_servizio_flutter/
node --check api/notion-query.js
```

Gli stessi controlli vengono eseguiti automaticamente da GitHub sul branch di
lavoro e sulle pull request.

## Configurazione Vercel

Variabili obbligatorie:

- `NOTION_TOKEN`: token dell'integrazione Notion, solo lato server.
- `DATABASE_ID`: database Notion degli utenti/cronometristi.

Variabili per le notifiche push:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Variabili opzionali:

- `SESSION_SECRET`: chiave casuale usata per firmare le sessioni. Se assente,
  viene usato il token Notion come chiave; impostarla separatamente è preferibile.
- `ALLOWED_ORIGINS`: origini web aggiuntive, separate da virgola.
- `ALLOWED_DATABASE_IDS`: database dati aggiuntivi, separati da virgola.

Le variabili segrete non devono mai essere inserite in `lib/`, nel README o nei
workflow GitHub.

## Pubblicazione web

Un push su `main`, se analyzer e test passano, genera la build Flutter e la
pubblica su GitHub Pages. Il workflow usa il base path
`/rapporto_servizio_flutter/`.

Il backend `api/` viene pubblicato separatamente da Vercel tramite
l'integrazione del repository.

## Rollback

Il punto precedente agli interventi di sicurezza è disponibile localmente e su
GitHub con il tag:

```text
backup-before-hardening-2026-07-11
```

Per aprire quella versione senza cancellare il lavoro successivo:

```powershell
git switch -c restore-hardening backup-before-hardening-2026-07-11
```

Non usare `git reset --hard` per un normale rollback: il tag e i singoli commit
consentono di recuperare la versione desiderata senza perdere dati.

## Note di sicurezza

- Il vecchio token Notion deve essere revocato e sostituito nel pannello Notion
  e nella variabile `NOTION_TOKEN` di Vercel.
- Le password sono ancora gestite come proprietà Notion per compatibilità. La
  migrazione futura consigliata è Firebase Authentication o un sistema server
  con password sottoposte a hashing.
- Una sessione salvata prima dell'introduzione dell'autenticazione firmata viene
  automaticamente eliminata: al primo avvio sarà richiesto un nuovo login.
