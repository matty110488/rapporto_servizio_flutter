# Cockpit gara e Pass designazione

## Obiettivo

Il dettaglio di una gara e diventato un cockpit operativo. Riunisce in una sola
schermata le informazioni che servono al cronometrista prima e durante il
servizio e presenta la designazione come un pass digitale facile da mostrare o
condividere.

Questa prima versione non usa Apple Wallet o Google Wallet. Non richiede
abbonamenti, account emittente o certificati e funziona allo stesso modo nella
PWA su iPhone, Android e computer.

## Contenuto del Cockpit

- nome, data, luogo e disciplina della gara;
- stato e avanzamento Designazione > Servizio > Rapportino;
- nome dell'utente e ruolo ricavato dalle relazioni Notion;
- DSC, cronometristi e PC Segreteria;
- apparecchiature previste;
- apertura delle indicazioni stradali;
- chiamata all'organizzatore quando il testo contiene un numero telefonico;
- Pass designazione universale.

Il ruolo viene risolto in questo ordine: DSC, PC Segreteria, Cronometrista,
Visualizzazione. L'ordine evita risultati ambigui quando una persona compare in
piu relazioni.

## Pass universale

Il pass mostra:

- organizzazione;
- evento;
- giorno e mese;
- cronometrista;
- ruolo;
- luogo;
- disciplina;
- stato della designazione;
- identificativo breve;
- QR code.

Il QR contiene un deep link all'app con il parametro `garaId`. Quando un utente
autenticato lo apre, l'app recupera la pagina Notion e mostra lo stesso cockpit.
Il QR non contiene token, password o dati segreti.

Il pulsante **Condividi o salva pass** cattura soltanto la card, crea un PNG ad
alta risoluzione e apre il pannello di condivisione del dispositivo. Il file puo
essere salvato nelle foto, nei file o inviato tramite le applicazioni installate.

## Limiti intenzionali

- Il PNG non viene inserito automaticamente in Apple Wallet o Google Wallet.
- Il pass salvato e una fotografia dei dati in quel momento e non si aggiorna
  se la designazione cambia.
- Il QR apre l'app e richiede una sessione valida; non rende pubblici i dati
  della gara.

## Evoluzione futura verso i Wallet

L'interfaccia del Cockpit e il modello dati del pass sono indipendenti dal
formato di esportazione. In futuro il pulsante di condivisione potra affiancare:

- un file Apple `.pkpass` firmato, se sara disponibile un account Apple
  Developer e un Pass Type ID;
- un link Google Wallet firmato, se sara disponibile un Issuer Account.

Non sara necessario ridisegnare il cockpit. Il backend dovra generare i pass a
partire dall'ID gara e dalla sessione autenticata, senza accettare dati arbitrari
dal client.
