# Contesto Progetto — Saldo e Movimenti (Monorepo Unificato)

Il progetto è ora **completamente unificato** nel repository principale GitHub:
- **Repository GitHub:** `https://github.com/TomExertus/saldo`
- **Web App / PWA online:** `https://tomexertus.github.io/saldo/`
- **Releases e Download:** `https://github.com/TomExertus/saldo/releases/latest`

## Struttura del Monorepo (`/Users/tommasonguyen/.gemini/antigravity/scratch/SaldoMovimentiWeb`)
1. **`ios/`**: App nativa iOS & macOS (SwiftUI, Xcode `SaldoMovimenti.xcodeproj`)
   - Versione: `1.1.0 (build 14)`
2. **`android/`**: App nativa Android (Kotlin, Gradle 8.5, SDK 34)
   - Versione: `1.1.0 (versionCode 11)`
   - File output: `SaldoMovimenti-Android.apk`
3. **`windows/`**: App Desktop Windows
   - `windows/electron/`: App Electron 29 con `electron-builder`
   - Versione: `1.1.0`
   - File output: `SaldoMovimenti-Windows-Setup.exe` e `SaldoMovimenti-Windows-Portable.exe`
   - `windows/Avvia-Saldo-Movimenti-Windows.bat`: launcher rapido
4. **`web/`** (e root): Core Web App / PWA (HTML5, CSS3, JavaScript, Service Worker)
   - Versione: `v14 (1.1.0)`
   - Supporto File System Access API (iCloud Drive / cartella File su iOS e macOS), parser estratti conto avanzato

## Pipeline GitHub Actions
- `.github/workflows/pages.yml`: deploy continuo su GitHub Pages
- `.github/workflows/build-release.yml`: compilazione automatica Android APK, Windows EXE, verifica iOS e pubblicazione su GitHub Releases
