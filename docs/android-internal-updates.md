# Aggiornamenti APK interni

L'app Android controlla il manifest della release GitHub più recente:

`https://github.com/matty110488/rapporto_servizio_flutter/releases/latest/download/android-update.json`

Il manifest contiene versione, build number, URL HTTPS dell'APK e checksum
SHA-256. L'APK viene installato solo se il checksum coincide.

## Prima configurazione

1. Generare una chiave release stabile:

   ```powershell
   keytool -genkeypair -v -keystore C:\Users\togno\upload-crono-valtellinesi.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Conservare chiave, alias e password in almeno due luoghi sicuri. Non
   aggiungere mai file `.jks`, `.keystore` o `android/key.properties` a Git.

3. Convertire la chiave in Base64 per GitHub Actions:

   ```powershell
   [Convert]::ToBase64String(
     [IO.File]::ReadAllBytes('C:\Users\togno\upload-crono-valtellinesi.jks')
   ) | Set-Clipboard
   ```

4. In GitHub, aprire **Settings → Secrets and variables → Actions** e creare:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`

## Pubblicare un aggiornamento

1. Incrementare sempre `version` in `pubspec.yaml`, soprattutto il numero dopo
   `+`.
2. Committare e pubblicare il codice sul branch desiderato.
3. Creare e pubblicare un tag coerente:

   ```powershell
   git tag android-v2.1.1
   git push origin android-v2.1.1
   ```

4. Il workflow `Release Android APK` esegue analisi e test, crea l'APK firmato,
   calcola SHA-256 e pubblica APK e manifest in una GitHub Release.

## Prima migrazione

La vecchia APK era firmata con la chiave debug. La prima APK firmata con la
nuova chiave release richiede quindi una disinstallazione e reinstallazione.
Prima di disinstallare, inviare o completare eventuali bozze locali.

Dalla release successiva Android accetterà l'aggiornamento sopra la versione
installata perché firma e `applicationId` resteranno invariati.

Al primo aggiornamento interno Android chiederà di abilitare **Consenti da
questa fonte** per Crono Valtellinesi. Le installazioni successive richiederanno
comunque la conferma finale di Android, ma non sarà più necessario distribuire
manualmente il file APK.
