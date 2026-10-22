//
//  NotificationManager.swift
//  SaldoMovimenti
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var scheduledCount: Int = 0
    
    private init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }
    
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        self.scheduledCount = pending.filter { $0.identifier.hasPrefix("saldo_due_") }.count
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func sendTestNotification() async {
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        let content = UNMutableNotificationContent()
        content.title = "💰 Promemoria Saldo e Movimenti"
        content.body = "Le notifiche per le scadenze ricorrenti e indefinite sono attive!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let req = UNNotificationRequest(identifier: "saldo_test_\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
    
    /// Reschedules upcoming notifications for the next 60 days based on `upcomingList` and `settings`.
    func rescheduleNotifications(upcoming: [ProssimaScadenza], settings: ReminderSettings) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.map(\.identifier).filter { $0.hasPrefix("saldo_due_") }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)
        
        guard settings.abilitati else {
            await refreshAuthorizationStatus()
            return
        }
        
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            if !granted { return }
        } else if authorizationStatus == .denied {
            return
        }
        
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var count = 0
        
        for item in upcoming {
            if count >= 56 { break } // Keep safely within iOS 64 pending notification limit
            
            let sign = item.tipo == .entrata ? "+" : "−"
            let amountStr = DateHelpers.formatCurrency(item.importo)
            let cat = CategorieCatalog.get(item.categoria)
            
            // 1. Advance reminder (N days before)
            if settings.giorniPrima > 0,
               let advanceDate = cal.date(byAdding: .day, value: -settings.giorniPrima, to: item.dataScadenza) {
                var comps = cal.dateComponents([.year, .month, .day], from: advanceDate)
                comps.hour = settings.oraNotifica
                comps.minute = settings.minutoNotifica
                if let fireDate = cal.date(from: comps), fireDate > now {
                    let content = UNMutableNotificationContent()
                    let dayWord = settings.giorniPrima == 1 ? "Domani" : "Tra \(settings.giorniPrima) giorni"
                    content.title = "\(cat.icon) \(dayWord): \(item.titolo)"
                    content.body = "\(item.source.label) di \(sign) \(amountStr) prevista il \(DateHelpers.formatDisplay(item.dataYMD))."
                    content.sound = .default
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let req = UNNotificationRequest(
                        identifier: "saldo_due_adv_\(item.id)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(req)
                    count += 1
                }
            }
            
            // 2. Due-date reminder (same day)
            if settings.ancheGiornoScadenza || settings.giorniPrima == 0 {
                var comps = cal.dateComponents([.year, .month, .day], from: item.dataScadenza)
                comps.hour = settings.oraNotifica
                comps.minute = settings.minutoNotifica
                if let fireDate = cal.date(from: comps), fireDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = "\(cat.icon) Scadenza oggi: \(item.titolo)"
                    content.body = "\(item.source.label) di \(sign) \(amountStr) registrata oggi (\(DateHelpers.formatDisplay(item.dataYMD)))."
                    content.sound = .default
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let req = UNNotificationRequest(
                        identifier: "saldo_due_today_\(item.id)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(req)
                    count += 1
                }
            }
        }
        
        await refreshAuthorizationStatus()
    }
}
