---
title: Privacy Policy
---

# Privacy Policy — Folio

_Ultimo aggiornamento / Last updated: 21 maggio 2026_

[🇮🇹 Italiano](#italiano) · [🇬🇧 English](#english)

---

## Italiano

Folio è un'applicazione Android per la visualizzazione e modifica di documenti
in formato OpenDocument Text (`.odt`). Questa pagina descrive come Folio
tratta i tuoi dati.

### In sintesi

Folio **non raccoglie, non trasmette e non condivide** alcun dato personale.
L'app funziona completamente offline: i tuoi documenti e tutti i dati relativi
restano sul tuo dispositivo.

### Titolare del trattamento

Carlo Giuseppe Celi — sviluppatore indipendente.
Email di contatto: <carloceli13@outlook.it>

### Dati non raccolti

Folio **non raccoglie**:

- dati identificativi (nome, email, account)
- dati di utilizzo, analytics o telemetria
- crash report
- identificativi pubblicitari o di dispositivo
- posizione geografica
- contatti, calendario, foto, microfono, fotocamera

L'app non richiede alcun account, registrazione o autenticazione per essere
utilizzata.

### Assenza di connessioni di rete

La versione di Folio distribuita su Google Play **non dichiara il permesso
`INTERNET`** nel proprio manifest Android. Di conseguenza il sistema operativo
impedisce qualsiasi traffico di rete in uscita dall'applicazione: Folio non
può tecnicamente comunicare con server esterni, inviare dati, scaricare
contenuti remoti o ricevere notifiche push.

### Dati salvati localmente sul tuo dispositivo

Per funzionare, Folio salva alcuni dati esclusivamente in spazio privato
dell'applicazione sul tuo dispositivo. Questi dati **non vengono mai
trasmessi** e sono accessibili solo a Folio (e all'utente del dispositivo
tramite le impostazioni di sistema).

In particolare l'app salva localmente:

- **Lista dei documenti recenti**: per ogni file aperto di recente vengono
  conservati nome del file, breve anteprima testuale, data di apertura e
  riferimento al percorso scelto dall'utente. La lista è memorizzata
  tramite `SharedPreferences` di Android.
- **Copia in cache dei documenti recenti**: per poter riaprire un file anche
  dopo che il permesso temporaneo concesso al selettore di sistema è scaduto,
  Folio mantiene una copia dei bytes del documento nella propria cartella
  privata (`getApplicationSupportDirectory`).
- **Bozze di lavoro**: durante la modifica di un documento, l'app salva
  automaticamente bozze locali nella propria cartella privata, in modo da
  permettere il recupero in caso di chiusura imprevista.

Tutti questi dati possono essere cancellati in qualsiasi momento eliminando
i documenti recenti dalla schermata principale dell'app, oppure cancellando
i dati dell'app dalle impostazioni Android (_Impostazioni → App → Folio →
Archiviazione → Cancella dati_).

### Accesso ai tuoi file

L'apertura e il salvataggio dei file `.odt` avvengono esclusivamente tramite
lo **Storage Access Framework di Android** (selettore di sistema). Folio
non scansiona, indicizza o legge altri file sul tuo dispositivo: accede
soltanto ai documenti che tu stesso selezioni esplicitamente.

### Link esterni nei documenti

Se un documento contiene un collegamento ipertestuale e tu decidi di toccarlo,
Folio chiede al sistema Android di aprire quel link nell'app predefinita
(tipicamente il browser). Folio non comunica direttamente con quei siti
e non riceve informazioni sul fatto che il link sia stato aperto.

### Servizi di terze parti

Folio **non integra** SDK di analytics, crash reporting, advertising,
social network o tracking di alcun tipo.

Il font utilizzato nell'interfaccia (Lora) viene caricato esclusivamente
da risorse interne all'applicazione: in assenza del permesso `INTERNET`,
non vengono effettuate richieste a server di Google Fonts né ad altri CDN.

L'unico canale di distribuzione è Google Play. Per le informazioni che
Google raccoglie quando scarichi l'app dallo store, fai riferimento alla
[Privacy Policy di Google](https://policies.google.com/privacy).

### Permessi Android richiesti

L'app non richiede permessi runtime (`READ_EXTERNAL_STORAGE`,
`WRITE_EXTERNAL_STORAGE`, posizione, contatti, fotocamera, ecc.).
L'accesso ai file avviene esclusivamente tramite il selettore di sistema,
che concede a Folio un permesso temporaneo e limitato al solo file
selezionato dall'utente.

### Minori

Folio non è specificamente rivolto a minori di 13 anni, ma non raccoglie
dati personali da nessun utente, indipendentemente dall'età.

### Diritti dell'utente (GDPR)

Poiché Folio non raccoglie né tratta dati personali ai sensi del
Regolamento UE 2016/679 (GDPR), non vi sono dati da fornire, rettificare,
cancellare o portare in risposta a una richiesta dell'interessato.
Per qualsiasi domanda relativa alla presente policy puoi comunque
contattare l'indirizzo email indicato sopra.

### Modifiche a questa policy

Eventuali modifiche future a questa Privacy Policy saranno pubblicate
in questa pagina, con aggiornamento della data in cima al documento.

### Codice sorgente

Folio è un progetto open source. Il codice è disponibile su
[GitHub](https://github.com/carloceli2312/folio): chiunque può
verificare in modo indipendente quanto dichiarato in questa policy.

---

## English

Folio is an Android application for viewing and editing OpenDocument Text
(`.odt`) files. This page explains how Folio handles your data.

### Summary

Folio **does not collect, transmit or share** any personal data. The app
runs entirely offline: your documents and all related data stay on your
device.

### Data controller

Carlo Giuseppe Celi — independent developer.
Contact email: <carloceli13@outlook.it>

### Data not collected

Folio **does not collect**:

- identifying data (name, email, account)
- usage data, analytics or telemetry
- crash reports
- advertising or device identifiers
- geolocation
- contacts, calendar, photos, microphone, camera

The app requires no account, registration or authentication of any kind.

### No network connectivity

The Google Play release of Folio **does not declare the `INTERNET`
permission** in its Android manifest. The operating system therefore
prevents any outbound network traffic: Folio is technically unable to
contact external servers, send data, download remote content or receive
push notifications.

### Data stored locally on your device

To function, Folio stores some data exclusively in its private application
storage on your device. This data is **never transmitted** and is
accessible only to Folio (and to the device user through system settings).

Specifically, the app stores locally:

- **List of recent documents**: for each recently opened file the app
  keeps the filename, a short text preview, the open date, and a reference
  to the path you chose. This list is saved through Android
  `SharedPreferences`.
- **Cached copy of recent documents**: in order to reopen a file even
  after the temporary permission granted by the system file picker has
  expired, Folio keeps a copy of the document bytes in its private
  application directory (`getApplicationSupportDirectory`).
- **Working drafts**: while editing a document the app automatically
  saves local drafts in its private directory, so the work can be
  recovered after an unexpected close.

You can delete all of this data at any time by removing recent documents
from the app home screen, or by clearing app data from Android settings
(_Settings → Apps → Folio → Storage → Clear data_).

### Access to your files

Opening and saving `.odt` files happens exclusively through Android's
**Storage Access Framework** (the system file picker). Folio does not
scan, index or read any other files on your device: it only accesses
the documents you explicitly select.

### External links in documents

If a document contains a hyperlink and you tap it, Folio asks the Android
system to open that link with the default app (typically the browser).
Folio does not communicate with those websites directly, nor does it
receive information about whether the link was opened.

### Third-party services

Folio **does not embed** any analytics, crash reporting, advertising,
social network or tracking SDK.

The font used in the UI (Lora) is loaded exclusively from resources
bundled with the application: since the app has no `INTERNET` permission,
no requests are made to Google Fonts servers or any other CDN.

The only distribution channel is Google Play. For information about what
Google collects when you download the app from the Store, see
[Google's Privacy Policy](https://policies.google.com/privacy).

### Android permissions requested

The app requests no runtime permissions (`READ_EXTERNAL_STORAGE`,
`WRITE_EXTERNAL_STORAGE`, location, contacts, camera, etc.). File access
happens only through the system file picker, which grants Folio a
temporary permission restricted to the file the user has selected.

### Children

Folio is not specifically directed at children under 13, but it does not
collect personal data from any user regardless of age.

### User rights (GDPR)

Because Folio does not collect or process personal data within the
meaning of EU Regulation 2016/679 (GDPR), there is no personal data to
provide, rectify, erase or port in response to a data subject request.
For any question about this policy you can still reach out at the email
address above.

### Changes to this policy

Any future changes to this Privacy Policy will be published on this page,
with the date at the top of the document updated accordingly.

### Source code

Folio is open source. The code is available on
[GitHub](https://github.com/carloceli2312/folio): anyone can verify
independently the claims made in this policy.
