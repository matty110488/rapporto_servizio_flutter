# Configurazione dell'ambiente TEST

L'applicazione usa due percorsi di pubblicazione:

- `develop` pubblica la PWA TEST su Firebase Hosting;
- `main` pubblica la PWA PROD su GitHub Pages.

La TEST ha un dominio, una cache, una sessione e un backend Vercel separati. Il
database Notion e il progetto Firebase rimangono gli stessi della produzione.
Questo significa che inserimenti, modifiche, notifiche e registrazioni eseguiti
dalla TEST possono modificare dati reali.

## 1. Creare il backend TEST su Vercel

1. Accedere a Vercel e scegliere **Add New > Project**.
2. Importare il repository GitHub `matty110488/rapporto_servizio_flutter`.
3. Assegnare il nome `rapporto-servizio-flutter-test`. Se il nome non e
   disponibile, sceglierne un altro e annotare l'URL assegnato da Vercel.
4. Lasciare la directory radice del progetto e il framework come nel progetto
   Vercel di produzione, quindi creare il progetto.
5. Per il primo deploy lasciare temporaneamente `main` come production branch.
6. Aprire **Settings > Environment Variables** e copiare dal progetto PROD:
   `NOTION_TOKEN`, `DATABASE_ID`, `FIREBASE_PROJECT_ID`,
   `FIREBASE_CLIENT_EMAIL` e `FIREBASE_PRIVATE_KEY`.
7. Aggiungere inoltre:
   - `PUBLIC_APP_URL` = `https://appkronos-1d181.web.app`;
   - `SESSION_SECRET` = una nuova stringa casuale lunga, diversa da PROD.
8. Non configurare un cron nel progetto TEST. Il poller GitHub esistente deve
   continuare a chiamare soltanto il backend PROD.

L'endpoint finale sara simile a:

```text
https://rapporto-servizio-flutter-test.vercel.app/api/notion-query
```

## 2. Abilitare Firebase Hosting per la PWA TEST

1. Aprire Firebase Console e selezionare il progetto `appkronos-1d181`.
2. Aprire **Hosting**, scegliere **Inizia** e completare la procedura iniziale.
   Non e necessario eseguire il deploy manuale proposto dalla procedura.
3. Il dominio TEST stabile sara `https://appkronos-1d181.web.app`.

## 3. Creare l'identita usata da GitHub per il deploy

Nel progetto Google Cloud collegato a Firebase:

1. Aprire **IAM e amministrazione > Account di servizio**.
2. Creare un account chiamato, per esempio, `github-actions-hosting`.
3. Assegnargli i ruoli consigliati dall'azione Firebase:
   - Firebase Hosting Admin;
   - Firebase Authentication Admin;
   - Cloud Run Viewer;
   - API Keys Viewer.
4. Aprire l'account, scegliere **Chiavi > Aggiungi chiave > Crea nuova chiave >
   JSON** e scaricare il file.
5. Non aggiungere mai questo JSON al repository.

## 4. Configurare Secret e Variable su GitHub

Aprire il repository GitHub, poi **Settings > Secrets and variables > Actions**.

Nella scheda **Secrets** creare:

- nome: `FIREBASE_SERVICE_ACCOUNT_APPKRONOS_1D181`;
- valore: l'intero contenuto del JSON scaricato al punto precedente.

Il secret `FIREBASE_WEB_VAPID_KEY` e gia usato dalla produzione: verificare che
esista. Nella scheda **Variables** creare:

- nome: `TEST_API_URL`;
- valore: l'endpoint completo del backend Vercel TEST, incluso
  `/api/notion-query`.

Dopo aver salvato il secret su GitHub, conservare il JSON in un password manager
oppure eliminarlo dal computer. GitHub ne conserva una copia cifrata.

## 5. Creare il branch develop

Questa configurazione deve prima essere presente su `main`. In seguito creare
`develop` partendo dal `main` aggiornato:

```powershell
git switch main
git pull
git switch -c develop
git push -u origin develop
```

Ora tornare nel progetto Vercel TEST e aprire **Settings > Environments >
Production > Branch Tracking**: impostare `develop` come production branch e
salvare.

Il primo push di `develop` avvia `.github/workflows/deploy-test.yml`. Lo stato si
vede in **GitHub > Actions > Deploy TEST**. A deploy concluso, aprire
`https://appkronos-1d181.web.app` da Safari e usare **Condividi > Aggiungi alla
schermata Home**.

## 6. Lavorare ogni giorno

1. Creare una branch di lavoro partendo da `develop`.
2. Aprire una Pull Request verso `develop`.
3. Dopo il merge, verificare la modifica nella PWA TEST.
4. Quando la versione e approvata, aprire una Pull Request da `develop` verso
   `main`.
5. Il merge su `main` pubblica la produzione attuale su GitHub Pages.

Per impedire pubblicazioni accidentali, in **GitHub > Settings > Rules >
Rulesets** creare una regola per `main` che richieda una Pull Request e i quality
checks prima del merge.

## 7. Controlli iniziali

Dopo il primo deploy verificare nella TEST:

- presenza del nastro arancione `TEST`;
- login con email e password;
- registrazione di una nuova passkey Face ID specifica per il dominio TEST;
- lettura delle gare;
- una modifica controllata, ricordando che il database e quello reale;
- ricezione delle notifiche, se abilitate.

Se Firebase Authentication rifiuta il dominio, aggiungere
`appkronos-1d181.web.app` in **Firebase > Authentication > Settings > Authorized
domains**.
