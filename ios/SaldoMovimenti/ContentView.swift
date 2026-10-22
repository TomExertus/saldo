//
//  ContentView.swift
//  SaldoMovimenti
//

import SwiftUI
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable, Identifiable {
    case movimenti = "Movimenti"
    case statistiche = "Statistiche"
    case ricorrenti = "Ricorrenti"
    case indefinite = "Indefinite"
    case promemoria = "Promemoria"
    case impostazioni = "Impostazioni"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .movimenti: return "list.bullet.rectangle.portrait"
        case .statistiche: return "chart.bar.xaxis"
        case .ricorrenti: return "repeat"
        case .indefinite: return "infinity"
        case .promemoria: return "bell.badge"
        case .impostazioni: return "gearshape"
        }
    }
}

struct ContentView: View {
    @StateObject private var store = SaldoStore()
    @State private var selectedTab: AppTab = .movimenti
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBg.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💰 Saldo e Movimenti")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.appText)
                        Text("Tieni traccia di entrate, uscite, spese ricorrenti, indefinite e promemoria")
                            .font(.subheadline)
                            .foregroundColor(.appMuted)
                    }
                    
                    // Sync Bar
                    SyncBarView(
                        store: store,
                        onImportStatement: { store.chooseStatementFile() },
                        onConnectFile: { store.chooseSaveLocation() },
                        onOpenExistingFile: { store.openExistingSyncFile() },
                        onExport: { store.exportBackupFile() },
                        onImport: { store.importBackupFile() }
                    )
                    
                    // Balance + Budget Card
                    BalanceAndBudgetHeaderView(store: store)
                    
                    // Custom Tab Bar matching original HTML tabs + Reminders tab
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(AppTab.allCases) { tab in
                                let isSelected = selectedTab == tab
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedTab = tab
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab.icon)
                                            .font(.caption.weight(.semibold))
                                        Text(tab.rawValue)
                                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.appAccent : Color.appPanel)
                                    .foregroundColor(isSelected ? Color.appBg : Color.appMuted)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? Color.appAccent : Color.appBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Active Tab Content
                    Group {
                        switch selectedTab {
                        case .movimenti:
                            MovimentiTabView(
                                store: store,
                                onImportStatement: { store.chooseStatementFile() }
                            )
                        case .statistiche:
                            StatisticheTabView(store: store)
                        case .ricorrenti:
                            RicorrentiTabView(store: store)
                        case .indefinite:
                            IndefiniteTabView(store: store)
                        case .promemoria:
                            PromemoriaTabView(store: store)
                        case .impostazioni:
                            ImpostazioniTabView(
                                store: store,
                                onConnectFile: { store.chooseSaveLocation() },
                                onOpenExistingFile: { store.openExistingSyncFile() },
                                onExport: { store.exportBackupFile() },
                                onImport: { store.importBackupFile() }
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            
            // Toast overlay
            if let msg = store.toastMessage {
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(store.toastIsError ? Color.appRed : Color.appGreen)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        // Bank Statement Preview Sheet
        .sheet(isPresented: $store.showStatementPreviewSheet) {
            StatementImportPreviewSheet(store: store)
        }
    }
}

struct StatementImportPreviewSheet: View {
    @ObservedObject var store: SaldoStore
    
    var selectedCount: Int {
        store.pendingStatementRows.filter { $0.selected }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🏦 Anteprima Importazione Movimenti")
                        .font(.title3.bold())
                        .foregroundColor(.appText)
                    Text("Trovati \(store.pendingStatementRows.count) movimenti (\(selectedCount) selezionati). Puoi modificare tipo, categoria o impostarli come ricorrenti.")
                        .font(.footnote)
                        .foregroundColor(.appMuted)
                }
                Spacer()
                Button("Chiudi") {
                    store.showStatementPreviewSheet = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appPanel2)
                .foregroundColor(.appText)
                .cornerRadius(8)
            }
            
            HStack(spacing: 8) {
                Button("☑️ Seleziona tutti") {
                    for i in store.pendingStatementRows.indices {
                        store.pendingStatementRows[i].selected = true
                    }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appPanel2)
                .foregroundColor(.appText)
                .cornerRadius(6)
                .buttonStyle(.plain)
                
                Button("☐ Deseleziona tutti") {
                    for i in store.pendingStatementRows.indices {
                        store.pendingStatementRows[i].selected = false
                    }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appPanel2)
                .foregroundColor(.appText)
                .cornerRadius(6)
                .buttonStyle(.plain)
                
                Button("🚫 Escludi duplicati") {
                    for i in store.pendingStatementRows.indices where store.pendingStatementRows[i].isDuplicate {
                        store.pendingStatementRows[i].selected = false
                    }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appPanel2)
                .foregroundColor(.appText)
                .cornerRadius(6)
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($store.pendingStatementRows) { $row in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $row.selected)
                                .labelsHidden()
                            
                            Text(DateHelpers.formatDisplay(row.data))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.appMuted)
                                .frame(width: 82, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Descrizione", text: $row.descrizione)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.appText)
                                if row.isDuplicate {
                                    Text("⚠️ Possibile duplicato già presente")
                                        .font(.caption2)
                                        .foregroundColor(.appYellow)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker("", selection: $row.categoria) {
                                ForEach(CategorieCatalog.forKind(row.tipo)) { cat in
                                    Text("\(cat.icon) \(cat.name)").tag(cat.id)
                                }
                            }
                            .frame(width: 175)
                            
                            Picker("", selection: $row.importMode) {
                                ForEach(StatementImportMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .frame(width: 155)
                            
                            Button(action: {
                                row.tipo = (row.tipo == .entrata) ? .uscita : .entrata
                                row.categoria = SaldoStore.guessCategory(for: row.descrizione, tipo: row.tipo)
                            }) {
                                Text("\(row.tipo == .entrata ? "+" : "−") \(DateHelpers.formatCurrency(row.importo))")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundColor(row.tipo == .entrata ? .appGreen : .appRed)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.appPanel)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(row.isDuplicate ? Color.appYellow.opacity(0.5) : Color.appBorder, lineWidth: 1)
                        )
                        .opacity(row.selected ? 1.0 : 0.45)
                    }
                }
            }
            
            HStack {
                Text("💡 Clicca sull'importo per invertire tra Entrata (+) e Uscita (−).")
                    .font(.caption)
                    .foregroundColor(.appMuted)
                Spacer()
                Button("Annulla") {
                    store.showStatementPreviewSheet = false
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.appPanel2)
                .foregroundColor(.appText)
                .cornerRadius(8)
                .buttonStyle(.plain)
                
                Button("✅ Importa \(selectedCount) selezionati") {
                    store.confirmStatementImport()
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appGreen)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 500)
        .background(Color.appBg)
        .preferredColorScheme(.dark)
    }
}

