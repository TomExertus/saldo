# 💰 Saldo e Movimenti — Edizione Windows & Android

Versione multipiattaforma per **Windows 10/11** e **Android** dell'app **Saldo e Movimenti**, completa di:
- **Saldo attuale** modificabile con un clic e ricalcolo automatico
- **Budget consigliato** fino a fine mese (giornaliero, settimanale, spese fisse residue)
- **🏦 Importatore Estratto Conto Bancario (PDF, Excel `.xlsx`/`.xls`, CSV/TSV)** con separazione intelligente multi-operazione, riconoscimento automatico di uscite/entrate/emolumenti e categorizzazione automatica
- **📁 Salva su File / 📂 Apri File** con selettore nativo di cartella/percorso su Windows e Android
- **🔔 Promemoria & Scadenze** con notifiche native Windows e Android ed esportazione calendario `.ics`

---

## 📥 Come scaricare e installare su Windows e Android

### 1️⃣ Scarica i pacchetti nativi (`.apk` e `.exe`)
Dalla sezione **[Releases](https://github.com/TomExertus/saldo-win-android/releases/latest)** di questa repository puoi scaricare direttamente:
- 🤖 **`SaldoMovimenti-Android.apk`**: installabile su qualsiasi smartphone o tablet Android (Android 8.0+).
- 💻 **`SaldoMovimenti-Windows-Portable.exe`**: versione portatile per Windows 10/11 (doppio clic per avviare, senza installazione).
- 💻 **`SaldoMovimenti-Windows-nsis.exe`**: programma di installazione per Windows con icona sul Desktop e nel Menu Start.

### 2️⃣ Oppure installa come App Web (PWA) in 1 clic
Apri il link **[https://tomexertus.github.io/saldo-win-android/](https://tomexertus.github.io/saldo-win-android/)**:
- **Su Android (Chrome)**: premi il pulsante **"⚡ Installa App ora"** nel banner in alto (oppure Menu `⋮` → **Installa app**).
- **Su Windows (Edge / Chrome)**: clicca sull'icona **"Installa app"** nella barra degli indirizzi (o premi **"⚡ Installa App ora"**) per averla sul Desktop e nella barra delle applicazioni come app nativa.

---

## 🛠️ Struttura del Progetto
- `android/` — Progetto nativo **Android (Kotlin + AndroidX WebView + Storage Access Framework + NotificationManager)** apribile in Android Studio.
- `windows/electron/` — Progetto **Windows Desktop (Electron + electron-builder)** con dialoghi nativi di salvataggio file (`Salva su File`) e notifiche Toast di Windows.
- `windows/Avvia-Saldo-Movimenti-Windows.bat` — Launcher istantaneo per Windows 10/11 senza bisogno di installare nulla.
- `www/` — Core dell'applicazione condiviso con bridge nativi `window.AndroidBridge` e `window.WindowsBridge`.
- `.github/workflows/build-release.yml` — Pipeline GitHub Actions che compila automaticamente `.apk` e `.exe` e li pubblica nelle Releases.
