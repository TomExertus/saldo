# 💰 Saldo e Movimenti — Monorepo Multipiattaforma

[![Deploy to GitHub Pages](https://github.com/TomExertus/saldo/actions/workflows/pages.yml/badge.svg)](https://github.com/TomExertus/saldo/actions/workflows/pages.yml)
[![Build Release](https://github.com/TomExertus/saldo/actions/workflows/build-release.yml/badge.svg)](https://github.com/TomExertus/saldo/actions/workflows/build-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/TomExertus/saldo?label=Release&color=success)](https://github.com/TomExertus/saldo/releases/latest)

Suite unificata per la gestione intelligente delle finanze personali su tutte le piattaforme:
- 🍏 **iOS & macOS**: App nativa SwiftUI (`ios/`) + PWA ottimizzata con selettore cartella File / iCloud Drive
- 🤖 **Android**: App nativa Kotlin (`android/`) + PWA installabile con notifiche push e Storage Access Framework
- 💻 **Windows**: App Desktop Electron (`windows/`) con pacchetti `.exe` (Installer NSIS & Portable) e launcher `.bat`
- 🌐 **Web**: PWA installabile e funzionante al 100% offline su [https://tomexertus.github.io/saldo/](https://tomexertus.github.io/saldo/)

---

## 📱 Versioni per Piattaforma

| Piattaforma | Componente | Versione Corrente | Formato Distribuzione |
| :--- | :--- | :---: | :--- |
| **🌐 Web / PWA** | `web/` & root | **v14 (v1.1.0)** | Online su GitHub Pages ([Apri](https://tomexertus.github.io/saldo/)) |
| **🤖 Android** | `android/` | **v1.1.0 (code 11)** | Pacchetto APK `SaldoMovimenti-Android.apk` ([Releases](https://github.com/TomExertus/saldo/releases/latest)) |
| **💻 Windows** | `windows/electron/` | **v1.1.0** | `SaldoMovimenti-Windows-Portable.exe` & `Setup.exe` ([Releases](https://github.com/TomExertus/saldo/releases/latest)) |
| **🍏 iOS / macOS** | `ios/` | **v1.1.0 (build 14)** | Progetto Xcode SwiftUI (`ios/SaldoMovimenti.xcodeproj`) |

---

## 📦 Download Diretti

Dalla sezione **[GitHub Releases](https://github.com/TomExertus/saldo/releases/latest)**:
- 🤖 **Android APK**: [`SaldoMovimenti-Android.apk`](https://github.com/TomExertus/saldo/releases/latest) (installa direttamente su smartphone o tablet Android 8.0+)
- 💻 **Windows Portable**: [`SaldoMovimenti-Windows-Portable.exe`](https://github.com/TomExertus/saldo/releases/latest) (avvio immediato senza installazione)
- 💻 **Windows Setup**: [`SaldoMovimenti-Windows-Setup.exe`](https://github.com/TomExertus/saldo/releases/latest) (installer con scorciatoie Desktop e Menu Start)
- 🍏 **iOS & macOS**: Apri [https://tomexertus.github.io/saldo/](https://tomexertus.github.io/saldo/) da Safari e tocca **Condividi (⬆️) → Aggiungi alla schermata Home**

---

## 🏛️ Architettura del Monorepo

```
saldo/
├── .github/
│   └── workflows/
│       ├── pages.yml               # Deploy continuo della PWA su GitHub Pages
│       └── build-release.yml       # Build automatica Android APK, Windows EXE e verifica iOS
├── android/                        # Progetto nativo Android (Kotlin, Gradle 8.5, SDK 34)
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/main/java/com/tommasonguyen/saldomovimenti/MainActivity.kt
│   ├── build.gradle.kts
│   ├── gradle.properties
│   └── settings.gradle.kts
├── ios/                            # Progetto nativo iOS & macOS (SwiftUI, Xcode)
│   ├── SaldoMovimenti.xcodeproj
│   └── SaldoMovimenti/             # Sorgenti Swift (Models, SaldoStore, Views, NotificationManager)
├── windows/                        # Progetto Desktop Windows
│   ├── Avvia-Saldo-Movimenti-Windows.bat   # Avvio rapido Edge WebView2
│   └── electron/                   # App Electron 29 con electron-builder (NSIS & Portable)
│       ├── main.js
│       ├── preload.js
│       ├── package.json
│       └── sync-www.js
├── web/                            # Core PWA / Web Application
│   ├── index.html                  # Dashboard completa (Saldo, Movimenti, Grafici, Parser Estratti Conto)
│   ├── app.html                    # Alias per bypass cache
│   ├── manifest.json               # Manifest PWA
│   ├── sw.js                       # Service Worker con cache offline
│   └── icon.svg                    # Icona vettoriale
├── index.html                      # Entry point root per GitHub Pages
├── app.html
├── manifest.json
├── sw.js
└── icon.svg
```

---

## ⚡ Caratteristiche Principali

1. **💰 Saldo Attuale & Budget Intelligente**
   - Modifica diretta del saldo con ricalcolo automatico del budget giornaliero e settimanale consigliato fino a fine mese.
2. **🏦 Importazione Intelligente Estratti Conto (PDF, Excel `.xlsx`/`.xls`, CSV, TSV)**
   - Riconoscimento multi-operazione e parsing geometrico avanzato per colonne dare/avere, stipendi e commissioni con categorizzazione automatica.
3. **📁 Sincronizzazione Dati & Backup su File**
   - Supporto per File System Access API (seleziona cartella o file iCloud Drive / locale), bridge nativo Android (SAF) e Electron (`dialog.showSaveDialog`).
4. **🔔 Promemoria e Scadenze**
   - Notifiche native locali su iOS, Android e Windows + esportazione calendario standard `.ics`.

---

## 🚀 Istruzioni di Build Locale

### Android
```bash
cd android
./gradlew assembleRelease
# L'APK compilato si troverà in app/build/outputs/apk/release/app-release.apk
```

### Windows (Electron)
```bash
cd windows/electron
npm install
npm run build:win
# Gli eseguibili .exe (Setup e Portable) si troveranno in dist/
```

### iOS / macOS (Xcode)
Apri `ios/SaldoMovimenti.xcodeproj` con **Xcode 15+** e seleziona il target desiderato (iPhone, iPad o Mac).
