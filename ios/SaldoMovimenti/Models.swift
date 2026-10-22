//
//  Models.swift
//  SaldoMovimenti
//

import Foundation
import SwiftUI

enum TipoMovimento: String, Codable, CaseIterable, Identifiable {
    case entrata = "entrata"
    case uscita = "uscita"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .entrata: return "Entrata"
        case .uscita: return "Uscita"
        }
    }
}

enum FrequenzaRicorrente: String, Codable, CaseIterable, Identifiable {
    case giornaliera = "giornaliera"
    case settimanale = "settimanale"
    case mensile = "mensile"
    case bimestrale = "bimestrale"
    case trimestrale = "trimestrale"
    case semestrale = "semestrale"
    case annuale = "annuale"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .giornaliera: return "Giornaliera"
        case .settimanale: return "Settimanale"
        case .mensile: return "Mensile"
        case .bimestrale: return "Bimestrale"
        case .trimestrale: return "Trimestrale"
        case .semestrale: return "Semestrale"
        case .annuale: return "Annuale"
        }
    }
    
    var monthlyFactor: Double {
        switch self {
        case .giornaliera: return 30.0
        case .settimanale: return 4.33
        case .mensile: return 1.0
        case .bimestrale: return 0.5
        case .trimestrale: return 1.0 / 3.0
        case .semestrale: return 1.0 / 6.0
        case .annuale: return 1.0 / 12.0
        }
    }
}

struct CategoriaItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let kind: TipoMovimento
    
    var color: Color {
        Color(hex: colorHex)
    }
}

enum CategorieCatalog {
    static let all: [CategoriaItem] = [
        // Uscite
        CategoriaItem(id: "spesa", name: "Spesa alimentare", icon: "🛒", colorHex: "#22c55e", kind: .uscita),
        CategoriaItem(id: "ristoranti", name: "Ristoranti e bar", icon: "🍽️", colorHex: "#f97316", kind: .uscita),
        CategoriaItem(id: "trasporti", name: "Trasporti", icon: "🚗", colorHex: "#3b82f6", kind: .uscita),
        CategoriaItem(id: "carburante", name: "Carburante", icon: "⛽", colorHex: "#0ea5e9", kind: .uscita),
        CategoriaItem(id: "casa", name: "Casa / Affitto", icon: "🏠", colorHex: "#8b5cf6", kind: .uscita),
        CategoriaItem(id: "bollette", name: "Bollette", icon: "💡", colorHex: "#eab308", kind: .uscita),
        CategoriaItem(id: "abbonamenti", name: "Abbonamenti", icon: "📱", colorHex: "#06b6d4", kind: .uscita),
        CategoriaItem(id: "salute", name: "Salute", icon: "🩺", colorHex: "#ef4444", kind: .uscita),
        CategoriaItem(id: "abbigliamento", name: "Abbigliamento", icon: "👕", colorHex: "#ec4899", kind: .uscita),
        CategoriaItem(id: "tempolibero", name: "Tempo libero", icon: "🎉", colorHex: "#a855f7", kind: .uscita),
        CategoriaItem(id: "viaggi", name: "Viaggi", icon: "✈️", colorHex: "#14b8a6", kind: .uscita),
        CategoriaItem(id: "regali", name: "Regali", icon: "🎁", colorHex: "#f43f5e", kind: .uscita),
        CategoriaItem(id: "istruzione", name: "Istruzione", icon: "📚", colorHex: "#6366f1", kind: .uscita),
        CategoriaItem(id: "tecnologia", name: "Tecnologia", icon: "💻", colorHex: "#64748b", kind: .uscita),
        CategoriaItem(id: "sport", name: "Sport e benessere", icon: "🏋️", colorHex: "#84cc16", kind: .uscita),
        CategoriaItem(id: "animali", name: "Animali", icon: "🐾", colorHex: "#d97706", kind: .uscita),
        CategoriaItem(id: "tasse", name: "Tasse e finanze", icon: "💼", colorHex: "#475569", kind: .uscita),
        CategoriaItem(id: "altro_u", name: "Altre spese", icon: "📦", colorHex: "#94a3b8", kind: .uscita),
        // Entrate
        CategoriaItem(id: "stipendio", name: "Stipendio", icon: "💰", colorHex: "#22c55e", kind: .entrata),
        CategoriaItem(id: "bonus", name: "Bonus / Premi", icon: "🎯", colorHex: "#10b981", kind: .entrata),
        CategoriaItem(id: "rimborso", name: "Rimborsi", icon: "↩️", colorHex: "#06b6d4", kind: .entrata),
        CategoriaItem(id: "investimenti", name: "Investimenti", icon: "📈", colorHex: "#3b82f6", kind: .entrata),
        CategoriaItem(id: "regalo_in", name: "Regali ricevuti", icon: "🎁", colorHex: "#ec4899", kind: .entrata),
        CategoriaItem(id: "altro_e", name: "Altre entrate", icon: "💸", colorHex: "#94a3b8", kind: .entrata)
    ]
    
    static let byId: [String: CategoriaItem] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    
    static func get(_ id: String?) -> CategoriaItem {
        guard let id = id, !id.isEmpty else {
            return CategoriaItem(id: "sconosciuta", name: "Senza categoria", icon: "❔", colorHex: "#64748b", kind: .uscita)
        }
        return byId[id] ?? CategoriaItem(id: id, name: id, icon: "❔", colorHex: "#64748b", kind: .uscita)
    }
    
    static func forKind(_ kind: TipoMovimento) -> [CategoriaItem] {
        all.filter { $0.kind == kind }
    }
    
    static func migrate(categoria: String?, tipo: TipoMovimento) -> String {
        guard let raw = categoria, !raw.isEmpty else {
            return tipo == .entrata ? "altro_e" : "altro_u"
        }
        if byId[raw] != nil { return raw }
        let t = raw.lowercased()
        if t.range(of: "spesa|aliment|super|grocery", options: .regularExpression) != nil { return "spesa" }
        if t.range(of: "risto|bar|caff|pizz", options: .regularExpression) != nil { return "ristoranti" }
        if t.range(of: "benz|carbur|gas", options: .regularExpression) != nil { return "carburante" }
        if t.range(of: "trasp|bus|treno|metro|taxi|uber", options: .regularExpression) != nil { return "trasporti" }
        if t.range(of: "affitt|mutuo|casa|condom", options: .regularExpression) != nil { return "casa" }
        if t.range(of: "bollet|luce|gas|acqua|wifi|inter", options: .regularExpression) != nil { return "bollette" }
        if t.range(of: "abbon|netflix|spotify|prime|disney|apple", options: .regularExpression) != nil { return "abbonamenti" }
        if t.range(of: "salu|medic|farmac|dentist|denti", options: .regularExpression) != nil { return "salute" }
        if t.range(of: "abbig|vesti|scarp", options: .regularExpression) != nil { return "abbigliamento" }
        if t.range(of: "viagg|hotel|volo|aere", options: .regularExpression) != nil { return "viaggi" }
        if t.range(of: "regal", options: .regularExpression) != nil { return "regali" }
        if t.range(of: "scuol|libr|cors|istru|univ", options: .regularExpression) != nil { return "istruzione" }
        if t.range(of: "sport|palestr|gym", options: .regularExpression) != nil { return "sport" }
        if t.range(of: "anim|gatt|cane", options: .regularExpression) != nil { return "animali" }
        if t.range(of: "tecno|pc|comput|telefon", options: .regularExpression) != nil { return "tecnologia" }
        if t.range(of: "tass|bance|banca|comm|finanz", options: .regularExpression) != nil { return "tasse" }
        if t.range(of: "stipend|salar", options: .regularExpression) != nil { return "stipendio" }
        if t.range(of: "bonus|prem", options: .regularExpression) != nil { return "bonus" }
        if t.range(of: "rimbors", options: .regularExpression) != nil { return "rimborso" }
        if t.range(of: "invest|divid|borsa", options: .regularExpression) != nil { return "investimenti" }
        return tipo == .entrata ? "altro_e" : "altro_u"
    }
}

struct Movimento: Identifiable, Codable, Equatable {
    var id: String
    var tipo: TipoMovimento
    var data: String // YYYY-MM-DD
    var importo: Double
    var categoria: String
    var descrizione: String
}

struct SpesaRicorrente: Identifiable, Codable, Equatable {
    var id: String
    var tipo: TipoMovimento
    var importo: Double
    var frequenza: FrequenzaRicorrente
    var dataInizio: String // YYYY-MM-DD
    var dataFine: String? // YYYY-MM-DD or nil
    var categoria: String
    var descrizione: String
    var promemoriaAttivo: Bool? // Optional for backward compatibility with HTML JSON
}

struct SpesaIndefinita: Identifiable, Codable, Equatable {
    var id: String
    var tipo: TipoMovimento
    var importo: Double
    var dataInizio: String // YYYY-MM-DD
    var categoria: String
    var descrizione: String
    var attiva: Bool
    var dataChiusura: String?
    var promemoriaAttivo: Bool? // Optional for backward compatibility
}

struct BudgetSettings: Codable, Equatable {
    var risparmioMensile: Double = 0
    var sogliaMinima: Double = 0
}

struct ReminderSettings: Codable, Equatable {
    var abilitati: Bool = true
    var giorniPrima: Int = 1 // 0 = stesso giorno, 1 = 1 giorno prima, 2 = 2 giorni prima, 3 = 3 giorni prima
    var ancheGiornoScadenza: Bool = true
    var oraNotifica: Int = 9
    var minutoNotifica: Int = 0
}

struct AppStateData: Codable, Equatable {
    var saldoIniziale: Double = 0
    var movimenti: [Movimento] = []
    var ricorrenti: [SpesaRicorrente] = []
    var indefinite: [SpesaIndefinita] = []
    var budget: BudgetSettings = BudgetSettings()
    var promemoria: ReminderSettings? = ReminderSettings()
}

// Wrapper for `saldo-sync-v1` format used by the HTML file's File System Access API
struct SyncFileEnvelope: Codable {
    var _format: String = "saldo-sync-v1"
    var updatedAt: String
    var data: AppStateData
}

enum FonteMovimento: String {
    case manuale = "manuale"
    case ricorrente = "ricorrente"
    case indefinita = "indefinita"
    
    var label: String {
        switch self {
        case .manuale: return "Manuale"
        case .ricorrente: return "Ricorrente"
        case .indefinita: return "Indefinita"
        }
    }
}

struct MovimentoEspanso: Identifiable, Equatable {
    let id: String
    let tipo: TipoMovimento
    let data: String
    let importo: Double
    let categoria: String
    let descrizione: String
    let source: FonteMovimento
    let refId: String?
}

struct ProssimaScadenza: Identifiable, Equatable {
    let id: String
    let titolo: String
    let importo: Double
    let tipo: TipoMovimento
    let categoria: String
    let dataScadenza: Date
    let dataYMD: String
    let source: FonteMovimento
    let refId: String
}

// MARK: - Helpers
enum DateHelpers {
    static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()
    
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "it_IT")
        f.currencyCode = "EUR"
        return f
    }()
    
    static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "€ %.2f", value)
    }
    
    static func todayYMD() -> String {
        ymdFormatter.string(from: Date())
    }
    
    static func parseYMD(_ s: String) -> Date? {
        ymdFormatter.date(from: s)
    }
    
    static func ymd(_ d: Date) -> String {
        ymdFormatter.string(from: d)
    }
    
    static func formatDisplay(_ s: String) -> String {
        guard let d = parseYMD(s) else { return s }
        return displayFormatter.string(from: d)
    }
    
    static func monthKey(_ dateStr: String) -> String {
        guard dateStr.count >= 7 else { return "" }
        return String(dateStr.prefix(7))
    }
    
    static func monthLabel(_ key: String?) -> String {
        guard let key = key, !key.isEmpty else { return "Tutti i mesi" }
        let parts = key.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), (1...12).contains(m) else { return key }
        let names = ["Gen","Feb","Mar","Apr","Mag","Giu","Lug","Ago","Set","Ott","Nov","Dic"]
        return "\(names[m - 1]) \(parts[0])"
    }
    
    static func shiftMonth(_ currentKey: String?, delta: Int) -> String {
        let base = currentKey ?? String(todayYMD().prefix(7))
        let parts = base.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else {
            return String(todayYMD().prefix(7))
        }
        var comps = DateComponents()
        comps.year = y
        comps.month = m + delta
        comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        if let d = cal.date(from: comps) {
            return String(ymd(d).prefix(7))
        }
        return base
    }
    
    static func uid() -> String {
        let timeStr = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let randStr = String(Int.random(in: 100000...999999), radix: 36)
        return timeStr + randStr
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 148, 163, 184)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static let appBg = Color(hex: "#0f172a")
    static let appPanel = Color(hex: "#1e293b")
    static let appPanel2 = Color(hex: "#334155")
    static let appText = Color(hex: "#e2e8f0")
    static let appMuted = Color(hex: "#94a3b8")
    static let appAccent = Color(hex: "#38bdf8")
    static let appGreen = Color(hex: "#22c55e")
    static let appRed = Color(hex: "#ef4444")
    static let appYellow = Color(hex: "#eab308")
    static let appBorder = Color(hex: "#334155")
}
