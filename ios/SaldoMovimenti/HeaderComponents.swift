//
//  HeaderComponents.swift
//  SaldoMovimenti
//

import SwiftUI

struct SyncBarView: View {
    @ObservedObject var store: SaldoStore
    var onImportStatement: () -> Void
    var onConnectFile: () -> Void
    var onOpenExistingFile: () -> Void
    var onExport: () -> Void
    var onImport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                switch store.syncMode {
                case .localOnly:
                    Text("📂")
                    (Text("\(store.activeFolderDisplay) › \(store.activeFileNameDisplay)").bold().foregroundColor(.appText) +
                     Text(" — Premi \"Salva su File\" per scegliere un'altra cartella").foregroundColor(.appMuted))
                        .font(.footnote)
                case .iCloudContainer:
                    Text("📂")
                    (Text("\(store.activeFolderDisplay) › \(store.activeFileNameDisplay)").bold().foregroundColor(.appGreen) +
                     Text(" — salvataggio automatico attivo nella cartella").foregroundColor(.appMuted))
                        .font(.footnote)
                case .linkedExternalFile:
                    Text("✅")
                    (Text("\(store.activeFolderDisplay) › \(store.activeFileNameDisplay)").bold().foregroundColor(.appGreen) +
                     Text(" — ogni modifica viene salvata automaticamente in questa cartella").foregroundColor(.appMuted))
                        .font(.footnote)
                }
                Spacer(minLength: 0)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: onImportStatement) {
                        Label("🏦 Importa Movimenti", systemImage: "doc.text.magnifyingglass")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appGreen)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onConnectFile) {
                        Label(store.syncMode.isSynced ? "Cambia cartella File…" : "Salva su File…", systemImage: "folder.badge.plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appAccent)
                            .foregroundColor(.appBg)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onOpenExistingFile) {
                        Label("Apri da cartella…", systemImage: "folder")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appPanel2)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    #if os(macOS)
                    Button(action: { store.revealActiveFileInFinder() }) {
                        Label("Mostra nella cartella", systemImage: "magnifyingglass.circle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appPanel2)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    #endif
                    
                    if store.syncMode.isSynced {
                        Button(action: { store.reloadFromSyncedFile() }) {
                            Label("Ricarica", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appPanel2)
                                .foregroundColor(.appText)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if case .linkedExternalFile = store.syncMode {
                        Button(action: { store.disconnectExternalSyncFile() }) {
                            Label("Scollega", systemImage: "xmark")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appPanel2)
                                .foregroundColor(.appText)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: onExport) {
                        Label("Esporta", systemImage: "square.and.arrow.down")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appGreen)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onImport) {
                        Label("Importa", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appPanel2)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

struct BalanceAndBudgetHeaderView: View {
    @ObservedObject var store: SaldoStore
    
    @State private var editingSaldoAttuale = false
    @State private var editingRisparmio = false
    @State private var editingSoglia = false
    @State private var tempSaldoAttuale = ""
    @State private var tempRisparmio = ""
    @State private var tempSoglia = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]
    
    var body: some View {
        let saldo = store.calcSaldo()
        let monthKey = store.currentMonth ?? String(DateHelpers.todayYMD().prefix(7))
        let stats = store.calcMonthStats(key: monthKey)
        let rec = store.calcRecurringMonthly()
        let b = store.calcBudgetSuggerito()
        
        VStack(alignment: .leading, spacing: 18) {
            // Saldo attuale (cliccabile / modificabile direttamente)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SALDO ATTUALE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .tracking(1)
                    Button(action: {
                        tempSaldoAttuale = String(format: "%.2f", saldo)
                        editingSaldoAttuale.toggle()
                    }) {
                        Label("Imposta saldo", systemImage: "pencil")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appPanel2)
                            .foregroundColor(.appText)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if editingSaldoAttuale {
                    HStack(spacing: 8) {
                        TextField("0,00", text: $tempSaldoAttuale)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.appText)
                            .padding(8)
                            .background(Color.appBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appAccent, lineWidth: 1))
                            .frame(maxWidth: 220)
                            .onSubmit {
                                commitSaldoAttuale(currentSaldo: saldo)
                            }
                        Button("Salva") {
                            commitSaldoAttuale(currentSaldo: saldo)
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.appAccent)
                        .foregroundColor(.appBg)
                        .cornerRadius(8)
                        .buttonStyle(.plain)
                        
                        Button("Annulla") {
                            editingSaldoAttuale = false
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.appPanel2)
                        .foregroundColor(.appText)
                        .cornerRadius(8)
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(DateHelpers.formatCurrency(saldo))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(saldo >= 0 ? .appGreen : .appRed)
                        .onTapGesture {
                            tempSaldoAttuale = String(format: "%.2f", saldo)
                            editingSaldoAttuale = true
                        }
                }
            }
            
            // Stats grid
            LazyVGrid(columns: columns, spacing: 10) {
                StatCell(label: "ENTRATE DEL MESE", value: DateHelpers.formatCurrency(stats.income), valueColor: .appGreen)
                StatCell(label: "USCITE DEL MESE", value: DateHelpers.formatCurrency(stats.expense), valueColor: .appRed)
                StatCell(label: "BILANCIO DEL MESE", value: DateHelpers.formatCurrency(stats.net), valueColor: stats.net >= 0 ? .appGreen : .appRed)
                StatCell(label: "RICORRENTI MENSILI (STIMA)", value: DateHelpers.formatCurrency(rec), valueColor: rec >= 0 ? .appGreen : .appRed)
            }
            
            // Budget consigliato card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("💡 PUOI SPENDERE FINO A FINE MESE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                    Spacer()
                    Text("\(b.daysLeft) \(b.daysLeft == 1 ? "GIORNO" : "GIORNI") A FINE MESE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                
                Text(DateHelpers.formatCurrency(b.spendibile))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(b.isDanger ? .appRed : (b.isWarning ? .appYellow : .appGreen))
                
                Text(budgetMessage(b))
                    .font(.footnote)
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    BudgetSubCell(label: "AL GIORNO", value: DateHelpers.formatCurrency(b.perDay))
                    BudgetSubCell(label: "ALLA SETTIMANA", value: DateHelpers.formatCurrency(b.perWeek))
                    BudgetSubCell(label: "SPESE FISSE RESIDUE", value: DateHelpers.formatCurrency(b.upcoming))
                    
                    // Inline editable Risparmio mensile
                    EditableBudgetSubCell(
                        label: "RISPARMIO MENSILE",
                        value: DateHelpers.formatCurrency(b.risparmio),
                        isEditing: $editingRisparmio,
                        textValue: $tempRisparmio,
                        onStartEdit: {
                            tempRisparmio = String(format: "%.2f", b.risparmio)
                            editingRisparmio = true
                        },
                        onCommit: {
                            let val = Double(tempRisparmio.replacingOccurrences(of: ",", with: ".")) ?? 0
                            store.state.budget.risparmioMensile = max(0, val)
                            store.saveState()
                            editingRisparmio = false
                        }
                    )
                    
                    // Inline editable Soglia minima
                    EditableBudgetSubCell(
                        label: "SOGLIA MINIMA",
                        value: DateHelpers.formatCurrency(b.soglia),
                        isEditing: $editingSoglia,
                        textValue: $tempSoglia,
                        onStartEdit: {
                            tempSoglia = String(format: "%.2f", b.soglia)
                            editingSoglia = true
                        },
                        onCommit: {
                            let val = Double(tempSoglia.replacingOccurrences(of: ",", with: ".")) ?? 0
                            store.state.budget.sogliaMinima = max(0, val)
                            store.saveState()
                            editingSoglia = false
                        }
                    )
                }
            }
            .padding(16)
            .background(budgetBackground(b))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(budgetBorderColor(b), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.appPanel, Color.appBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
    
    private func commitSaldoAttuale(currentSaldo: Double) {
        guard let target = Double(tempSaldoAttuale.replacingOccurrences(of: ",", with: ".")) else {
            store.showToast("Importo non valido", isError: true)
            return
        }
        let netMovimenti = currentSaldo - store.state.saldoIniziale
        store.state.saldoIniziale = target - netMovimenti
        store.saveState()
        editingSaldoAttuale = false
    }
    
    private func budgetMessage(_ b: BudgetCalculationResult) -> String {
        if b.spendibile >= 0 {
            if b.isWarning {
                return "⚠️ Margine ridotto. Ti consigliamo di non superare \(DateHelpers.formatCurrency(b.perDay)) al giorno."
            } else if b.spendibile == 0 {
                return "Sei in pareggio: niente spese extra fino a fine mese."
            } else {
                return "Puoi permetterti circa \(DateHelpers.formatCurrency(b.perDay)) al giorno (\(DateHelpers.formatCurrency(b.perWeek)) a settimana) per spese non fisse, mantenendo il tuo obiettivo di risparmio e la soglia di sicurezza."
            }
        } else {
            return "🚨 Sforamento previsto di \(DateHelpers.formatCurrency(abs(b.spendibile))) entro fine mese. Riduci le spese non essenziali, rivedi l'obiettivo di risparmio o la soglia minima."
        }
    }
    
    private func budgetBackground(_ b: BudgetCalculationResult) -> LinearGradient {
        if b.isDanger {
            return LinearGradient(colors: [Color.appRed.opacity(0.16), Color.appRed.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if b.isWarning {
            return LinearGradient(colors: [Color.appYellow.opacity(0.16), Color.appRed.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.appAccent.opacity(0.12), Color.appGreen.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func budgetBorderColor(_ b: BudgetCalculationResult) -> Color {
        if b.isDanger { return Color.appRed.opacity(0.45) }
        if b.isWarning { return Color.appYellow.opacity(0.45) }
        return Color.appAccent.opacity(0.35)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appMuted)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

struct BudgetSubCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.appMuted)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.appText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.22))
        .cornerRadius(8)
    }
}

struct EditableBudgetSubCell: View {
    let label: String
    let value: String
    @Binding var isEditing: Bool
    @Binding var textValue: String
    var onStartEdit: () -> Void
    var onCommit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.appMuted)
                Spacer()
                Text("✏️")
                    .font(.system(size: 10))
                    .opacity(0.7)
            }
            if isEditing {
                HStack(spacing: 4) {
                    TextField("0,00", text: $textValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                        .padding(4)
                        .background(Color.appBg)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appAccent, lineWidth: 1))
                        .onSubmit { onCommit() }
                    Button("OK") { onCommit() }
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.appAccent)
                        .foregroundColor(.appBg)
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                }
            } else {
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.appText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.22))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing { onStartEdit() }
        }
    }
}
