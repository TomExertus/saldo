//
//  SaldoMovimentiApp.swift
//  SaldoMovimenti
//

import SwiftUI
import UserNotifications

@main
struct SaldoMovimentiApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 780, minHeight: 620)
                #endif
        }
    }
}

final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
