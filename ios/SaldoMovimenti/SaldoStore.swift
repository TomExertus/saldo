//
//  SaldoStore.swift
//  SaldoMovimenti
//

import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum SyncMode: Equatable {
    case localOnly
    case iCloudContainer(URL)
    case linkedExternalFile(URL)
    
    var isSynced: Bool {
        switch self {
        case .localOnly: return false
        case .iCloudContainer, .linkedExternalFile: return true
        }
    }
    
    var fileName: String? {
        switch self {
        case .localOnly: return nil
        case .iCloudContainer(let url), .linkedExternalFile(let url):
            return url.lastPathComponent
        }
    }
    
    static func friendlyFolderName(for url: URL) -> String {
        let parent = url.deletingLastPathComponent()
        let path = parent.path
        let lastDir = parent.lastPathComponent
        
        if path.contains("com~apple~CloudDocs") {
            if lastDir == "com~apple~CloudDocs" || lastDir == "Documents" {
                return "App File › iCloud Drive"
            } else {
                return "App File › iCloud Drive › \(lastDir)"
            }
        }
        if path.contains("Mobile Documents") {
            return "App File › iCloud Drive › \(lastDir)"
        }
        #if os(iOS)
        if lastDir == "Documents" {
            return "App File › Su iPhone › Saldo e Movimenti"
        }
        return "App File › \(lastDir)"
        #else
        if path.contains("/Containers/") && lastDir == "Documents" {
            return "Cartella App (Locale) › Documenti"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            let rel = String(path.dropFirst(home.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !rel.isEmpty {
                return "Cartella File › " + rel.replacingOccurrences(of: "/", with: " › ")
            }
        }
        return "Cartella › \(lastDir)"
        #endif
    }
}

struct BudgetCalculationResult {
    let saldo: Double
    let upcoming: Double
    let risparmio: Double
    let soglia: Double
    let spendibile: Double
    let daysLeft: Int
    let endOfMonth: String
    
    var perDay: Double {
        spendibile >= 0 ? spendibile / Double(max(1, daysLeft)) : 0
    }
    
    var perWeek: Double {
        perDay * 7.0
    }
    
    var isWarning: Bool {
        spendibile > 0 && spendibile < (upcoming + risparmio) * 0.2
    }
    
    var isDanger: Bool {
        spendibile < 0
    }
}

#if os(iOS)
final class IOSDocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private let onPick: (URL) -> Void
    
    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick(url)
    }
}
#endif

@MainActor
final class SaldoStore: ObservableObject {
    @Published var state: AppStateData = AppStateData()
    @Published var currentMonth: String? = nil // nil = tutti i mesi
    @Published var statsMonth: String? = nil // nil = tutti i mesi
    
    @Published var syncMode: SyncMode = .localOnly
    @Published var lastSyncDate: Date? = nil
    @Published var toastMessage: String? = nil
    @Published var toastIsError: Bool = false
    
    private let localFileName = "saldo-dati.json"
    private let bookmarkKey = "saldo_external_file_bookmark_v1"
    private var toastTask: Task<Void, Never>?
    #if os(iOS)
    private var activePickerCoordinator: IOSDocumentPickerCoordinator?
    #endif
    
    init() {
        loadInitialData()
    }
    
    // MARK: - Toast
    func showToast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.toastMessage = message
            self.toastIsError = isError
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.toastMessage = nil
                }
            }
        }
    }
    
    // MARK: - Persistence & File Sync
    var localFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(localFileName)
    }
    
    #if os(macOS)
    var iCloudDriveRootURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: cloudDocs.path) {
            return cloudDocs
        }
        return nil
    }
    #endif
    
    var activeFileURL: URL {
        switch syncMode {
        case .localOnly:
            return localFileURL
        case .iCloudContainer(let url), .linkedExternalFile(let url):
            return url
        }
    }
    
    var activeFolderDisplay: String {
        SyncMode.friendlyFolderName(for: activeFileURL)
    }
    
    var activeFileNameDisplay: String {
        activeFileURL.lastPathComponent
    }
    
    private var ubiquityFileURL: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let docs = container.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs.appendingPathComponent(localFileName)
    }
    
    func loadInitialData() {
        #if os(macOS)
        // Migrate from old sandboxed container if present and localFileURL doesn't exist yet
        if !FileManager.default.fileExists(atPath: localFileURL.path) {
            let legacyContainerFile = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.tommasonguyen.saldomovimenti/Data/Documents/\(localFileName)")
            if FileManager.default.fileExists(atPath: legacyContainerFile.path) {
                try? FileManager.default.copyItem(at: legacyContainerFile, to: localFileURL)
            }
        }
        #endif
        
        // 1. Check if user linked an external file via security-scoped bookmark (e.g., in File / iCloud Drive / Finder)
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    saveBookmark(for: url)
                }
                if let loaded = readStateFromURL(url) {
                    self.state = normalizeState(loaded)
                    self.syncMode = .linkedExternalFile(url)
                    self.lastSyncDate = Date()
                    scheduleNotifications()
                    return
                }
            }
            #if os(macOS)
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if let loaded = readStateFromURL(url) {
                    self.state = normalizeState(loaded)
                    self.syncMode = .linkedExternalFile(url)
                    self.lastSyncDate = Date()
                    scheduleNotifications()
                    return
                }
            }
            #endif
        }
        
        // 2. Check native iCloud Ubiquity container if available
        if let iCloudURL = ubiquityFileURL {
            self.syncMode = .iCloudContainer(iCloudURL)
            if FileManager.default.fileExists(atPath: iCloudURL.path),
               let loaded = readStateFromURL(iCloudURL) {
                self.state = normalizeState(loaded)
                self.lastSyncDate = Date()
                scheduleNotifications()
                return
            }
        }
        
        // 3. Fallback to local Documents directory (visible in iOS App "File" › Su iPhone › Saldo e Movimenti, and ~/Documents on macOS)
        if FileManager.default.fileExists(atPath: localFileURL.path),
           let loaded = readStateFromURL(localFileURL) {
            self.state = normalizeState(loaded)
        } else {
            let _ = writeStateToURL(localFileURL)
        }
        scheduleNotifications()
    }
    
    private func normalizeState(_ data: AppStateData) -> AppStateData {
        var copy = data
        if copy.promemoria == nil {
            copy.promemoria = ReminderSettings()
        }
        for i in copy.movimenti.indices {
            copy.movimenti[i].categoria = CategorieCatalog.migrate(
                categoria: copy.movimenti[i].categoria,
                tipo: copy.movimenti[i].tipo
            )
        }
        for i in copy.ricorrenti.indices {
            copy.ricorrenti[i].categoria = CategorieCatalog.migrate(
                categoria: copy.ricorrenti[i].categoria,
                tipo: copy.ricorrenti[i].tipo
            )
        }
        for i in copy.indefinite.indices {
            copy.indefinite[i].categoria = CategorieCatalog.migrate(
                categoria: copy.indefinite[i].categoria,
                tipo: copy.indefinite[i].tipo
            )
        }
        return copy
    }
    
    func saveState(silent: Bool = false) {
        state = normalizeState(state)
        let localSaved = writeStateToURL(localFileURL)
        var externalSaved = false
        
        switch syncMode {
        case .localOnly:
            if let iCloudURL = ubiquityFileURL {
                syncMode = .iCloudContainer(iCloudURL)
                externalSaved = writeStateToURL(iCloudURL)
            }
        case .iCloudContainer(let url):
            externalSaved = writeStateToURL(url)
        case .linkedExternalFile(let url):
            externalSaved = writeStateToURL(url)
        }
        
        if externalSaved {
            lastSyncDate = Date()
        }
        
        if !silent {
            if externalSaved {
                showToast("Salvato in \(activeFolderDisplay) › \(activeFileNameDisplay) ✓")
            } else if localSaved {
                showToast("Salvato in \(activeFolderDisplay) ✓")
            } else {
                showToast("Errore salvataggio", isError: true)
            }
        }
        
        scheduleNotifications()
    }
    
    func scheduleNotifications() {
        let upcoming = calcUpcomingDeadlines(daysAhead: 60)
        let settings = state.promemoria ?? ReminderSettings()
        Task {
            await NotificationManager.shared.rescheduleNotifications(upcoming: upcoming, settings: settings)
        }
    }
    
    // MARK: - File Read/Write (Compatible with HTML JSON & saldo-sync-v1)
    func encodeStateJSON(useSyncEnvelope: Bool = true) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if useSyncEnvelope {
            let iso = ISO8601DateFormatter().string(from: Date())
            let env = SyncFileEnvelope(updatedAt: iso, data: state)
            return try? encoder.encode(env)
        } else {
            return try? encoder.encode(state)
        }
    }
    
    func decodeStateJSON(_ data: Data) -> AppStateData? {
        let decoder = JSONDecoder()
        if let env = try? decoder.decode(SyncFileEnvelope.self, from: data),
           env._format == "saldo-sync-v1" {
            return env.data
        }
        if let raw = try? decoder.decode(AppStateData.self, from: data) {
            return raw
        }
        return nil
    }
    
    private func writeStateToURL(_ url: URL) -> Bool {
        guard let jsonData = encodeStateJSON(useSyncEnvelope: true) else { return false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        
        do {
            var coordinatorError: NSError?
            var writeSuccess = false
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { newURL in
                do {
                    try jsonData.write(to: newURL, options: .atomic)
                    writeSuccess = true
                } catch {
                    print("Write error: \(error)")
                }
            }
            if coordinatorError != nil {
                try jsonData.write(to: url, options: .atomic)
                return true
            }
            return writeSuccess
        } catch {
            print("Failed to write to \(url): \(error)")
            return false
        }
    }
    
    func readStateFromURL(_ url: URL) -> AppStateData? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        
        // Trigger iCloud download if needed
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        
        var resultData: Data?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            resultData = try? Data(contentsOf: readURL)
        }
        if resultData == nil {
            resultData = try? Data(contentsOf: url)
        }
        guard let data = resultData, !data.isEmpty else { return nil }
        return decodeStateJSON(data)
    }
    
    private func saveBookmark(for url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            return
        }
        #if os(macOS)
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
        #endif
    }
    
    func linkExternalSyncFile(url: URL, loadExistingIfPresent: Bool) {
        saveBookmark(for: url)
        syncMode = .linkedExternalFile(url)
        if loadExistingIfPresent, let existing = readStateFromURL(url),
           (!existing.movimenti.isEmpty || !existing.ricorrenti.isEmpty || !existing.indefinite.isEmpty || existing.saldoIniziale != 0) {
            self.state = normalizeState(existing)
        }
        saveState(silent: true)
        showToast("Salvato in \(activeFolderDisplay) › \(activeFileNameDisplay) ✓")
    }
    
    // MARK: - Native Folder & File Pickers (macOS Finder & iOS App "File")
    #if os(iOS)
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) ?? scenes.flatMap({ $0.windows }).first,
              var top = window.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
    
    func chooseSaveLocation() {
        #if os(macOS)
        // Force macOS Save Panel to open in expanded folder-browser mode so the user always sees Finder/iCloud Drive folders
        UserDefaults.standard.set(true, forKey: "NSNavPanelExpandedStateForSaveMode")
        let panel = NSSavePanel()
        panel.title = "Salva su File (Scegli cartella)"
        panel.message = "Scegli la cartella (es. iCloud Drive / App File, Documenti o Scrivania) in cui salvare il file"
        panel.prompt = "Salva nella cartella"
        panel.nameFieldStringValue = activeFileNameDisplay
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.json]
        if case .linkedExternalFile(let existingURL) = syncMode {
            panel.directoryURL = existingURL.deletingLastPathComponent()
        } else if let iCloudDrive = iCloudDriveRootURL {
            panel.directoryURL = iCloudDrive
        } else {
            panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        if panel.runModal() == .OK, let url = panel.url {
            let _ = writeStateToURL(url)
            linkExternalSyncFile(url: url, loadExistingIfPresent: false)
        }
        #elseif os(iOS)
        guard let topVC = topViewController(),
              let jsonData = encodeStateJSON(useSyncEnvelope: true) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(activeFileNameDisplay)
        try? jsonData.write(to: tempURL, options: .atomic)
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: false)
        picker.shouldShowFileExtensions = true
        let coord = IOSDocumentPickerCoordinator { [weak self] url in
            Task { @MainActor in
                self?.linkExternalSyncFile(url: url, loadExistingIfPresent: false)
            }
        }
        self.activePickerCoordinator = coord
        picker.delegate = coord
        topVC.present(picker, animated: true)
        #endif
    }
    
    func openExistingSyncFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Apri da cartella File"
        panel.message = "Scegli un file JSON esistente da qualsiasi cartella (es. iCloud Drive o Documenti) per collegarlo"
        panel.prompt = "Apri e collega"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let iCloudDrive = iCloudDriveRootURL {
            panel.directoryURL = iCloudDrive
        }
        if panel.runModal() == .OK, let url = panel.url {
            linkExternalSyncFile(url: url, loadExistingIfPresent: true)
        }
        #elseif os(iOS)
        guard let topVC = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: false)
        picker.shouldShowFileExtensions = true
        let coord = IOSDocumentPickerCoordinator { [weak self] url in
            Task { @MainActor in
                self?.linkExternalSyncFile(url: url, loadExistingIfPresent: true)
            }
        }
        self.activePickerCoordinator = coord
        picker.delegate = coord
        topVC.present(picker, animated: true)
        #endif
    }
    
    func exportBackupFile() {
        let backupName = "saldo-backup-\(DateHelpers.todayYMD()).json"
        guard let jsonData = encodeStateJSON(useSyncEnvelope: false) else { return }
        #if os(macOS)
        UserDefaults.standard.set(true, forKey: "NSNavPanelExpandedStateForSaveMode")
        let panel = NSSavePanel()
        panel.title = "Esporta Backup JSON"
        panel.prompt = "Esporta"
        panel.nameFieldStringValue = backupName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? jsonData.write(to: url, options: .atomic)
            showToast("Backup esportato in \(SyncMode.friendlyFolderName(for: url)) ✓")
        }
        #elseif os(iOS)
        guard let topVC = topViewController() else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupName)
        try? jsonData.write(to: tempURL, options: .atomic)
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        picker.shouldShowFileExtensions = true
        let coord = IOSDocumentPickerCoordinator { [weak self] url in
            Task { @MainActor in
                self?.showToast("Backup esportato in \(SyncMode.friendlyFolderName(for: url)) ✓")
            }
        }
        self.activePickerCoordinator = coord
        picker.delegate = coord
        topVC.present(picker, animated: true)
        #endif
    }
    
    func importBackupFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Importa Backup JSON"
        panel.prompt = "Importa"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            if importJSONData(data) {
                showToast("Dati importati da \(url.lastPathComponent) ✓")
            }
        }
        #elseif os(iOS)
        guard let topVC = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        let coord = IOSDocumentPickerCoordinator { [weak self] url in
            Task { @MainActor in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    _ = self?.importJSONData(data)
                }
            }
        }
        self.activePickerCoordinator = coord
        picker.delegate = coord
        topVC.present(picker, animated: true)
        #endif
    }
    
    func chooseStatementFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Importa Movimenti (PDF / CSV / TXT)"
        panel.message = "Seleziona il file PDF o CSV della lista movimenti o dell'estratto conto"
        panel.prompt = "Importa movimenti"
        panel.allowedContentTypes = [.pdf, .commaSeparatedText, .tabSeparatedText, .plainText, .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            importBankStatementFromURL(url)
        }
        #elseif os(iOS)
        guard let topVC = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .commaSeparatedText, .tabSeparatedText, .plainText, .data], asCopy: true)
        let coord = IOSDocumentPickerCoordinator { [weak self] url in
            Task { @MainActor in
                self?.importBankStatementFromURL(url)
            }
        }
        self.activePickerCoordinator = coord
        picker.delegate = coord
        topVC.present(picker, animated: true)
        #endif
    }
    
    #if os(macOS)
    func revealActiveFileInFinder() {
        let url = activeFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            let _ = writeStateToURL(url)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
    
    func reloadFromSyncedFile() {
        let url = activeFileURL
        if let loaded = readStateFromURL(url) {
            self.state = normalizeState(loaded)
            let _ = writeStateToURL(localFileURL)
            self.lastSyncDate = Date()
            scheduleNotifications()
            showToast("Ricaricato da \(activeFolderDisplay) ✓")
        } else {
            showToast("Lettura file fallita", isError: true)
        }
    }
    
    func disconnectExternalSyncFile() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        if let iCloudURL = ubiquityFileURL {
            syncMode = .iCloudContainer(iCloudURL)
        } else {
            syncMode = .localOnly
        }
        showToast("Tornato alla cartella predefinita: \(activeFolderDisplay)")
    }
    
    func importJSONData(_ data: Data) -> Bool {
        guard let decoded = decodeStateJSON(data) else {
            showToast("File JSON non valido", isError: true)
            return false
        }
        self.state = normalizeState(decoded)
        saveState()
        return true
    }
    
    func resetAllData() {
        self.state = AppStateData()
        saveState()
    }
    
    // MARK: - Core Financial Logic (100% faithful to HTML)
    func expandRicorrente(_ r: SpesaRicorrente, untilDate: Date) -> [MovimentoEspanso] {
        var occorrenze: [MovimentoEspanso] = []
        guard let start = DateHelpers.parseYMD(r.dataInizio) else { return [] }
        let end = (r.dataFine.flatMap { DateHelpers.parseYMD($0) }) ?? untilDate
        let stop = min(end, untilDate)
        
        let cal = Calendar(identifier: .gregorian)
        var d = start
        var safety = 0
        while d <= stop && safety < 5000 {
            let ymdStr = DateHelpers.ymd(d)
            occorrenze.append(MovimentoEspanso(
                id: "\(r.id)_\(ymdStr)",
                tipo: r.tipo,
                data: ymdStr,
                importo: r.importo,
                categoria: r.categoria,
                descrizione: "\(r.descrizione) (ricorrente)",
                source: .ricorrente,
                refId: r.id
            ))
            switch r.frequenza {
            case .giornaliera: d = cal.date(byAdding: .day, value: 1, to: d) ?? stop.addingTimeInterval(86400)
            case .settimanale: d = cal.date(byAdding: .day, value: 7, to: d) ?? stop.addingTimeInterval(86400)
            case .mensile: d = cal.date(byAdding: .month, value: 1, to: d) ?? stop.addingTimeInterval(86400)
            case .bimestrale: d = cal.date(byAdding: .month, value: 2, to: d) ?? stop.addingTimeInterval(86400)
            case .trimestrale: d = cal.date(byAdding: .month, value: 3, to: d) ?? stop.addingTimeInterval(86400)
            case .semestrale: d = cal.date(byAdding: .month, value: 6, to: d) ?? stop.addingTimeInterval(86400)
            case .annuale: d = cal.date(byAdding: .year, value: 1, to: d) ?? stop.addingTimeInterval(86400)
            }
            safety += 1
        }
        return occorrenze
    }
    
    func expandIndefinita(_ i: SpesaIndefinita, untilDate: Date) -> [MovimentoEspanso] {
        var occorrenze: [MovimentoEspanso] = []
        guard let start = DateHelpers.parseYMD(i.dataInizio) else { return [] }
        let end: Date
        if !i.attiva, let ch = i.dataChiusura, let chDate = DateHelpers.parseYMD(ch) {
            end = chDate
        } else {
            end = untilDate
        }
        let stop = min(end, untilDate)
        let cal = Calendar(identifier: .gregorian)
        var d = start
        var safety = 0
        while d <= stop && safety < 1000 {
            let ymdStr = DateHelpers.ymd(d)
            occorrenze.append(MovimentoEspanso(
                id: "\(i.id)_\(ymdStr)",
                tipo: i.tipo,
                data: ymdStr,
                importo: i.importo,
                categoria: i.categoria,
                descrizione: "\(i.descrizione) (indefinita)",
                source: .indefinita,
                refId: i.id
            ))
            d = cal.date(byAdding: .month, value: 1, to: d) ?? stop.addingTimeInterval(86400)
            safety += 1
        }
        return occorrenze
    }
    
    func getAllMovimenti() -> [MovimentoEspanso] {
        let today = Date()
        var all: [MovimentoEspanso] = state.movimenti.map { m in
            MovimentoEspanso(
                id: m.id,
                tipo: m.tipo,
                data: m.data,
                importo: m.importo,
                categoria: m.categoria,
                descrizione: m.descrizione,
                source: .manuale,
                refId: nil
            )
        }
        for r in state.ricorrenti {
            all.append(contentsOf: expandRicorrente(r, untilDate: today))
        }
        for i in state.indefinite {
            all.append(contentsOf: expandIndefinita(i, untilDate: today))
        }
        return all.sorted { $0.data > $1.data }
    }
    
    func calcSaldo() -> Double {
        let all = getAllMovimenti()
        var saldo = state.saldoIniziale
        for m in all {
            saldo += (m.tipo == .entrata ? 1.0 : -1.0) * m.importo
        }
        return saldo
    }
    
    func calcMonthStats(key: String?) -> (income: Double, expense: Double, net: Double) {
        let all = getAllMovimenti()
        var income = 0.0
        var expense = 0.0
        for m in all {
            if let key = key, !key.isEmpty, DateHelpers.monthKey(m.data) != key {
                continue
            }
            if m.tipo == .entrata {
                income += m.importo
            } else {
                expense += m.importo
            }
        }
        return (income, expense, income - expense)
    }
    
    func calcRecurringMonthly() -> Double {
        var total = 0.0
        let today = DateHelpers.todayYMD()
        for r in state.ricorrenti {
            if let fine = r.dataFine, !fine.isEmpty, fine < today { continue }
            if r.dataInizio > today { continue }
            let sign = r.tipo == .entrata ? 1.0 : -1.0
            total += sign * r.importo * r.frequenza.monthlyFactor
        }
        for i in state.indefinite {
            if !i.attiva { continue }
            let sign = i.tipo == .entrata ? 1.0 : -1.0
            total += sign * i.importo
        }
        return total
    }
    
    func calcBudgetSuggerito() -> BudgetCalculationResult {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let today = cal.startOfDay(for: now)
        
        var comps = cal.dateComponents([.year, .month], from: today)
        comps.month = (comps.month ?? 1) + 1
        comps.day = 0
        let endOfMonth = cal.date(from: comps) ?? today
        
        let diffDays = cal.dateComponents([.day], from: today, to: endOfMonth).day ?? 0
        let daysLeft = max(1, diffDays + 1)
        
        let saldo = calcSaldo()
        var upcoming = 0.0
        let todayYmd = DateHelpers.ymd(today)
        let endYmd = DateHelpers.ymd(endOfMonth)
        
        for r in state.ricorrenti {
            if r.dataInizio > endYmd { continue }
            let occorrenze = expandRicorrente(r, untilDate: endOfMonth)
            for o in occorrenze {
                if o.data > todayYmd && o.data <= endYmd {
                    upcoming += (r.tipo == .entrata ? -1.0 : 1.0) * r.importo
                }
            }
        }
        
        let lastDayOfMonth = cal.component(.day, from: endOfMonth)
        for i in state.indefinite {
            if !i.attiva { continue }
            if i.dataInizio > endYmd { continue }
            guard let startDate = DateHelpers.parseYMD(i.dataInizio) else { continue }
            let startDay = cal.component(.day, from: startDate)
            let dueDay = min(startDay, lastDayOfMonth)
            var dueComps = cal.dateComponents([.year, .month], from: today)
            dueComps.day = dueDay
            if let dueDate = cal.date(from: dueComps), DateHelpers.ymd(dueDate) > todayYmd {
                upcoming += (i.tipo == .entrata ? -1.0 : 1.0) * i.importo
            }
        }
        
        let risparmio = state.budget.risparmioMensile
        let soglia = state.budget.sogliaMinima
        let spendibile = saldo - upcoming - risparmio - soglia
        
        return BudgetCalculationResult(
            saldo: saldo,
            upcoming: upcoming,
            risparmio: risparmio,
            soglia: soglia,
            spendibile: spendibile,
            daysLeft: daysLeft,
            endOfMonth: endYmd
        )
    }
    
    /// Computes upcoming recurring and indefinite occurrences from today up to `daysAhead` days in the future.
    func calcUpcomingDeadlines(daysAhead: Int = 60) -> [ProssimaScadenza] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let todayYmd = DateHelpers.ymd(today)
        guard let horizon = cal.date(byAdding: .day, value: daysAhead, to: today) else { return [] }
        let horizonYmd = DateHelpers.ymd(horizon)
        
        var items: [ProssimaScadenza] = []
        
        for r in state.ricorrenti {
            guard r.promemoriaAttivo ?? true else { continue }
            let occs = expandRicorrente(r, untilDate: horizon)
            for o in occs where o.data >= todayYmd && o.data <= horizonYmd {
                if let d = DateHelpers.parseYMD(o.data) {
                    items.append(ProssimaScadenza(
                        id: o.id,
                        titolo: r.descrizione,
                        importo: r.importo,
                        tipo: r.tipo,
                        categoria: r.categoria,
                        dataScadenza: d,
                        dataYMD: o.data,
                        source: .ricorrente,
                        refId: r.id
                    ))
                }
            }
        }
        
        for i in state.indefinite where i.attiva {
            guard i.promemoriaAttivo ?? true else { continue }
            let occs = expandIndefinita(i, untilDate: horizon)
            for o in occs where o.data >= todayYmd && o.data <= horizonYmd {
                if let d = DateHelpers.parseYMD(o.data) {
                    items.append(ProssimaScadenza(
                        id: o.id,
                        titolo: i.descrizione,
                        importo: i.importo,
                        tipo: i.tipo,
                        categoria: i.categoria,
                        dataScadenza: d,
                        dataYMD: o.data,
                        source: .indefinita,
                        refId: i.id
                    ))
                }
            }
        }
        
        return items.sorted { $0.dataYMD < $1.dataYMD }
    }
    
    // MARK: - CRUD Mutations
    func addMovimento(tipo: TipoMovimento, data: String, importo: Double, categoria: String, descrizione: String) {
        let mov = Movimento(
            id: DateHelpers.uid(),
            tipo: tipo,
            data: data,
            importo: importo,
            categoria: categoria,
            descrizione: descrizione
        )
        state.movimenti.append(mov)
        saveState()
    }
    
    func deleteMovimento(id: String) {
        state.movimenti.removeAll { $0.id == id }
        saveState()
    }
    
    func addRicorrente(tipo: TipoMovimento, importo: Double, frequenza: FrequenzaRicorrente, dataInizio: String, dataFine: String?, categoria: String, descrizione: String, promemoriaAttivo: Bool = true) {
        let ric = SpesaRicorrente(
            id: DateHelpers.uid(),
            tipo: tipo,
            importo: importo,
            frequenza: frequenza,
            dataInizio: dataInizio,
            dataFine: (dataFine?.isEmpty == true) ? nil : dataFine,
            categoria: categoria,
            descrizione: descrizione,
            promemoriaAttivo: promemoriaAttivo
        )
        state.ricorrenti.append(ric)
        saveState()
    }
    
    func toggleRicorrenteReminder(id: String) {
        guard let idx = state.ricorrenti.firstIndex(where: { $0.id == id }) else { return }
        let current = state.ricorrenti[idx].promemoriaAttivo ?? true
        state.ricorrenti[idx].promemoriaAttivo = !current
        saveState()
    }
    
    func deleteRicorrente(id: String) {
        state.ricorrenti.removeAll { $0.id == id }
        saveState()
    }
    
    func addIndefinita(tipo: TipoMovimento, importo: Double, dataInizio: String, categoria: String, descrizione: String, promemoriaAttivo: Bool = true) {
        let ind = SpesaIndefinita(
            id: DateHelpers.uid(),
            tipo: tipo,
            importo: importo,
            dataInizio: dataInizio,
            categoria: categoria,
            descrizione: descrizione,
            attiva: true,
            dataChiusura: nil,
            promemoriaAttivo: promemoriaAttivo
        )
        state.indefinite.append(ind)
        saveState()
    }
    
    func closeIndefinita(id: String) {
        guard let idx = state.indefinite.firstIndex(where: { $0.id == id }) else { return }
        state.indefinite[idx].attiva = false
        state.indefinite[idx].dataChiusura = DateHelpers.todayYMD()
        saveState()
    }
    
    func reopenIndefinita(id: String) {
        guard let idx = state.indefinite.firstIndex(where: { $0.id == id }) else { return }
        state.indefinite[idx].attiva = true
        state.indefinite[idx].dataChiusura = nil
        saveState()
    }
    
    func toggleIndefinitaReminder(id: String) {
        guard let idx = state.indefinite.firstIndex(where: { $0.id == id }) else { return }
        let current = state.indefinite[idx].promemoriaAttivo ?? true
        state.indefinite[idx].promemoriaAttivo = !current
        saveState()
    }
    
    func deleteIndefinita(id: String) {
        state.indefinite.removeAll { $0.id == id }
        saveState()
    }
    
    // MARK: - Bank Statement Importer (PDF / CSV / TSV / TXT)
    @Published var pendingStatementRows: [ParsedStatementRow] = []
    @Published var showStatementPreviewSheet: Bool = false
    
    func importBankStatementFromURL(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        
        let ext = url.pathExtension.lowercased()
        var extractedRows: [ParsedStatementRow] = []
        
        if ext == "pdf" {
            if let pdf = PDFDocument(url: url) {
                var allLines: [String] = []
                for i in 0..<pdf.pageCount {
                    if let pageText = pdf.page(at: i)?.string {
                        let lines = pageText.components(separatedBy: .newlines)
                        allLines.append(contentsOf: lines)
                    }
                }
                extractedRows = parseStatementLines(allLines)
            }
        } else {
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                extractedRows = parseCSVOrTextStatement(text)
            }
        }
        
        if extractedRows.isEmpty {
            showToast("Nessun movimento trovato nel file selezionato", isError: true)
            return
        }
        
        self.pendingStatementRows = extractedRows
        self.showStatementPreviewSheet = true
    }
    
    func confirmStatementImport() {
        let chosen = pendingStatementRows.filter { $0.selected }
        guard !chosen.isEmpty else {
            showToast("Nessun movimento selezionato", isError: true)
            return
        }
        for r in chosen {
            switch r.importMode {
            case .singolo:
                state.movimenti.append(Movimento(
                    id: DateHelpers.uid(),
                    tipo: r.tipo,
                    data: r.data,
                    importo: r.importo,
                    categoria: r.categoria,
                    descrizione: r.descrizione
                ))
            case .ricorrenteMensile:
                state.ricorrenti.append(SpesaRicorrente(
                    id: DateHelpers.uid(),
                    tipo: r.tipo,
                    importo: r.importo,
                    frequenza: .mensile,
                    dataInizio: r.data,
                    dataFine: nil,
                    categoria: r.categoria,
                    descrizione: r.descrizione,
                    promemoriaAttivo: true
                ))
            case .indefinitaMensile:
                state.indefinite.append(SpesaIndefinita(
                    id: DateHelpers.uid(),
                    tipo: r.tipo,
                    importo: r.importo,
                    dataInizio: r.data,
                    categoria: r.categoria,
                    descrizione: r.descrizione,
                    attiva: true,
                    dataChiusura: nil,
                    promemoriaAttivo: true
                ))
            }
        }
        showStatementPreviewSheet = false
        pendingStatementRows = []
        saveState()
        showToast("Importati \(chosen.count) movimenti ✓")
    }
    
    private func parseCSVOrTextStatement(_ text: String) -> [ParsedStatementRow] {
        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { return [] }
        
        let sample = rawLines.prefix(10).joined(separator: "\n")
        let sep: Character = {
            let semicolons = sample.filter { $0 == ";" }.count
            let tabs = sample.filter { $0 == "\t" }.count
            let commas = sample.filter { $0 == "," }.count
            if semicolons >= commas && semicolons >= tabs && semicolons > 0 { return ";" }
            if tabs >= commas && tabs > 0 { return "\t" }
            return ","
        }()
        
        var rows: [ParsedStatementRow] = []
        for line in rawLines {
            let cols = splitCSVLine(line, separator: sep)
            if let parsed = parseColumnsRow(cols) {
                rows.append(parsed)
            } else if let fallback = parseFreeTextLine(line) {
                rows.append(fallback)
            }
        }
        return rows
    }
    
    private func splitCSVLine(_ line: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == separator && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
    
    private func parseColumnsRow(_ cols: [String]) -> ParsedStatementRow? {
        guard cols.count >= 2 else { return nil }
        var foundDate: String? = nil
        var numbers: [Double] = []
        var textParts: [String] = []
        
        for col in cols {
            let cleaned = col.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            if foundDate == nil, let d = parseBankDate(cleaned) {
                foundDate = d
                continue
            }
            if let amt = parseBankAmount(cleaned) {
                numbers.append(amt)
                continue
            }
            if cleaned.count > 1 {
                textParts.append(cleaned)
            }
        }
        
        guard let dateYMD = foundDate, let rawAmount = numbers.first, abs(rawAmount) > 0.001 else {
            return nil
        }
        let desc = textParts.joined(separator: " · ").isEmpty ? "Movimento estratto conto" : textParts.joined(separator: " · ")
        if desc.lowercased().range(of: #"saldo\s+(iniziale|finale|contabile|disponibile)"#, options: .regularExpression) != nil {
            return nil
        }
        return makeStatementRow(date: dateYMD, rawAmount: rawAmount, description: desc)
    }
    
    private func parseStatementLines(_ lines: [String]) -> [ParsedStatementRow] {
        // Infer dominant 4-digit year from the document
        var yearCounts: [Int: Int] = [:]
        let yearRegex = try? NSRegularExpression(pattern: #"\b(20\d{2})\b"#)
        for line in lines {
            let ns = line as NSString
            let matches = yearRegex?.matches(in: line, range: NSRange(location: 0, length: ns.length)) ?? []
            for m in matches {
                if let y = Int(ns.substring(with: m.range)) {
                    yearCounts[y, default: 0] += 1
                }
            }
        }
        let defaultYear = yearCounts.max(by: { $0.value < $1.value })?.key ?? Calendar.current.component(.year, from: Date())
        
        struct PendingTx {
            var date: String
            var descParts: [String]
            var rawAmount: Double?
            var rawAmountToken: String?
        }
        
        var results: [ParsedStatementRow] = []
        var currentTx: PendingTx? = nil
        var lastSeenDate: String? = nil
        var preDescBuffer: [String] = []
        var stopSection = false
        
        func finalize(_ tx: PendingTx?) {
            guard let tx = tx, let amt = tx.rawAmount, abs(amt) >= 0.01 else { return }
            let fullDesc = tx.descParts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if fullDesc.lowercased().range(of: #"^(saldo\s+(iniziale|finale|precedente|contabile|disponibile)|totale\s+(movimenti|addebiti|accrediti|operazioni|entrate|uscite)|riporto)\b"#, options: .regularExpression) != nil {
                return
            }
            if let row = makeStatementRow(date: tx.date, rawAmount: amt, rawToken: tx.rawAmountToken ?? "", description: fullDesc) {
                results.append(row)
            }
        }
        
        // Pre-split lines that contain multiple concatenated transactions
        var expandedLines: [String] = []
        let splitDatePattern = #"\b(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}|\d{4}[\/\.\-]\d{1,2}[\/\.\-]\d{1,2})\b"#
        let splitDateRegex = try? NSRegularExpression(pattern: splitDatePattern, options: [.caseInsensitive])
        let amtCheckPattern = #"[+\-−]?\s*(?:€|EUR)?\s*(?:\d{1,3}(?:[\.'’\s]\d{3})+|\d+)[,\.]\d{2}"#
        
        for rawLine in lines {
            let trimmed = rawLine
                .replacingOccurrences(of: "\u{2212}", with: "-")
                .replacingOccurrences(of: "\u{2013}", with: "-")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let ns = trimmed as NSString
            let dMatches = splitDateRegex?.matches(in: trimmed, range: NSRange(location: 0, length: ns.length)) ?? []
            if dMatches.count > 1 {
                var segStart = 0
                for i in 1..<dMatches.count {
                    let prevEnd = dMatches[i - 1].range.location + dMatches[i - 1].range.length
                    let currStart = dMatches[i].range.location
                    let between = ns.substring(with: NSRange(location: prevEnd, length: max(0, currStart - prevEnd))).trimmingCharacters(in: .whitespaces)
                    if between.range(of: amtCheckPattern, options: .regularExpression) != nil || between.count > 10 {
                        let piece = ns.substring(with: NSRange(location: segStart, length: currStart - segStart)).trimmingCharacters(in: .whitespaces)
                        if !piece.isEmpty { expandedLines.append(piece) }
                        segStart = currStart
                    }
                }
                let tail = ns.substring(from: segStart).trimmingCharacters(in: .whitespaces)
                if !tail.isEmpty { expandedLines.append(tail) }
            } else {
                expandedLines.append(trimmed)
            }
        }
        
        for trimmed in expandedLines {
            let lower = trimmed.lowercased()
            if lower.range(of: #"^\s*(data\s*contabile|data\s*operazione)\b.*\b(descrizione|causale|addebiti|accrediti|importo)"#, options: .regularExpression) != nil {
                stopSection = false
                continue
            }
            if lower.range(of: #"^\s*(riepilogo\s+spese|calcolo\s+interessi|numeri\s+debitori|numeri\s+creditori)"#, options: .regularExpression) != nil {
                stopSection = true
                continue
            }
            if stopSection { continue }
            if lower.range(of: #"^\s*(pagina|pag\.|foglio)\s+\d+"#, options: .regularExpression) != nil { continue }
            if lower.range(of: #"^\s*(saldo\s+(iniziale|finale|precedente|contabile\s+al|disponibile\s+al)|totale\s+(movimenti|addebiti|accrediti|operazioni)|riporto|a\s+riportare)\b"#, options: .regularExpression) != nil {
                continue
            }
            
            let analyzed = analyzeStatementLine(trimmed, defaultYear: defaultYear)
            let startsWithTime = analyzed.desc.range(of: #"^(?:[01]?\d|2[0-3]):[0-5]\d\b"#, options: .regularExpression) != nil
            
            if let d = analyzed.leadingDate {
                lastSeenDate = d
                if var existing = currentTx, existing.rawAmount == nil {
                    // Date / Data Valuta on 2nd line of a transaction that had no amount yet
                    existing.date = d
                    if !analyzed.desc.isEmpty { existing.descParts.append(analyzed.desc) }
                    if let amt = analyzed.amount {
                        existing.rawAmount = amt
                        existing.rawAmountToken = analyzed.amountToken
                    }
                    currentTx = existing
                    continue
                }
                if let existing = currentTx, existing.rawAmount != nil {
                    finalize(existing)
                    currentTx = nil
                }
                var newTx = PendingTx(
                    date: d,
                    descParts: [],
                    rawAmount: analyzed.amount,
                    rawAmountToken: analyzed.amountToken
                )
                if !preDescBuffer.isEmpty && analyzed.desc.isEmpty {
                    newTx.descParts.append(contentsOf: preDescBuffer)
                }
                preDescBuffer.removeAll()
                if !analyzed.desc.isEmpty {
                    newTx.descParts.append(analyzed.desc)
                }
                currentTx = newTx
            } else {
                // Line does NOT start with a date
                if startsWithTime, let prevDate = lastSeenDate {
                    if let existing = currentTx, existing.rawAmount != nil {
                        finalize(existing)
                    }
                    currentTx = PendingTx(
                        date: prevDate,
                        descParts: analyzed.desc.isEmpty ? [] : [analyzed.desc],
                        rawAmount: analyzed.amount,
                        rawAmountToken: analyzed.amountToken
                    )
                } else if let amt = analyzed.amount {
                    if var existing = currentTx, existing.rawAmount == nil {
                        if !analyzed.desc.isEmpty {
                            existing.descParts.append(analyzed.desc)
                        }
                        existing.rawAmount = amt
                        existing.rawAmountToken = analyzed.amountToken
                        currentTx = existing
                    } else if let prevDate = lastSeenDate {
                        finalize(currentTx)
                        var parts: [String] = []
                        if !preDescBuffer.isEmpty {
                            parts.append(contentsOf: preDescBuffer)
                            preDescBuffer.removeAll()
                        }
                        if !analyzed.desc.isEmpty {
                            parts.append(analyzed.desc)
                        }
                        currentTx = PendingTx(
                            date: prevDate,
                            descParts: parts,
                            rawAmount: amt,
                            rawAmountToken: analyzed.amountToken
                        )
                    }
                } else if !analyzed.desc.isEmpty {
                    if var existing = currentTx, existing.descParts.count < 5 {
                        existing.descParts.append(analyzed.desc)
                        currentTx = existing
                    } else {
                        preDescBuffer.append(analyzed.desc)
                        if preDescBuffer.count > 2 { preDescBuffer.removeFirst() }
                    }
                }
            }
        }
        
        finalize(currentTx)
        return results
    }
    
    private func analyzeStatementLine(_ line: String, defaultYear: Int) -> (leadingDate: String?, amount: Double?, amountToken: String?, desc: String) {
        var work = line.replacingOccurrences(of: #"^(?:[*•·\-]|\d{1,2}\))\s+"#, with: "", options: .regularExpression)
        var foundDate: String? = nil
        
        let leadingDatePattern = #"^(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}|\d{4}[\/\.\-]\d{1,2}[\/\.\-]\d{1,2}|\d{1,2}[\s\.\/\-]+(?:gen|feb|mar|apr|mag|giu|lug|ago|set|ott|nov|dic|jan|may|jun|jul|aug|sep|oct|dec)[a-z\.]*(?:[\s\.\/\-]+\d{2,4})?|\d{1,2}[\/\.]\d{1,2})\b"#
        if let r = work.range(of: leadingDatePattern, options: [.regularExpression, .caseInsensitive]) {
            let token = String(work[r])
            let remainder = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            let isShort = token.count <= 5 && !token.contains("-")
            if !isShort || remainder.isEmpty || remainder.range(of: #"\d+[,\.]\d{2}"#, options: .regularExpression) != nil || !remainder.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }) {
                if let parsed = parseBankDate(token, defaultYear: defaultYear) {
                    foundDate = parsed
                    work = remainder
                    if let r2 = work.range(of: leadingDatePattern, options: [.regularExpression, .caseInsensitive]) {
                        let token2 = String(work[r2])
                        if parseBankDate(token2, defaultYear: defaultYear) != nil {
                            work = String(work[r2.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }
        
        // Find all valid currency amounts in work
        let amountPattern = #"(?:^|\s|[€$£])([+\-−]?\s*(?:€|EUR)?\s*(?:\d{1,3}(?:[\.'’\s]\d{3})+|\d+)[,\.]\d{2}\s*(?:€|EUR|[+\-]|\bD\b|\bA\b)?)(?=\s|$|[€$£])"#
        let nsWork = work as NSString
        let regex = try? NSRegularExpression(pattern: amountPattern, options: [.caseInsensitive])
        let matches = regex?.matches(in: work, range: NSRange(location: 0, length: nsWork.length)) ?? []
        
        struct AmtCandidate {
            let val: Double
            let token: String
            let range: NSRange
        }
        var candidates: [AmtCandidate] = []
        for m in matches {
            guard m.numberOfRanges > 1 else { continue }
            let capRange = m.range(at: 1)
            let rawToken = nsWork.substring(with: capRange).trimmingCharacters(in: .whitespaces)
            let before = nsWork.substring(to: capRange.location).lowercased()
            let after = nsWork.substring(from: capRange.location + capRange.length).lowercased()
            
            if before.range(of: #"(?:\bdel|\bil|\bal|\bdal|\bore|\bh\.|\bdata|\bvaluta|\bn\.|\btasso|\bcambio)\s*$"#, options: .regularExpression) != nil {
                continue
            }
            if after.range(of: #"^(?:[\/\.\-]\d{2,4}|\s*%)"#, options: .regularExpression) != nil {
                continue
            }
            if let v = parseBankAmount(rawToken), abs(v) >= 0.01 {
                candidates.append(AmtCandidate(val: v, token: rawToken, range: capRange))
            }
        }
        
        var chosen: AmtCandidate? = nil
        if candidates.count == 1 {
            chosen = candidates[0]
        } else if candidates.count >= 2 {
            let secondLast = candidates[candidates.count - 2]
            let last = candidates[candidates.count - 1]
            let secondHasSign = secondLast.token.contains("-") || secondLast.token.contains("+")
            let lastHasSign = last.token.contains("-") || last.token.contains("+")
            chosen = (secondHasSign && !lastHasSign) ? secondLast : last
        }
        
        var desc = work
        for c in candidates.reversed() {
            if let swiftRange = Range(c.range, in: desc) {
                desc.replaceSubrange(swiftRange, with: " ")
            }
        }
        desc = desc.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–—·|;:,€"))
        
        return (foundDate, chosen?.val, chosen?.token, desc)
    }
    
    private func parseFreeTextLine(_ line: String) -> ParsedStatementRow? {
        let rows = parseStatementLines([line])
        return rows.first
    }
    
    private func makeStatementRow(date: String, rawAmount: Double, rawToken: String = "", description: String) -> ParsedStatementRow? {
        let cleanDesc = description.isEmpty ? "Operazione bancaria" : description
        let lower = cleanDesc.lowercased()
        let isPositiveKeyword = lower.range(of: #"emolument|stipend|salar|retribuz|cedolino|accredit|bonifico\s+(?:sepa\s+)?(?:a\s+(?:vostro|tuo|suo)\s+favore|da\s+|in\s+entrata)|versament|rimbors|divid|cedol|pensione|giroconto\s+da"#, options: .regularExpression) != nil
        let isNegativeKeyword = lower.range(of: #"addebit|pagamento|pagobancomat|pos\b|carta\s+di|prelievo|sdd|utenza|commission|bollo|imposta|f24|cbill|pagopa|mav|rav|bonifico\s+(?:sepa\s+)?(?:disposto|a\s+favore\s+di)"#, options: .regularExpression) != nil
        
        let hasPlus = rawToken.contains("+") || rawToken.uppercased().hasSuffix("A")
        let hasMinus = rawToken.contains("-") || rawToken.contains("−") || rawToken.uppercased().hasSuffix("D")
        
        let tipo: TipoMovimento
        if hasMinus || rawAmount < 0 {
            tipo = .uscita
        } else if hasPlus {
            tipo = .entrata
        } else if isPositiveKeyword && !isNegativeKeyword {
            tipo = .entrata
        } else if isNegativeKeyword && !isPositiveKeyword {
            tipo = .uscita
        } else {
            tipo = .uscita
        }
        
        let importo = (abs(rawAmount) * 100).rounded() / 100
        let cat = Self.guessCategory(for: cleanDesc, tipo: tipo)
        let isDup = state.movimenti.contains {
            $0.data == date && abs($0.importo - importo) < 0.01 && $0.tipo == tipo
        }
        return ParsedStatementRow(
            selected: !isDup,
            tipo: tipo,
            data: date,
            importo: importo,
            categoria: cat,
            descrizione: cleanDesc,
            importMode: .singolo,
            isDuplicate: isDup
        )
    }
    
    private func parseBankDate(_ str: String, defaultYear: Int = Calendar.current.component(.year, from: Date())) -> String? {
        let s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return s
        }
        // Textual month (e.g. 12 ott 2026, 12 ott)
        let monthsMap: [String: Int] = [
            "gen":1, "feb":2, "mar":3, "apr":4, "mag":5, "giu":6, "lug":7, "ago":8, "set":9, "ott":10, "nov":11, "dic":12,
            "jan":1, "may":5, "jun":6, "jul":7, "aug":8, "sep":9, "oct":10, "dec":12
        ]
        let lower = s.lowercased()
        let tokens = lower.components(separatedBy: CharacterSet(charactersIn: " /.-")).filter { !$0.isEmpty }
        if tokens.count >= 2, let d = Int(tokens[0]), tokens[1].count >= 3 {
            let monKey = String(tokens[1].prefix(3))
            if let m = monthsMap[monKey], d >= 1 && d <= 31 {
                var y = defaultYear
                if tokens.count >= 3, let parsedY = Int(tokens[2]) {
                    y = parsedY < 100 ? (parsedY >= 70 ? 1900 + parsedY : 2000 + parsedY) : parsedY
                }
                return String(format: "%04d-%02d-%02d", y, m, d)
            }
        }
        
        let parts = s.components(separatedBy: CharacterSet(charactersIn: "/.-"))
        if parts.count == 3 {
            if parts[0].count == 4, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
                if m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                    return String(format: "%04d-%02d-%02d", y, m, d)
                }
            }
            if let d = Int(parts[0]), let m = Int(parts[1]), var y = Int(parts[2]) {
                if y < 100 { y += y >= 70 ? 1900 : 2000 }
                if m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                    return String(format: "%04d-%02d-%02d", y, m, d)
                }
            }
        } else if parts.count == 2, let d = Int(parts[0]), let m = Int(parts[1]) {
            if m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                return String(format: "%04d-%02d-%02d", defaultYear, m, d)
            }
        }
        return nil
    }
    
    private func parseBankAmount(_ str: String) -> Double? {
        var s = str
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        var isNeg = false
        if s.contains("-") || (s.hasPrefix("(") && s.hasSuffix(")")) || s.uppercased().hasSuffix("D") {
            isNeg = true
        }
        s = s.replacingOccurrences(of: #"[€$£\s+()A-Za-z'’\-]"#, with: "", options: .regularExpression)
        guard !s.isEmpty else { return nil }
        if s.contains(",") && s.contains(".") {
            if let lastComma = s.lastIndex(of: ","), let lastDot = s.lastIndex(of: ".") {
                if lastComma > lastDot {
                    s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                } else {
                    s = s.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if s.contains(",") {
            let parts = s.components(separatedBy: ",")
            if parts.count == 2 && parts[1].count <= 2 {
                s = parts[0] + "." + parts[1]
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        }
        guard let val = Double(s) else { return nil }
        return isNeg ? -abs(val) : val
    }
    
    static func guessCategory(for description: String, tipo: TipoMovimento) -> String {
        let t = description.lowercased()
        if tipo == .entrata {
            if t.range(of: #"emolument|stipend|salar|busta\s*paga|competenze|retribuz|cedolino"#, options: .regularExpression) != nil { return "stipendio" }
            if t.range(of: #"bonus|premi|tredicesim|quattordicesim|welfare"#, options: .regularExpression) != nil { return "bonus" }
            if t.range(of: #"rimbors|storno|cashback|accredito\s*spese|nota\s*credito"#, options: .regularExpression) != nil { return "rimborso" }
            if t.range(of: #"divid|cedol|interessi|invest|titoli|btp|etf"#, options: .regularExpression) != nil { return "investimenti" }
            if t.range(of: #"regal|donaz"#, options: .regularExpression) != nil { return "regalo_e" }
            return "altro_e"
        } else {
            if t.range(of: #"esselunga|conad|coop|carrefour|lidl|eurospin|aldi|pam|penny|despar|tigros|bennet|iper|supermerc|spesa|aliment|md\s|todis|crai"#, options: .regularExpression) != nil { return "spesa" }
            if t.range(of: #"ristor|pizzer|trattor|osteri|bar\s|caffe|sushi|burger|mcdonald|poke|deliveroo|glovo|just\s*eat|starbucks|pub|gelat|pasticcer"#, options: .regularExpression) != nil { return "ristoranti" }
            if t.range(of: #"eni\s|q8|ip\s|tamoil|esso|shell|benz|carburant|gasolio|distributore"#, options: .regularExpression) != nil { return "carburante" }
            if t.range(of: #"trenitalia|italo|atm\s|atac|telepass|unipolmove|autostrad|uber|taxi|parchegg|ryanair|easyjet|ita\s*airways|mezzi|metro"#, options: .regularExpression) != nil { return "trasporti" }
            if t.range(of: #"affitt|locazion|mutuo|rata\s*mutuo|condomin|ikea|leroy\s*merlin"#, options: .regularExpression) != nil { return "casa" }
            if t.range(of: #"enel|plenitude|edison|a2a|iren|hera|acea|sorgenia|tim\s|vodafone|windtre|fastweb|iliad|sky|luce|gas|acqua|bollett|tari"#, options: .regularExpression) != nil { return "bollette" }
            if t.range(of: #"netflix|spotify|disney|dazn|amazon\s*prime|prime\s*video|apple\.com\/bill|icloud|google\s*\*|youtube|chatgpt|openai|playstation"#, options: .regularExpression) != nil { return "abbonamenti" }
            if t.range(of: #"farmac|parafarmac|medic|dentist|ospedal|clinic|ticket\s*sanit|visita|ottic"#, options: .regularExpression) != nil { return "salute" }
            if t.range(of: #"zara|h&m|uniqlo|zalando|nike|adidas|calzedonia|intimissimi|ovs|decathlon|abbigliament|scarp"#, options: .regularExpression) != nil { return "abbigliamento" }
            if t.range(of: #"booking|airbnb|hotel|alberg|expedia|viagg|vacanz"#, options: .regularExpression) != nil { return "viaggi" }
            if t.range(of: #"palestr|virgin\s*active|mcfit|fitactive|sport|piscin|padel|tennis"#, options: .regularExpression) != nil { return "sport" }
            if t.range(of: #"mediaworld|unieuro|euronics|apple\s*store|amazon|amzn|ebay|aliexpress"#, options: .regularExpression) != nil { return "tecnologia" }
            if t.range(of: #"commission|imposta\s*di\s*bollo|canone\s*conto|f24|agenzia\s*entrate|inps|cbill|pagopa|mav|tass"#, options: .regularExpression) != nil { return "tasse" }
            return "altro_u"
        }
    }
}

enum StatementImportMode: String, CaseIterable, Identifiable {
    case singolo = "Movimento singolo"
    case ricorrenteMensile = "Ricorrente mensile"
    case indefinitaMensile = "Indefinita mensile"
    
    var id: String { rawValue }
}

struct ParsedStatementRow: Identifiable {
    let id = UUID()
    var selected: Bool
    var tipo: TipoMovimento
    var data: String
    var importo: Double
    var categoria: String
    var descrizione: String
    var importMode: StatementImportMode
    var isDuplicate: Bool
}

