//
//  FocusGardenApp.swift
//  FocusGarden
//
//  Created by Vedat Dağlar on 15.03.2026.
//

import SwiftUI
import SwiftData
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        migrateSharedDefaults()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    private func migrateSharedDefaults() {
        guard let sharedDefaults = SharedStore.defaults else { return }
        let standardDefaults = UserDefaults.standard

        for key in SharedStore.mirroredKeys {
            if sharedDefaults.object(forKey: key) == nil, let value = standardDefaults.object(forKey: key) {
                sharedDefaults.set(value, forKey: key)
            }
        }
    }
}

@main
struct FocusGardenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FocusSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
