//
//  FocusGardenApp.swift
//  FocusGarden
//
//  Created by Vedat Dağlar on 15.03.2026.
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        migrateSharedDefaults()
        configureAudioSessionForBackground()

        // Set default appearance mode if not set
        if SharedStore.defaults?.string(forKey: "appearanceMode") == nil {
            SharedStore.defaults?.set("dark", forKey: "appearanceMode")
        }

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

    /// Configure the audio session for background playback so ambient sounds
    /// can keep playing when the app is in the background.
    /// IMPORTANT: Do NOT use .mixWithOthers — it can prevent iOS from keeping the app alive for audio.
    private func configureAudioSessionForBackground() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session background config failed: \(error)")
        }
    }

    /// Called when the app enters background — ensure audio session stays active.
    func applicationDidEnterBackground(_ application: UIApplication) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true, options: [])
        } catch {
            print("Failed to keep audio session active in background: \(error)")
        }
    }

    /// Called when the app returns to foreground — reactivate audio session.
    func applicationWillEnterForeground(_ application: UIApplication) {
        configureAudioSessionForBackground()
    }
}

@main
struct FocusGardenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let sharedModelContainer: ModelContainer?
    private let dataError: String?

    init() {
        let schema = Schema([
            FocusSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.dataError = nil
        } catch {
            // Fallback: in-memory container so the app doesn't crash
            print("⚠️ Could not create persistent ModelContainer: \(error)")
            self.sharedModelContainer = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
            self.dataError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                if let errorMessage = dataError {
                    DataErrorView(errorMessage: errorMessage)
                        .modelContainer(container)
                } else {
                    ContentView()
                        .modelContainer(container)
                }
            } else {
                DataErrorView(errorMessage: NSLocalizedString("error.fallback", comment: ""))
            }
        }
    }
}

/// Error screen shown when data fails to load
struct DataErrorView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text(NSLocalizedString("error.title", comment: ""))
                .font(.title2.bold())
            Text(NSLocalizedString("error.message", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}
