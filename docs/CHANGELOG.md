# Registro delle modifiche architetturali

Questo documento registra le modifiche che cambiano il modo in cui il progetto
e configurato o gestito. Le modifiche funzionali dettagliate restano disponibili
anche nella cronologia Git e nelle pull request GitHub.

## 2026-07-24 - Release 2.2.0

- Aggiunto il meteo per le gare da oggi ai successivi sette giorni, con
  geocodifica della località, cache e riepilogo nel Calendario e nel Cockpit.
- Riorganizzato il Cockpit gara mettendo Équipe, Organizzatore e Info utili
  nell'ordine operativo richiesto.
- Compattati e uniformati i filtri del Calendario.
- Aggiunti Archivio rapportini, invio PDF tramite email o WhatsApp e azioni
  standard Aiuto, Aggiorna e Home nelle schermate operative.

## 2026-07-22 - Caricamento annuale e cache gare

- Home, Designazioni e compilazione rapportini leggono solo l'anno corrente.
- Calendario, Archivio e Statistiche caricano gli anni storici solo su scelta
  esplicita dell'utente.
- Aggiunta una cache annuale condivisa di cinque minuti per evitare letture
  duplicate passando da una schermata all'altra.
- Aggiornamenti manuali e modifiche alle gare invalidano o ignorano la cache.

## 2026-07-19 - Cockpit gara e Pass universale

- Trasformato il dettaglio gara in un cockpit operativo.
- Aggiunti avanzamento del servizio, azioni rapide, squadra e materiale.
- Aggiunto un Pass designazione multipiattaforma con QR e ruolo personale.
- Aggiunta esportazione del pass come immagine PNG tramite condivisione nativa.
- Il QR usa un deep link autenticato e non contiene credenziali.
- Documentata la separazione tra Pass universale gratuito e futura integrazione
  ufficiale Apple/Google Wallet.

## 2026-07-19 - Configurazione centrale

- Creato `lib/config/app_config.dart` come sorgente unica Flutter per database
  gare annuali, proprietà Notion, stati e intervalli operativi.
- Creato `api/notion-config.js` come allowlist centrale del backend Vercel.
- Rimosse le copie degli ID 2025/2026 da Home, Calendario, Designazioni,
  Rapporti di servizio, Archivio, Statistiche, Dettaglio gara e Notifiche.
- Il selettore annuale del Calendario viene ora generato dalla configurazione.
- Le schermate cumulative caricano automaticamente tutti gli ID configurati.
- Centralizzati autosalvataggio, polling notifiche, refresh Home e limite PDF.
- Centralizzati i nomi delle principali proprietà Notion e gli stati di gara.
- Aggiunti test Flutter e Node.js sulla configurazione.
- Aggiunta la procedura documentata per introdurre un nuovo database annuale.

### Compatibilità

Nessun comportamento dati e stato modificato: i database 2025 e 2026, gli
stati e gli intervalli mantengono gli stessi valori usati prima del riordino.
Il database 2027 non e ancora configurato perché il relativo ID non e stato
fornito.
