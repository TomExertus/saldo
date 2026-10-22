//
//  TabViews.swift
//  SaldoMovimenti
//

import SwiftUI

// MARK: - Shared UI Helpers
struct PanelBox<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: () -> Content
    
    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.appText)
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.appMuted)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

struct BadgeView: View {
    let source: FonteMovimento
    
    var body: some View {
        Text(source.label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bgColor)
            .foregroundColor(fgColor)
            .clipShape(Capsule())
    }
    
    private var bgColor: Color {
        switch source {
        case .manuale: return Color.appMuted.opacity(0.2)
        case .ricorrente: return Color.appAccent.opacity(0.2)
        case .indefinita: return Color.appYellow.opacity(0.2)
        }
    }
    
    private var fgColor: Color {
        switch source {
        case .manuale: return .appMuted
        case .ricorrente: return .appAccent
        case .indefinita: return .appYellow
        }
    }
}

// MARK: - 1. Tab Movimenti
struct MovimentiTabView: View {
    @ObservedObject var store: SaldoStore
    var onImportStatement: (() -> Void)? = nil
    
    @State private var tipo: TipoMovimento = .uscita
    @State private var data: Date = Date()
    @State private var importoStr: String = ""
    @State private var categoria: String = "spesa"
    @State private var descrizione: String = ""
    
    @State private var searchText: String = ""
    @State private var filterTipo: String = "" // "", "entrata", "uscita"
    @State private var itemToDelete: String? = nil
    
    var availableCategories: [CategoriaItem] {
        CategorieCatalog.forKind(tipo)
    }
    
    var filteredMovimenti: [MovimentoEspanso] {
        var all = store.getAllMovimenti()
        if let m = store.currentMonth, !m.isEmpty {
            all = all.filter { DateHelpers.monthKey($0.data) == m }
        }
        if !filterTipo.isEmpty {
            all = all.filter { $0.tipo.rawValue == filterTipo }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            all = all.filter {
                $0.descrizione.lowercased().contains(q) ||
                $0.categoria.lowercased().contains(q) ||
                CategorieCatalog.get($0.categoria).name.lowercased().contains(q)
            }
        }
        return all
    }
    
    var body: some View {
        VStack(spacing: 18) {
            // Card Importa Movimenti
            if let onImportStatement = onImportStatement {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("🏦 Importa Movimenti (Lista Movimenti / Estratto Conto)")
                                .font(.headline)
                                .foregroundColor(.appText)
                            Text("PDF · CSV · TXT")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appGreen.opacity(0.22))
                                .foregroundColor(.appGreen)
                                .clipShape(Capsule())
                        }
                        Text("Riconosce in automatico spese, addebiti POS/SDD, stipendi (emolumenti), bonifici e accrediti con anteprima di controllo.")
                            .font(.footnote)
                            .foregroundColor(.appMuted)
                    }
                    Spacer()
                    Button(action: onImportStatement) {
                        Label("Scegli file movimenti…", systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.appGreen)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.appGreen.opacity(0.16), Color.appAccent.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appGreen.opacity(0.45), lineWidth: 1)
                )
            }
            
            // Form Aggiungi movimento
            PanelBox(title: "Aggiungi movimento") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        FormFieldBox(label: "TIPO") {
                            Picker("Tipo", selection: $tipo) {
                                ForEach(TipoMovimento.allCases) { t in
                                    Text(t.label).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: tipo) { _, newValue in
                                if let first = CategorieCatalog.forKind(newValue).first {
                                    categoria = first.id
                                }
                            }
                        }
                        
                        FormFieldBox(label: "DATA") {
                            DatePicker("", selection: $data, displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormFieldBox(label: "IMPORTO (€)") {
                            TextField("0,00", text: $importoStr)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.appBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                        
                        FormFieldBox(label: "CATEGORIA") {
                            Picker("Categoria", selection: $categoria) {
                                ForEach(availableCategories) { c in
                                    Text("\(c.icon) \(c.name)").tag(c.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                    
                    FormFieldBox(label: "DESCRIZIONE") {
                        TextField("Descrizione del movimento", text: $descrizione)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    }
                    
                    Button(action: submitMovimento) {
                        Text("Aggiungi movimento")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appAccent)
                            .foregroundColor(.appBg)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Storico movimenti
            PanelBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Storico movimenti")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Spacer()
                        MonthNavigatorView(
                            label: DateHelpers.monthLabel(store.currentMonth),
                            onPrev: { store.currentMonth = DateHelpers.shiftMonth(store.currentMonth, delta: -1) },
                            onNext: { store.currentMonth = DateHelpers.shiftMonth(store.currentMonth, delta: 1) },
                            onAll: { store.currentMonth = nil }
                        )
                    }
                    
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.appMuted)
                            TextField("Cerca…", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(9)
                        .background(Color.appBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        
                        Picker("Filtro", selection: $filterTipo) {
                            Text("Tutti i tipi").tag("")
                            Text("Solo entrate").tag("entrata")
                            Text("Solo uscite").tag("uscita")
                        }
                        .frame(maxWidth: 160)
                    }
                    
                    let list = filteredMovimenti
                    if list.isEmpty {
                        Text("Nessun movimento da mostrare.")
                            .font(.subheadline)
                            .foregroundColor(.appMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(list) { m in
                                let cat = CategorieCatalog.get(m.categoria)
                                HStack(spacing: 10) {
                                    Text(cat.icon)
                                        .font(.title3)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(m.descrizione.isEmpty ? cat.name : m.descrizione)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.appText)
                                        HStack(spacing: 6) {
                                            Text(DateHelpers.formatDisplay(m.data))
                                                .font(.caption)
                                                .foregroundColor(.appMuted)
                                            Text("·")
                                                .foregroundColor(.appMuted)
                                            Text(cat.name)
                                                .font(.caption)
                                                .foregroundColor(.appMuted)
                                            BadgeView(source: m.source)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(m.tipo == .entrata ? "+" : "−") \(DateHelpers.formatCurrency(m.importo))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(m.tipo == .entrata ? .appGreen : .appRed)
                                    
                                    if m.source == .manuale {
                                        Button(action: { itemToDelete = m.id }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .padding(7)
                                                .background(Color.appRed.opacity(0.2))
                                                .foregroundColor(.appRed)
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text("auto")
                                            .font(.caption2)
                                            .foregroundColor(.appMuted)
                                            .frame(width: 28)
                                    }
                                }
                                .padding(.vertical, 10)
                                Divider().overlay(Color.appBorder)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Eliminare questo movimento?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let id = itemToDelete {
                    store.deleteMovimento(id: id)
                }
                itemToDelete = nil
            }
            Button("Annulla", role: .cancel) { itemToDelete = nil }
        }
    }
    
    private func submitMovimento() {
        let val = Double(importoStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard val > 0 else {
            store.showToast("Importo non valido", isError: true)
            return
        }
        store.addMovimento(
            tipo: tipo,
            data: DateHelpers.ymd(data),
            importo: val,
            categoria: categoria,
            descrizione: descrizione.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        importoStr = ""
        descrizione = ""
        data = Date()
    }
}

// MARK: - 2. Tab Statistiche
struct StatisticheTabView: View {
    @ObservedObject var store: SaldoStore
    
    var filteredMovimenti: [MovimentoEspanso] {
        let all = store.getAllMovimenti()
        if let m = store.statsMonth, !m.isEmpty {
            return all.filter { DateHelpers.monthKey($0.data) == m }
        }
        return all
    }
    
    var body: some View {
        let list = filteredMovimenti
        let expenseTotals = aggregate(list: list, kind: .uscita)
        let incomeTotals = aggregate(list: list, kind: .entrata)
        
        VStack(spacing: 18) {
            PanelBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Spese per categoria")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Spacer()
                        MonthNavigatorView(
                            label: DateHelpers.monthLabel(store.statsMonth),
                            onPrev: { store.statsMonth = DateHelpers.shiftMonth(store.statsMonth, delta: -1) },
                            onNext: { store.statsMonth = DateHelpers.shiftMonth(store.statsMonth, delta: 1) },
                            onAll: { store.statsMonth = nil }
                        )
                    }
                    Text("Vedi dove vanno i tuoi soldi: ogni barra è proporzionale alla spesa totale del periodo.")
                        .font(.footnote)
                        .foregroundColor(.appMuted)
                    
                    CategoryBarsListView(entries: expenseTotals, kind: .uscita)
                }
            }
            
            PanelBox(title: "Entrate per categoria") {
                CategoryBarsListView(entries: incomeTotals, kind: .entrata)
            }
        }
    }
    
    private func aggregate(list: [MovimentoEspanso], kind: TipoMovimento) -> [(id: String, amount: Double)] {
        var dict: [String: Double] = [:]
        for m in list where m.tipo == kind {
            let catId = m.categoria.isEmpty ? (kind == .entrata ? "altro_e" : "altro_u") : m.categoria
            dict[catId, default: 0] += m.importo
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.amount > $1.amount }
    }
}

struct CategoryBarsListView: View {
    let entries: [(id: String, amount: Double)]
    let kind: TipoMovimento
    
    var body: some View {
        if entries.isEmpty {
            Text("Nessun\(kind == .entrata ? "a entrata" : "a spesa") nel periodo selezionato.")
                .font(.subheadline)
                .foregroundColor(.appMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            let total = entries.reduce(0.0) { $0 + $1.amount }
            let maxVal = max(entries.first?.amount ?? 1.0, 0.01)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Totale:")
                        .font(.footnote)
                        .foregroundColor(.appMuted)
                    Text(DateHelpers.formatCurrency(total))
                        .font(.footnote.bold())
                        .foregroundColor(.appText)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                ForEach(entries, id: \.id) { item in
                    let cat = CategorieCatalog.get(item.id)
                    let pct = (item.amount / total) * 100.0
                    let widthRatio = CGFloat(item.amount / maxVal)
                    
                    HStack(spacing: 12) {
                        Text(cat.icon)
                            .font(.title3)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 4) {
                                Text(cat.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.appText)
                                Text("· \(String(format: "%.1f", pct))%")
                                    .font(.caption)
                                    .foregroundColor(.appMuted)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 8)
                                    Capsule()
                                        .fill(cat.color)
                                        .frame(width: max(6, geo.size.width * widthRatio), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        
                        Spacer()
                        
                        Text(DateHelpers.formatCurrency(item.amount))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(kind == .entrata ? .appGreen : .appRed)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 3. Tab Ricorrenti
struct RicorrentiTabView: View {
    @ObservedObject var store: SaldoStore
    
    @State private var tipo: TipoMovimento = .uscita
    @State private var importoStr: String = ""
    @State private var frequenza: FrequenzaRicorrente = .mensile
    @State private var dataInizio: Date = Date()
    @State private var usaDataFine: Bool = false
    @State private var dataFine: Date = Date()
    @State private var categoria: String = "abbonamenti"
    @State private var descrizione: String = ""
    @State private var promemoriaAttivo: Bool = true
    
    @State private var itemToDelete: String? = nil
    
    var availableCategories: [CategoriaItem] {
        CategorieCatalog.forKind(tipo)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            PanelBox(title: "Aggiungi spesa ricorrente") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        FormFieldBox(label: "TIPO") {
                            Picker("Tipo", selection: $tipo) {
                                ForEach(TipoMovimento.allCases) { t in
                                    Text(t.label).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: tipo) { _, newValue in
                                if let first = CategorieCatalog.forKind(newValue).first {
                                    categoria = first.id
                                }
                            }
                        }
                        
                        FormFieldBox(label: "IMPORTO (€)") {
                            TextField("0,00", text: $importoStr)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.appBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                        
                        FormFieldBox(label: "FREQUENZA") {
                            Picker("Frequenza", selection: $frequenza) {
                                ForEach(FrequenzaRicorrente.allCases) { f in
                                    Text(f.label).tag(f)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                        
                        FormFieldBox(label: "DATA INIZIO") {
                            DatePicker("", selection: $dataInizio, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        FormFieldBox(label: "DATA FINE (OPZIONALE)") {
                            HStack {
                                Toggle("", isOn: $usaDataFine)
                                    .labelsHidden()
                                if usaDataFine {
                                    DatePicker("", selection: $dataFine, displayedComponents: .date)
                                        .labelsHidden()
                                } else {
                                    Text("Nessuna scadenza")
                                        .font(.caption)
                                        .foregroundColor(.appMuted)
                                }
                            }
                        }
                        
                        FormFieldBox(label: "CATEGORIA") {
                            Picker("Categoria", selection: $categoria) {
                                ForEach(availableCategories) { c in
                                    Text("\(c.icon) \(c.name)").tag(c.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                    
                    FormFieldBox(label: "DESCRIZIONE") {
                        TextField("es. Abbonamento Netflix", text: $descrizione)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    }
                    
                    Toggle(isOn: $promemoriaAttivo) {
                        Label("Invia promemoria notifica prima della scadenza", systemImage: "bell.badge")
                            .font(.footnote)
                            .foregroundColor(.appText)
                    }
                    
                    Button(action: submitRicorrente) {
                        Text("Aggiungi ricorrente")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appAccent)
                            .foregroundColor(.appBg)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            PanelBox(
                title: "Spese ricorrenti attive",
                subtitle: "Le rate vengono calcolate automaticamente fino alla data odierna (o alla data fine)."
            ) {
                if store.state.ricorrenti.isEmpty {
                    Text("Nessuna spesa ricorrente.")
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.state.ricorrenti) { r in
                            let cat = CategorieCatalog.get(r.categoria)
                            let remOn = r.promemoriaAttivo ?? true
                            HStack(spacing: 10) {
                                Text(cat.icon)
                                    .font(.title3)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.descrizione)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appText)
                                    HStack(spacing: 6) {
                                        Text(r.frequenza.label)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.appAccent)
                                        Text("· Dal \(DateHelpers.formatDisplay(r.dataInizio))")
                                            .font(.caption)
                                            .foregroundColor(.appMuted)
                                        if let fine = r.dataFine, !fine.isEmpty {
                                            Text("al \(DateHelpers.formatDisplay(fine))")
                                                .font(.caption)
                                                .foregroundColor(.appMuted)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(r.tipo == .entrata ? "+" : "−") \(DateHelpers.formatCurrency(r.importo))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(r.tipo == .entrata ? .appGreen : .appRed)
                                
                                Button(action: { store.toggleRicorrenteReminder(id: r.id) }) {
                                    Image(systemName: remOn ? "bell.fill" : "bell.slash")
                                        .font(.caption)
                                        .padding(7)
                                        .background(remOn ? Color.appAccent.opacity(0.2) : Color.appPanel2)
                                        .foregroundColor(remOn ? .appAccent : .appMuted)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .help(remOn ? "Promemoria attivo" : "Promemoria disattivato")
                                
                                Button(action: { itemToDelete = r.id }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .padding(7)
                                        .background(Color.appRed.opacity(0.2))
                                        .foregroundColor(.appRed)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(Color.appBorder)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Eliminare questa spesa ricorrente? Tutte le occorrenze passate non saranno più conteggiate.", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let id = itemToDelete {
                    store.deleteRicorrente(id: id)
                }
                itemToDelete = nil
            }
            Button("Annulla", role: .cancel) { itemToDelete = nil }
        }
    }
    
    private func submitRicorrente() {
        let val = Double(importoStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let desc = descrizione.trimmingCharacters(in: .whitespacesAndNewlines)
        guard val > 0, !desc.isEmpty else {
            store.showToast("Inserisci importo e descrizione validi", isError: true)
            return
        }
        store.addRicorrente(
            tipo: tipo,
            importo: val,
            frequenza: frequenza,
            dataInizio: DateHelpers.ymd(dataInizio),
            dataFine: usaDataFine ? DateHelpers.ymd(dataFine) : nil,
            categoria: categoria,
            descrizione: desc,
            promemoriaAttivo: promemoriaAttivo
        )
        importoStr = ""
        descrizione = ""
        usaDataFine = false
    }
}

// MARK: - 4. Tab Indefinite
struct IndefiniteTabView: View {
    @ObservedObject var store: SaldoStore
    
    @State private var tipo: TipoMovimento = .uscita
    @State private var importoStr: String = ""
    @State private var dataInizio: Date = Date()
    @State private var categoria: String = "casa"
    @State private var descrizione: String = ""
    @State private var promemoriaAttivo: Bool = true
    
    @State private var itemToDelete: String? = nil
    
    var availableCategories: [CategoriaItem] {
        CategorieCatalog.forKind(tipo)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            PanelBox(
                title: "Aggiungi spesa a periodo indefinito",
                subtitle: "Spese senza data di fine certa: vengono conteggiate ogni mese fino a quando non le chiudi."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        FormFieldBox(label: "TIPO") {
                            Picker("Tipo", selection: $tipo) {
                                ForEach(TipoMovimento.allCases) { t in
                                    Text(t.label).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: tipo) { _, newValue in
                                if let first = CategorieCatalog.forKind(newValue).first {
                                    categoria = first.id
                                }
                            }
                        }
                        
                        FormFieldBox(label: "IMPORTO MENSILE (€)") {
                            TextField("0,00", text: $importoStr)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.appBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                        
                        FormFieldBox(label: "DATA INIZIO") {
                            DatePicker("", selection: $dataInizio, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        FormFieldBox(label: "CATEGORIA") {
                            Picker("Categoria", selection: $categoria) {
                                ForEach(availableCategories) { c in
                                    Text("\(c.icon) \(c.name)").tag(c.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                    
                    FormFieldBox(label: "DESCRIZIONE") {
                        TextField("Descrizione della spesa mensile", text: $descrizione)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    }
                    
                    Toggle(isOn: $promemoriaAttivo) {
                        Label("Invia promemoria mensile prima dell'addebito", systemImage: "bell.badge")
                            .font(.footnote)
                            .foregroundColor(.appText)
                    }
                    
                    Button(action: submitIndefinita) {
                        Text("Aggiungi spesa indefinita")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appAccent)
                            .foregroundColor(.appBg)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            PanelBox(title: "Spese a periodo indefinito") {
                if store.state.indefinite.isEmpty {
                    Text("Nessuna spesa a periodo indefinito.")
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.state.indefinite) { i in
                            let cat = CategorieCatalog.get(i.categoria)
                            let remOn = i.promemoriaAttivo ?? true
                            HStack(spacing: 10) {
                                Text(cat.icon)
                                    .font(.title3)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(i.descrizione)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appText)
                                    HStack(spacing: 6) {
                                        Text("Dal \(DateHelpers.formatDisplay(i.dataInizio))")
                                            .font(.caption)
                                            .foregroundColor(.appMuted)
                                        if i.attiva {
                                            Text("In corso")
                                                .font(.system(size: 10, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.appYellow.opacity(0.2))
                                                .foregroundColor(.appYellow)
                                                .clipShape(Capsule())
                                        } else {
                                            Text("Chiusa il \(DateHelpers.formatDisplay(i.dataChiusura ?? ""))")
                                                .font(.system(size: 10, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.appMuted.opacity(0.2))
                                                .foregroundColor(.appMuted)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(i.tipo == .entrata ? "+" : "−") \(DateHelpers.formatCurrency(i.importo))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(i.tipo == .entrata ? .appGreen : .appRed)
                                
                                if i.attiva {
                                    Button(action: { store.toggleIndefinitaReminder(id: i.id) }) {
                                        Image(systemName: remOn ? "bell.fill" : "bell.slash")
                                            .font(.caption)
                                            .padding(7)
                                            .background(remOn ? Color.appAccent.opacity(0.2) : Color.appPanel2)
                                            .foregroundColor(remOn ? .appAccent : .appMuted)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button("Chiudi") {
                                        store.closeIndefinita(id: i.id)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.appPanel2)
                                    .foregroundColor(.appText)
                                    .cornerRadius(6)
                                    .buttonStyle(.plain)
                                } else {
                                    Button("Riapri") {
                                        store.reopenIndefinita(id: i.id)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.appGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .buttonStyle(.plain)
                                }
                                
                                Button(action: { itemToDelete = i.id }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .padding(7)
                                        .background(Color.appRed.opacity(0.2))
                                        .foregroundColor(.appRed)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(Color.appBorder)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Eliminare questa spesa indefinita?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let id = itemToDelete {
                    store.deleteIndefinita(id: id)
                }
                itemToDelete = nil
            }
            Button("Annulla", role: .cancel) { itemToDelete = nil }
        }
    }
    
    private func submitIndefinita() {
        let val = Double(importoStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let desc = descrizione.trimmingCharacters(in: .whitespacesAndNewlines)
        guard val > 0, !desc.isEmpty else {
            store.showToast("Inserisci importo e descrizione validi", isError: true)
            return
        }
        store.addIndefinita(
            tipo: tipo,
            importo: val,
            dataInizio: DateHelpers.ymd(dataInizio),
            categoria: categoria,
            descrizione: desc,
            promemoriaAttivo: promemoriaAttivo
        )
        importoStr = ""
        descrizione = ""
    }
}

// MARK: - 5. Tab Promemoria (Reminders)
struct PromemoriaTabView: View {
    @ObservedObject var store: SaldoStore
    @ObservedObject var notifManager = NotificationManager.shared
    
    private var reminderBinding: Binding<ReminderSettings> {
        Binding(
            get: { store.state.promemoria ?? ReminderSettings() },
            set: { newVal in
                store.state.promemoria = newVal
                store.saveState()
            }
        )
    }
    
    private var notificationTimeBinding: Binding<Date> {
        Binding(
            get: {
                let s = store.state.promemoria ?? ReminderSettings()
                var comps = DateComponents()
                comps.hour = s.oraNotifica
                comps.minute = s.minutoNotifica
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                var s = store.state.promemoria ?? ReminderSettings()
                s.oraNotifica = comps.hour ?? 9
                s.minutoNotifica = comps.minute ?? 0
                store.state.promemoria = s
                store.saveState()
            }
        )
    }
    
    var body: some View {
        let upcoming = store.calcUpcomingDeadlines(daysAhead: 60)
        
        VStack(spacing: 18) {
            PanelBox(
                title: "🔔 Impostazioni Promemoria Scadenze",
                subtitle: "Ricevi notifiche native su iOS e macOS per le tue spese ed entrate ricorrenti o a periodo indefinito."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Circle()
                            .fill(notifManager.authorizationStatus == .authorized ? Color.appGreen : Color.appYellow)
                            .frame(width: 10, height: 10)
                        Text(statusLabel)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.appText)
                        Spacer()
                        if notifManager.authorizationStatus != .authorized {
                            Button("Attiva Permessi Notifiche") {
                                Task {
                                    _ = await notifManager.requestAuthorization()
                                    store.scheduleNotifications()
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.appAccent)
                            .foregroundColor(.appBg)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                        
                        Button("Notifica di prova (3s)") {
                            Task {
                                await notifManager.sendTestNotification()
                                store.showToast("Notifica di prova programmata tra 3 secondi")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appPanel2)
                        .foregroundColor(.appText)
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    
                    Toggle("Abilita promemoria automatici per le scadenze", isOn: reminderBinding.abilitati)
                        .foregroundColor(.appText)
                    
                    if reminderBinding.wrappedValue.abilitati {
                        Divider().overlay(Color.appBorder)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                            FormFieldBox(label: "QUANDO AVVISARE IN ANTICIPO") {
                                Picker("Anticipo", selection: reminderBinding.giorniPrima) {
                                    Text("Solo il giorno stesso").tag(0)
                                    Text("1 giorno prima").tag(1)
                                    Text("2 giorni prima").tag(2)
                                    Text("3 giorni prima").tag(3)
                                    Text("7 giorni prima").tag(7)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            FormFieldBox(label: "ORARIO NOTIFICA") {
                                DatePicker("", selection: notificationTimeBinding, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        
                        if reminderBinding.wrappedValue.giorniPrima > 0 {
                            Toggle("Avvisa anche la mattina del giorno di scadenza", isOn: reminderBinding.ancheGiornoScadenza)
                                .font(.subheadline)
                                .foregroundColor(.appText)
                        }
                        
                        Text("Notifiche attualmente in coda nel sistema: \(notifManager.scheduledCount)")
                            .font(.caption)
                            .foregroundColor(.appMuted)
                    }
                }
            }
            
            PanelBox(
                title: "📅 Prossime scadenze (prossimi 60 giorni)",
                subtitle: "Elenco calcolato automaticamente dalle tue spese ricorrenti e indefinite con promemoria attivo."
            ) {
                if upcoming.isEmpty {
                    Text("Nessuna scadenza prevista nei prossimi 60 giorni.")
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(upcoming) { item in
                            let cat = CategorieCatalog.get(item.categoria)
                            let isToday = item.dataYMD == DateHelpers.todayYMD()
                            HStack(spacing: 12) {
                                Text(cat.icon)
                                    .font(.title3)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(item.titolo)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.appText)
                                        BadgeView(source: item.source)
                                    }
                                    HStack(spacing: 6) {
                                        Text(DateHelpers.formatDisplay(item.dataYMD))
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(isToday ? .appYellow : .appAccent)
                                        if isToday {
                                            Text("· OGGI")
                                                .font(.caption2.bold())
                                                .foregroundColor(.appYellow)
                                        }
                                        Text("· \(cat.name)")
                                            .font(.caption)
                                            .foregroundColor(.appMuted)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(item.tipo == .entrata ? "+" : "−") \(DateHelpers.formatCurrency(item.importo))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(item.tipo == .entrata ? .appGreen : .appRed)
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(Color.appBorder)
                        }
                    }
                }
            }
        }
        .task {
            await notifManager.refreshAuthorizationStatus()
        }
    }
    
    private var statusLabel: String {
        switch notifManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Permessi notifiche concessi e attivi"
        case .denied:
            return "Notifiche disabilitate nelle Impostazioni di Sistema"
        case .notDetermined:
            return "Permesso notifiche non ancora richiesto"
        @unknown default:
            return "Stato notifiche sconosciuto"
        }
    }
}

// MARK: - 6. Tab Impostazioni
struct ImpostazioniTabView: View {
    @ObservedObject var store: SaldoStore
    var onConnectFile: () -> Void
    var onOpenExistingFile: () -> Void
    var onExport: () -> Void
    var onImport: () -> Void
    
    @State private var saldoInizialeStr: String = ""
    @State private var risparmioStr: String = ""
    @State private var sogliaStr: String = ""
    @State private var showResetConfirm: Bool = false
    
    var body: some View {
        let diag = computeDiagnostica()
        
        VStack(spacing: 18) {
            // Saldo iniziale
            PanelBox(
                title: "Saldo iniziale",
                subtitle: "Il saldo iniziale rappresenta il punto di partenza prima dei movimenti registrati."
            ) {
                HStack(alignment: .bottom, spacing: 12) {
                    FormFieldBox(label: "SALDO INIZIALE (€)") {
                        TextField("0,00", text: $saldoInizialeStr)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    }
                    Button("Salva") {
                        let val = Double(saldoInizialeStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                        store.state.saldoIniziale = val
                        store.saveState()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.appAccent)
                    .foregroundColor(.appBg)
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                }
            }
            
            // Budget consigliato
            PanelBox(
                title: "💡 Budget consigliato",
                subtitle: "Imposta i tuoi obiettivi: il suggerimento \"puoi spendere\" si calcola sottraendo dal saldo le spese ricorrenti e indefinite ancora da pagare entro fine mese, l'obiettivo di risparmio e la soglia minima che vuoi mantenere."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                        FormFieldBox(label: "RISPARMIO MENSILE DESIDERATO (€)") {
                            TextField("0,00", text: $risparmioStr)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.appBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                        FormFieldBox(label: "SOGLIA MINIMA DI SICUREZZA (€)") {
                            TextField("0,00", text: $sogliaStr)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.appBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                    Button("Salva budget") {
                        let r = Double(risparmioStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let s = Double(sogliaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                        store.state.budget = BudgetSettings(risparmioMensile: max(0, r), sogliaMinima: max(0, s))
                        store.saveState()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.appAccent)
                    .foregroundColor(.appBg)
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                }
            }
            
            // Verifica saldo (Diagnostica)
            PanelBox(
                title: "🔍 Verifica saldo",
                subtitle: "Dettaglio dei calcoli per verificare che i conti tornino."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Saldo iniziale:")
                            .foregroundColor(.appText)
                        Text(DateHelpers.formatCurrency(store.state.saldoIniziale))
                            .bold()
                            .foregroundColor(.appText)
                    }
                    HStack {
                        Text("+ Totale entrate (manuali + ricorrenti + indefinite):")
                            .foregroundColor(.appText)
                        Text(DateHelpers.formatCurrency(diag.totEntrate))
                            .fontWeight(.semibold)
                            .foregroundColor(.appGreen)
                    }
                    HStack {
                        Text("− Totale uscite (manuali + ricorrenti + indefinite):")
                            .foregroundColor(.appText)
                        Text(DateHelpers.formatCurrency(diag.totUscite))
                            .fontWeight(.semibold)
                            .foregroundColor(.appRed)
                    }
                    Divider().overlay(Color.appBorder)
                    HStack {
                        Text("= Saldo attuale:")
                            .bold()
                            .foregroundColor(.appText)
                        Text(DateHelpers.formatCurrency(diag.saldo))
                            .bold()
                            .foregroundColor(diag.saldo >= 0 ? .appGreen : .appRed)
                    }
                    Text("Movimenti manuali: \(store.state.movimenti.count) · Occorrenze ricorrenti generate: \(diag.nRic) · Occorrenze indefinite generate: \(diag.nInd)")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                        .padding(.top, 4)
                }
                .font(.subheadline)
            }
            
            // Backup e Salva su File
            PanelBox(
                title: "📁 Salvataggio su File e Backup JSON",
                subtitle: "Il formato JSON è 100% compatibile con la versione web. Puoi scegliere la cartella in cui salvare il file per mantenerlo sempre aggiornato."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("📂 Cartella attiva:")
                            .font(.footnote)
                            .foregroundColor(.appMuted)
                        Text("\(store.activeFolderDisplay) › \(store.activeFileNameDisplay)")
                            .font(.footnote.bold())
                            .foregroundColor(.appGreen)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appBg)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button(action: onConnectFile) {
                                Label("Salva su File (Scegli cartella)…", systemImage: "folder.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appAccent)
                                    .foregroundColor(.appBg)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: onOpenExistingFile) {
                                Label("Apri da cartella…", systemImage: "folder")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appPanel2)
                                    .foregroundColor(.appText)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            #if os(macOS)
                            Button(action: { store.revealActiveFileInFinder() }) {
                                Label("Mostra nella cartella", systemImage: "magnifyingglass.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appPanel2)
                                    .foregroundColor(.appText)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            #endif
                            
                            Button(action: onExport) {
                                Label("Esporta JSON", systemImage: "square.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: onImport) {
                                Label("Importa JSON", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appPanel2)
                                    .foregroundColor(.appText)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { showResetConfirm = true }) {
                                Label("Cancella tutto", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appRed)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            saldoInizialeStr = String(format: "%.2f", store.state.saldoIniziale)
            risparmioStr = String(format: "%.2f", store.state.budget.risparmioMensile)
            sogliaStr = String(format: "%.2f", store.state.budget.sogliaMinima)
        }
        .confirmationDialog("Cancellare TUTTI i dati? Questa azione non può essere annullata.", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Cancella tutto", role: .destructive) {
                store.resetAllData()
                saldoInizialeStr = "0.00"
                risparmioStr = "0.00"
                sogliaStr = "0.00"
            }
            Button("Annulla", role: .cancel) {}
        }
    }
    
    private func computeDiagnostica() -> (totEntrate: Double, totUscite: Double, nRic: Int, nInd: Int, saldo: Double) {
        let all = store.getAllMovimenti()
        var totE = 0.0, totU = 0.0
        var nR = 0, nI = 0
        for m in all {
            if m.tipo == .entrata { totE += m.importo } else { totU += m.importo }
            if m.source == .ricorrente { nR += 1 }
            if m.source == .indefinita { nI += 1 }
        }
        let s = store.state.saldoIniziale + totE - totU
        return (totE, totU, nR, nI, s)
    }
}

// MARK: - Form & Navigation Subcomponents
struct FormFieldBox<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.appMuted)
                .tracking(0.4)
            content()
        }
    }
}

struct MonthNavigatorView: View {
    let label: String
    let onPrev: () -> Void
    let onNext: () -> Void
    let onAll: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrev) {
                Text("‹")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appPanel2)
                    .foregroundColor(.appText)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appText)
                .frame(minWidth: 90, alignment: .center)
            
            Button(action: onNext) {
                Text("›")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appPanel2)
                    .foregroundColor(.appText)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: onAll) {
                Text("Tutti")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appPanel2)
                    .foregroundColor(.appText)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
}
