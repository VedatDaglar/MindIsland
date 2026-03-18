//
//  ContentView.swift
//  FocusGarden
//
//  Created by Vedat Dağlar on 15.03.2026.
//

import SwiftUI
import Combine
import AVFoundation
import UserNotifications
import ActivityKit
import WidgetKit
import SwiftData
import Charts

// MARK: - Language

private enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish  = "tr"
    case english  = "en"
    case chinese  = "zh-Hans"

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:  return nil
        case .turkish: return "tr"
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }

    var bundleLanguageCode: String? { localeIdentifier }

    var labelKey: String {
        switch self {
        case .system:  return "settings.language.system"
        case .turkish: return "settings.language.turkish"
        case .english: return "settings.language.english"
        case .chinese: return "settings.language.chinese"
        }
    }
}

private func activeLocalizationBundle() -> Bundle {
    let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
    let lang   = AppLanguage(rawValue: stored) ?? .system
    guard let code = lang.bundleLanguageCode,
          let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return .main }
    return bundle
}

private func localized(_ key: String) -> String {
    activeLocalizationBundle().localizedString(forKey: key, value: nil, table: nil)
}

private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    let fmt = activeLocalizationBundle().localizedString(forKey: key, value: nil, table: nil)
    return String(format: fmt, locale: Locale.current, arguments: arguments)
}

// MARK: - Theme

private enum AppTheme {
    static let accent            = Color(red: 0.48, green: 0.83, blue: 0.72)
    static let accentBright      = Color(red: 0.82, green: 0.97, blue: 0.90)
    static let accentBreak       = Color(red: 0.95, green: 0.75, blue: 0.45)
    static let accentBreakBright = Color(red: 1.00, green: 0.90, blue: 0.65)
    static let backgroundTop     = Color(red: 0.05, green: 0.08, blue: 0.11)
    static let backgroundBottom  = Color(red: 0.07, green: 0.16, blue: 0.14)
    static let card              = Color(red: 0.11, green: 0.16, blue: 0.15)
    static let cardSoft          = Color(red: 0.15, green: 0.22, blue: 0.20)
    static let textPrimary       = Color.white
    static let textSecondary     = Color.white.opacity(0.72)
    static let border            = Color.white.opacity(0.06)
}

// MARK: - Shared Store

enum SharedStore {
    static let suiteName = "group.vedatdaglar.FocusGarden"
    static let defaults  = UserDefaults(suiteName: suiteName)

    static let mirroredKeys = [
        "appLanguage",
        "totalFocusMinutes",
        "completedSessions",
        "focusStreak",
        "lastSessionDate",
        "ambientSoundsEnabled",
        "notificationsEnabled"
    ]
}

// MARK: - Sound Player

private final class FocusSoundPlayer {
    static let shared = FocusSoundPlayer()

    enum Cue { case start, complete, breakStart, breakEnd }

    private let engine  = AVAudioEngine()
    private let player  = AVAudioPlayerNode()
    private let format  = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var configured = false

    func play(_ cue: Cue) {
        guard let format else { return }
        configureIfNeeded(format: format)
        guard let buffer = makeBuffer(for: cue, format: format) else { return }
        if player.isPlaying { player.stop() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func configureIfNeeded(format: AVAudioFormat) {
        guard !configured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.55
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            configured = true
        } catch {
            assertionFailure("Audio engine config failed: \(error)")
        }
    }

    private func makeBuffer(for cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let notes: [(frequency: Double, duration: Double, amplitude: Double)] = {
            switch cue {
            case .start:      return [(523.25, 0.09, 0.10), (659.25, 0.10, 0.08)]
            case .complete:   return [(523.25, 0.08, 0.08), (659.25, 0.09, 0.08), (783.99, 0.12, 0.07)]
            case .breakStart: return [(440.00, 0.10, 0.08), (523.25, 0.12, 0.07)]
            case .breakEnd:   return [(659.25, 0.09, 0.08), (523.25, 0.10, 0.08), (440.00, 0.12, 0.07)]
            }
        }()
        let gap = 0.025
        let sr  = format.sampleRate
        let totalFrames = Int((notes.reduce(0) { $0 + $1.duration } + gap * Double(notes.count - 1)) * sr)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let ch = buffer.floatChannelData?[0] else { return nil }
        var cursor = 0
        for note in notes {
            let nf = Int(note.duration * sr)
            let af = max(Int(0.018 * sr), 1)
            let rf = max(Int(0.030 * sr), 1)
            for f in 0..<nf {
                let raw = sin(2 * .pi * note.frequency * Double(f) / sr)
                let env = min(Double(f) / Double(af), 1) * min(Double(nf - f) / Double(rf), 1)
                ch[cursor + f] = Float(raw * note.amplitude * env)
            }
            cursor += nf + Int(gap * sr)
        }
        return buffer
    }
}

// MARK: - Notification Manager

private final class FocusNotificationManager {
    static let shared = FocusNotificationManager()
    private let center     = UNUserNotificationCenter.current()
    private let completeID = "mindisland.focus.complete"
    private let breakID    = "mindisland.break.end"

    func requestAuthorizationIfNeeded() async -> Bool {
        let s = await center.notificationSettings()
        switch s.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined:
            do { return try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
            catch { return false }
        default: return false
        }
    }

    func scheduleSessionCompletion(after seconds: Int) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let c = UNMutableNotificationContent()
            c.title = localized("notification.complete.title")
            c.body  = localizedFormat("notification.complete.body", max(seconds / 60, 1))
            c.sound = .default; c.interruptionLevel = .active; c.relevanceScore = 0.8
            schedule(identifier: completeID, content: c, after: seconds)
        }
    }

    func scheduleBreakEnd(after seconds: Int) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let c = UNMutableNotificationContent()
            c.title = localized("notification.break.title")
            c.body  = localized("notification.break.body")
            c.sound = .default; c.interruptionLevel = .timeSensitive
            schedule(identifier: breakID, content: c, after: seconds)
        }
    }

    private func schedule(identifier: String, content: UNMutableNotificationContent, after seconds: Int) {
        let fireDate    = Calendar.current.date(byAdding: .second, value: max(seconds, 1), to: Date())!
        let triggerDate = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fireDate)
        let trigger     = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request     = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task { try? await center.add(request) }
    }

    func cancelSessionCompletion() { center.removePendingNotificationRequests(withIdentifiers: [completeID]) }
    func cancelBreakEnd()          { center.removePendingNotificationRequests(withIdentifiers: [breakID]) }
}

// MARK: - Root View

struct ContentView: View {
    @AppStorage("appLanguage", store: SharedStore.defaults) private var appLanguage = AppLanguage.system.rawValue

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(localized("tab.focus"), systemImage: "leaf.fill") }
            StatsView()
                .tabItem { Label(localized("tab.stats"), systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label(localized("tab.settings"), systemImage: "gearshape.fill") }
        }
        .tint(AppTheme.accent)
        .environment(\.locale, Locale(identifier: (AppLanguage(rawValue: appLanguage) ?? .system).localeIdentifier ?? Locale.current.identifier))
        .id(appLanguage)
    }
}

// MARK: - Home View

private struct HomeView: View {
    private let presetOptions = [15, 25, 45, 60]

    @Environment(\.modelContext) private var modelContext

    @AppStorage("totalFocusMinutes",    store: SharedStore.defaults) private var totalFocusMinutes    = 0
    @AppStorage("completedSessions",    store: SharedStore.defaults) private var completedSessions    = 0
    @AppStorage("focusStreak",          store: SharedStore.defaults) private var focusStreak          = 0
    @AppStorage("lastSessionDate",      store: SharedStore.defaults) private var lastSessionDate       = ""
    @AppStorage("ambientSoundsEnabled", store: SharedStore.defaults) private var ambientSoundsEnabled  = true
    @AppStorage("notificationsEnabled", store: SharedStore.defaults) private var notificationsEnabled  = false

    // Focus timer
    @State private var focusDuration: Int    = 25 * 60
    @State private var timeRemaining: Int    = 25 * 60
    @State private var timerIsRunning         = false
    @State private var sessionCompleted       = false
    @State private var showCelebration        = false
    @State private var sessionEndDate: Date?

    // Break timer
    @State private var breakDuration: Int      = 5 * 60
    @State private var breakTimeRemaining: Int = 5 * 60
    @State private var breakIsRunning          = false
    @State private var breakEndDate: Date?

    // Custom duration
    @State private var showCustomSheet = false
    @State private var customMinutes: Double = 30

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        focusOrb
                        if breakIsRunning {
                            breakTimerCard
                        } else {
                            sessionButton
                            durationPicker
                        }
                        statsGrid
                        quickTipsCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
                }

                if showCelebration { celebrationOverlay }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(AppTheme.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .onReceive(timer) { _ in handleTick() }
            .task {
                if notificationsEnabled {
                    let ok = await FocusNotificationManager.shared.requestAuthorizationIfNeeded()
                    if !ok { notificationsEnabled = false }
                }
            }
            .sheet(isPresented: $showCustomSheet) { customDurationSheet }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, Color(red: 0.08, green: 0.20, blue: 0.22), AppTheme.backgroundBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            Circle()
                .fill((breakIsRunning ? AppTheme.accentBreak : AppTheme.accent).opacity(0.16))
                .frame(width: 280, height: 280).blur(radius: 40).offset(x: 120, y: -260)
                .animation(.easeInOut(duration: 0.6), value: breakIsRunning)

            Circle()
                .fill(Color(red: 0.32, green: 0.60, blue: 0.52).opacity(0.18))
                .frame(width: 240, height: 240).blur(radius: 45).offset(x: -120, y: 260)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("app.name"))
                        .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                    Text(localized("home.hero.subtitle"))
                        .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(localized("home.hero.badge"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.accentBright)
                    Text(localizedFormat("format.minutes", totalFocusMinutes))
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(AppTheme.card.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
            }
            Text(statusText)
                .font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.84))
        }
    }

    // MARK: Focus Orb

    private var focusOrb: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill((breakIsRunning ? AppTheme.accentBreak : AppTheme.accent).opacity(0.12))
                    .frame(width: 270, height: 270).blur(radius: 14)
                    .animation(.easeInOut(duration: 0.6), value: breakIsRunning)

                Circle().stroke(Color.white.opacity(0.08), lineWidth: 18).frame(width: 236, height: 236)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: breakIsRunning
                                ? [AppTheme.accentBreakBright, AppTheme.accentBreak]
                                : [AppTheme.accentBright, AppTheme.accent],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 236, height: 236)
                    .shadow(color: (breakIsRunning ? AppTheme.accentBreak : AppTheme.accent).opacity(0.25), radius: 14, y: 8)
                    .animation(.easeInOut(duration: 0.35), value: progressValue)

                Circle()
                    .fill(LinearGradient(colors: [AppTheme.cardSoft, AppTheme.card], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 188, height: 188)
                    .overlay { Circle().stroke(AppTheme.border, lineWidth: 1) }

                NeonEggEvolutionView(
                    completedSessions: completedSessions,
                    timerIsRunning: timerIsRunning || breakIsRunning,
                    sessionCompleted: sessionCompleted,
                    isBreak: breakIsRunning,
                    size: 120
                ).offset(y: -8)

                VStack(spacing: 10) {
                    Text(orbTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                    Text(timeString)
                        .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                .offset(y: 60)
            }

            HStack(spacing: 12) {
                capsuleInfo(title: localized("home.hero.focus"), value: localizedFormat("format.minutes", selectedMinutes))
                capsuleInfo(title: localized("home.hero.streak"), value: localizedFormat("format.days", focusStreak))
            }
        }
        .padding(22)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    // MARK: Session Button

    private var sessionButton: some View {
        VStack(spacing: 14) {
            Button {
                if timerIsRunning { stopSession() } else { startSession() }
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            Text(timerIsRunning ? localized("home.footer.running") : localized("home.footer.ready"))
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
        .shadow(color: .black.opacity(0.20), radius: 18, y: 10)
    }

    // MARK: Break Timer Card

    private var breakTimerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.accentBreakBright)
                Text(localized("home.break.title"))
                    .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text(localized("home.break.badge"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.accentBreakBright)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.accentBreak.opacity(0.18)).clipShape(Capsule())
            }

            Button { skipBreak() } label: {
                Text(localized("home.break.skip"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)

            Text(localized("home.break.footer"))
                .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.accentBreak.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.accentBreak.opacity(0.22), lineWidth: 1) }
        .shadow(color: AppTheme.accentBreak.opacity(0.12), radius: 18, y: 10)
    }

    // MARK: Duration Picker

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("home.duration.title"))
                .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(presetOptions, id: \.self) { minutes in
                    Button { selectDuration(minutes) } label: {
                        VStack(spacing: 5) {
                            Text("\(minutes)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(localized("common.minutesShort"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedMinutes == minutes ? AppTheme.accent.opacity(0.24) : Color.white.opacity(0.06)))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selectedMinutes == minutes ? AppTheme.accent.opacity(0.42) : Color.white.opacity(0.08), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(timerIsRunning)
                    .opacity(timerIsRunning && selectedMinutes != minutes ? 0.45 : 1)
                }

                Button { if !timerIsRunning { showCustomSheet = true } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold))
                        Text(localized("home.duration.custom")).font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isCustomSelected ? AppTheme.accent.opacity(0.24) : Color.white.opacity(0.06)))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isCustomSelected ? AppTheme.accent.opacity(0.42) : Color.white.opacity(0.08), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(timerIsRunning)
                .opacity(timerIsRunning && !isCustomSelected ? 0.45 : 1)
            }
        }
        .padding(18)
        .background(AppTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    // MARK: Custom Duration Sheet

    private var customDurationSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(spacing: 32) {
                    VStack(spacing: 10) {
                        Text("\(Int(customMinutes))")
                            .font(.system(size: 72, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(localized("home.duration.minutes"))
                            .font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        Slider(value: $customMinutes, in: 5...120, step: 5).tint(AppTheme.accent).padding(.horizontal, 24)
                        HStack {
                            Text("5 \(localized("common.minutesShort"))")
                            Spacer()
                            Text("120 \(localized("common.minutesShort"))")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 28)
                    }

                    Button {
                        selectDuration(Int(customMinutes))
                        showCustomSheet = false
                    } label: {
                        Text(localizedFormat("home.startSession", Int(customMinutes)))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle(localized("home.duration.customTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("common.cancel")) { showCustomSheet = false }.foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 14) {
            statCard(title: localized("home.today"),    value: localizedFormat("format.minutes", todayPreviewMinutes), icon: "clock.fill")
            statCard(title: localized("home.sessions"), value: "\(completedSessions)",                                  icon: "checkmark.circle.fill")
            statCard(title: localized("home.streak"),   value: localizedFormat("format.days", focusStreak),             icon: "flame.fill")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.accentBright)
            Text(title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    // MARK: Celebration

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(AppTheme.cardSoft).frame(width: 104, height: 104)
                        .overlay { Circle().stroke(AppTheme.border, lineWidth: 1) }
                    NeonEggEvolutionView(completedSessions: completedSessions, timerIsRunning: false, sessionCompleted: true, isBreak: false, size: 78)
                }

                Text(localized("celebration.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(localizedFormat("celebration.message", selectedMinutes))
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center).foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    celebrationPill(title: localized("celebration.total"), value: localizedFormat("format.minutes", totalFocusMinutes))
                    celebrationPill(title: localized("home.sessions"),     value: "\(completedSessions)")
                }

                Button {
                    showCelebration = false
                    startBreak()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill").font(.system(size: 15, weight: .semibold))
                        Text(localizedFormat("home.break.start", breakDuration / 60))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.03))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [AppTheme.accentBreakBright, AppTheme.accentBreak], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showCelebration = false
                } label: {
                    Text(localized("common.continue"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24).frame(maxWidth: 330)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 16)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func celebrationPill(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).background(AppTheme.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Quick Tips

    private var quickTipsCard: some View {
        HStack(spacing: 14) {
            Image(systemName: notificationsEnabled ? "bell.badge.fill" : "sparkles")
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(AppTheme.accentBright)
                .frame(width: 42, height: 42).background(AppTheme.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("home.tip.title")).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(notificationsEnabled ? localized("home.tip.notificationsOn") : localized("home.tip.notificationsOff"))
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16).background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func capsuleInfo(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Computed Properties

    private var timeString: String {
        let src = breakIsRunning ? breakTimeRemaining : timeRemaining
        return String(format: "%02d:%02d", src / 60, src % 60)
    }

    private var progressValue: Double {
        if breakIsRunning {
            guard breakDuration > 0 else { return 0 }
            return min(max(Double(breakDuration - breakTimeRemaining) / Double(breakDuration), 0), 1)
        }
        guard focusDuration > 0 else { return 0 }
        return min(max(Double(focusDuration - timeRemaining) / Double(focusDuration), 0), 1)
    }

    private var statusText: String {
        if breakIsRunning   { return localized("home.status.break") }
        if timerIsRunning   { return localized("home.status.running") }
        if sessionCompleted { return localized("home.status.completed") }
        return localizedFormat("home.status.ready", selectedMinutes)
    }

    private var orbTitle: String {
        if breakIsRunning   { return localized("home.break.title") }
        if timerIsRunning   { return localized("home.timer.remaining") }
        if sessionCompleted { return localized("home.timer.completed") }
        return localized("home.timer.ready")
    }

    private var selectedMinutes: Int { focusDuration / 60 }
    private var isCustomSelected: Bool { !presetOptions.contains(selectedMinutes) }

    private var buttonTitle: String {
        timerIsRunning ? localized("home.stopSession") : localizedFormat("home.startSession", selectedMinutes)
    }

    private var todayPreviewMinutes: Int {
        if timerIsRunning { return max(totalFocusMinutes + ((focusDuration - timeRemaining) / 60), 0) }
        return totalFocusMinutes
    }

    private func suggestedBreakDuration(forFocusMinutes mins: Int) -> Int {
        switch mins {
        case ..<20: return 3 * 60
        case ..<40: return 5 * 60
        case ..<70: return 10 * 60
        default:    return 15 * 60
        }
    }

    // MARK: Actions

    private func startSession() {
        sessionCompleted    = false
        timeRemaining       = focusDuration
        timerIsRunning      = true
        sessionEndDate      = Date().addingTimeInterval(TimeInterval(focusDuration))
        showCelebration     = false
        breakDuration       = suggestedBreakDuration(forFocusMinutes: focusDuration / 60)
        breakTimeRemaining  = breakDuration

        startLiveActivity()
        if ambientSoundsEnabled { FocusSoundPlayer.shared.play(.start) }
        if notificationsEnabled { FocusNotificationManager.shared.scheduleSessionCompletion(after: focusDuration) }
    }

    private func stopSession() {
        timerIsRunning = false
        timeRemaining  = focusDuration
        sessionEndDate = nil
        endLiveActivity()
        FocusNotificationManager.shared.cancelSessionCompletion()
    }

    private func completeSession() {
        timerIsRunning   = false
        sessionCompleted = true
        timeRemaining    = 0
        sessionEndDate   = nil
        endLiveActivity(finalState: .init(startDate: Date(), endDate: Date(), isRunning: false, sessionTitle: localized("home.timer.completed")))
        FocusNotificationManager.shared.cancelSessionCompletion()

        totalFocusMinutes += focusDuration / 60
        completedSessions += 1

        let calendar   = Calendar.current
        let today      = calendar.startOfDay(for: Date())
        let todayStr   = ISO8601DateFormatter().string(from: today)
        if lastSessionDate != todayStr {
            let yesterday    = calendar.date(byAdding: .day, value: -1, to: today)!
            let yesterdayStr = ISO8601DateFormatter().string(from: yesterday)
            focusStreak      = (lastSessionDate == yesterdayStr) ? focusStreak + 1 : 1
            lastSessionDate  = todayStr
        }

        let session = FocusSession(date: Date(), durationMinutes: focusDuration / 60, completed: true)
        modelContext.insert(session)

        WidgetCenter.shared.reloadAllTimelines()
        if ambientSoundsEnabled { FocusSoundPlayer.shared.play(.complete) }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { showCelebration = true }
    }

    private func startBreak() {
        breakIsRunning     = true
        breakTimeRemaining = breakDuration
        breakEndDate       = Date().addingTimeInterval(TimeInterval(breakDuration))
        if ambientSoundsEnabled { FocusSoundPlayer.shared.play(.breakStart) }
        if notificationsEnabled { FocusNotificationManager.shared.scheduleBreakEnd(after: breakDuration) }
    }

    private func completeBreak() {
        breakIsRunning = false
        breakEndDate   = nil
        if ambientSoundsEnabled { FocusSoundPlayer.shared.play(.breakEnd) }
        FocusNotificationManager.shared.cancelBreakEnd()
    }

    private func skipBreak() {
        breakIsRunning     = false
        breakEndDate       = nil
        breakTimeRemaining = breakDuration
        FocusNotificationManager.shared.cancelBreakEnd()
    }

    private func selectDuration(_ minutes: Int) {
        guard !timerIsRunning else { return }
        focusDuration      = minutes * 60
        timeRemaining      = focusDuration
        sessionCompleted   = false
        showCelebration    = false
        sessionEndDate     = nil
        breakDuration      = suggestedBreakDuration(forFocusMinutes: minutes)
        breakTimeRemaining = breakDuration
    }

    private func handleTick() {
        if timerIsRunning {
            guard let end = sessionEndDate else { timerIsRunning = false; return }
            let remaining = max(Int(ceil(end.timeIntervalSinceNow)), 0)
            if remaining == 0 { completeSession() } else { timeRemaining = remaining }
        }
        if breakIsRunning {
            guard let end = breakEndDate else { breakIsRunning = false; return }
            let remaining = max(Int(ceil(end.timeIntervalSinceNow)), 0)
            if remaining == 0 { completeBreak() } else { breakTimeRemaining = remaining }
        }
    }

    // MARK: Live Activity

    private func startLiveActivity() {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = FocusSessionActivityAttributes(sessionName: localized("app.name"))
        let now   = Date()
        let end   = sessionEndDate ?? now.addingTimeInterval(TimeInterval(focusDuration))
        let state = FocusSessionActivityAttributes.ContentState(
            startDate: now,
            endDate: end,
            isRunning: true,
            sessionTitle: localized("home.timer.remaining")
        )
        do {
            _ = try Activity<FocusSessionActivityAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: end.addingTimeInterval(60)),
                pushType: nil
            )
        } catch { print("Live activity start failed: \(error)") }
    }

    // Only called on state transitions — Text(timerInterval:) updates itself on lock screen.
    private func updateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let now = Date()
        let end = sessionEndDate ?? now.addingTimeInterval(TimeInterval(timeRemaining))
        let s = FocusSessionActivityAttributes.ContentState(
            startDate: now,
            endDate: end,
            isRunning: timerIsRunning,
            sessionTitle: timerIsRunning ? localized("home.timer.remaining") : localized("home.timer.completed")
        )
        Task { for a in Activity<FocusSessionActivityAttributes>.activities {
            await a.update(.init(state: s, staleDate: end.addingTimeInterval(60)))
        }}
    }

    private func endLiveActivity(finalState: FocusSessionActivityAttributes.ContentState? = nil) {
        guard #available(iOS 16.2, *) else { return }
        let s = finalState ?? FocusSessionActivityAttributes.ContentState(
            startDate: Date(), endDate: Date(), isRunning: false,
            sessionTitle: localized("home.timer.completed")
        )
        Task { for a in Activity<FocusSessionActivityAttributes>.activities {
            await a.end(.init(state: s, staleDate: Date()), dismissalPolicy: .default)
        }}
    }
}

// MARK: - Neon Egg Evolution View

private struct NeonEggEvolutionView: View {
    let completedSessions: Int
    let timerIsRunning: Bool
    let sessionCompleted: Bool
    let isBreak: Bool
    let size: CGFloat

    @State private var ring1Pulse   = false
    @State private var ring2Pulse   = false
    @State private var ring3Pulse   = false
    @State private var outerOrbit   = 0.0
    @State private var innerOrbit   = 0.0
    @State private var iconFloat    = false
    @State private var glowPulse    = false

    // -1 = break, 0–4 = focus stages
    private var stage: Int {
        if isBreak { return -1 }
        switch completedSessions {
        case 20...: return 4
        case 10...: return 3
        case 4...:  return 2
        case 1...:  return 1
        default:    return 0
        }
    }

    private var stageColor: Color {
        switch stage {
        case -1: return AppTheme.accentBreak                          // amber – break
        case  4: return Color(red: 1.00, green: 0.94, blue: 0.55)    // golden – island peak
        case  3: return Color(red: 0.72, green: 0.98, blue: 0.68)    // bright lime – thriving
        case  2: return Color(red: 0.52, green: 0.90, blue: 0.80)    // teal – growing
        case  1: return AppTheme.accent                               // mint – started
        default: return Color(red: 0.42, green: 0.62, blue: 0.68)    // muted – dormant
        }
    }

    private var stageIcon: String {
        switch stage {
        case -1: return "cup.and.saucer.fill"
        case  4: return "sun.max.fill"
        case  3: return "tree.fill"
        case  2: return "leaf.fill"
        case  1: return "leaf"
        default: return "sparkle"
        }
    }

    private var orbitCount: Int {
        switch stage {
        case -1: return 4
        case  4: return 7
        case  3: return 6
        case  2: return 5
        case  1: return 3
        default: return 2
        }
    }

    var body: some View {
        ZStack {

            // ── Outer bloom glow ──────────────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [stageColor.opacity(glowPulse ? 0.30 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.1, height: size * 1.1)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: glowPulse)

            // ── Ring 3 – outer halo, very slow ───────────────────────
            Circle()
                .stroke(stageColor.opacity(ring3Pulse ? 0.20 : 0.06), lineWidth: 1)
                .frame(width: size * 0.96, height: size * 0.96)
                .scaleEffect(ring3Pulse ? 1.05 : 0.97)
                .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: ring3Pulse)

            // ── Ring 2 – mid ring ─────────────────────────────────────
            Circle()
                .stroke(stageColor.opacity(ring2Pulse ? 0.32 : 0.10), lineWidth: 1.4)
                .frame(width: size * 0.76, height: size * 0.76)
                .scaleEffect(ring2Pulse ? 1.06 : 0.95)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: ring2Pulse)

            // ── Ring 1 – inner ring, fastest ─────────────────────────
            Circle()
                .stroke(stageColor.opacity(ring1Pulse ? 0.50 : 0.18), lineWidth: 1.8)
                .frame(width: size * 0.58, height: size * 0.58)
                .scaleEffect(ring1Pulse ? 1.07 : 0.94)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: ring1Pulse)

            // ── Outer orbit dots (clockwise) ──────────────────────────
            ForEach(0..<orbitCount, id: \.self) { i in
                let bright = (i % 2 == 0)
                Circle()
                    .fill(bright ? Color.white.opacity(0.90) : stageColor.opacity(0.78))
                    .frame(
                        width:  size * (bright ? 0.065 : 0.048),
                        height: size * (bright ? 0.065 : 0.048)
                    )
                    .offset(y: -size * 0.37)
                    .rotationEffect(.degrees(outerOrbit + Double(i) * (360.0 / Double(orbitCount))))
                    .shadow(color: stageColor.opacity(0.55), radius: bright ? 10 : 5)
                    .animation(.linear(duration: 13).repeatForever(autoreverses: false), value: outerOrbit)
            }

            // ── Inner counter-rotating dots (stage 2+) ───────────────
            if stage >= 2 || stage == -1 {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(stageColor.opacity(0.52))
                        .frame(width: size * 0.038, height: size * 0.038)
                        .offset(y: -size * 0.22)
                        .rotationEffect(.degrees(innerOrbit + Double(i) * 120))
                        .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: innerOrbit)
                }
            }

            // ── Center core glow ─────────────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [stageColor.opacity(0.28), stageColor.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.26
                    )
                )
                .frame(width: size * 0.52, height: size * 0.52)
                .scaleEffect(ring1Pulse ? 1.10 : 0.92)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: ring1Pulse)

            // ── Main evolving icon ────────────────────────────────────
            Image(systemName: stageIcon)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, stageColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: stageColor.opacity(0.55), radius: 20)
                .offset(y: iconFloat ? -size * 0.08 : -size * 0.03)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: iconFloat)

            // ── Sparkles on session completion ───────────────────────
            if sessionCompleted {
                ForEach(0..<3, id: \.self) { i in
                    let offsets: [(CGFloat, CGFloat)] = [
                        ( size * 0.26, -size * 0.20),
                        (-size * 0.22, -size * 0.16),
                        ( size * 0.06,  size * 0.25)
                    ]
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.13, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright.opacity(0.90))
                        .offset(x: offsets[i].0, y: offsets[i].1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            ring1Pulse = true
            ring2Pulse = true
            ring3Pulse = true
            outerOrbit = 360
            innerOrbit = -360
            iconFloat  = true
            glowPulse  = true
        }
    }
}

// MARK: - Stats View

private struct StatsView: View {
    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]

    @AppStorage("totalFocusMinutes", store: SharedStore.defaults) private var totalFocusMinutes = 0
    @AppStorage("completedSessions", store: SharedStore.defaults) private var completedSessions = 0
    @AppStorage("focusStreak",       store: SharedStore.defaults) private var focusStreak       = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.09, blue: 0.11), Color(red: 0.10, green: 0.15, blue: 0.14), Color(red: 0.14, green: 0.22, blue: 0.19)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        statsHeader
                        weeklyChartCard
                        summaryCards
                        insightsCard
                    }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(localized("stats.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
    }

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("stats.title")).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(localized("stats.hero.subtitle")).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 12) {
                heroMetric(title: localized("home.today"),    value: localizedFormat("format.minutes", totalFocusMinutes))
                heroMetric(title: localized("home.sessions"), value: "\(completedSessions)")
                heroMetric(title: localized("home.streak"),   value: localizedFormat("format.days", focusStreak))
            }
        }
        .padding(22).background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("stats.weeklyChart.title"))
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)

            if last7DaysData.allSatisfy({ $0.minutes == 0 }) {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 32, weight: .light)).foregroundStyle(AppTheme.textSecondary)
                        Text(localized("stats.noData")).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                Chart(last7DaysData) { day in
                    BarMark(x: .value("Day", day.label), y: .value("Minutes", day.minutes))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(AppTheme.textSecondary) }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel().foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(18).background(AppTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private var summaryCards: some View {
        VStack(spacing: 14) {
            statsRow(title: localized("stats.totalFocus"),        value: localizedFormat("format.minutes", totalFocusMinutes), detail: localized("stats.totalFocus.detail"),        icon: "hourglass")
            statsRow(title: localized("stats.completedSessions"), value: "\(completedSessions)",                               detail: localized("stats.completedSessions.detail"), icon: "checkmark.seal.fill")
            statsRow(title: localized("stats.activeStreak"),      value: localizedFormat("format.days", focusStreak),          detail: localized("stats.activeStreak.detail"),      icon: "flame.fill")
        }
    }

    private func statsRow(title: String, value: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.72))
                .frame(width: 46, height: 46).background(Color(red: 0.18, green: 0.27, blue: 0.24))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(Color.white.opacity(0.68))
            }
            Spacer()
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Color(red: 0.88, green: 0.97, blue: 0.92))
        }
        .padding(16).background(Color(red: 0.11, green: 0.16, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 8)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.accentBright)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("stats.insight.title")).font(.headline).foregroundStyle(.white)
            Text(insightText).font(.body).foregroundStyle(Color.white.opacity(0.74))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.11, green: 0.16, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 8)
    }

    private var insightText: String {
        if completedSessions >= 8 { return localized("stats.insight.high") }
        if completedSessions >= 3 { return localized("stats.insight.medium") }
        return localized("stats.insight.low")
    }

    struct DayData: Identifiable {
        let id    = UUID()
        let label: String
        let minutes: Int
    }

    private var last7DaysData: [DayData] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt   = DateFormatter(); fmt.dateFormat = "E"
        return (0..<7).reversed().map { offset in
            let day  = cal.date(byAdding: .day, value: -offset, to: today)!
            let mins = sessions.filter { $0.completed && cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.durationMinutes }
            return DayData(label: fmt.string(from: day), minutes: mins)
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    @AppStorage("totalFocusMinutes",    store: SharedStore.defaults) private var totalFocusMinutes    = 0
    @AppStorage("completedSessions",    store: SharedStore.defaults) private var completedSessions    = 0
    @AppStorage("focusStreak",          store: SharedStore.defaults) private var focusStreak          = 0
    @AppStorage("ambientSoundsEnabled", store: SharedStore.defaults) private var ambientSoundsEnabled  = true
    @AppStorage("notificationsEnabled", store: SharedStore.defaults) private var notificationsEnabled  = false
    @AppStorage("appLanguage",          store: SharedStore.defaults) private var appLanguage           = AppLanguage.system.rawValue

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [AppTheme.backgroundTop, Color(red: 0.08, green: 0.14, blue: 0.14), AppTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        settingsHeader

                        settingsCard(title: localized("settings.language")) {
                            Menu {
                                ForEach(AppLanguage.allCases) { lang in
                                    Button(localized(lang.labelKey)) { appLanguage = lang.rawValue }
                                }
                            } label: {
                                settingsRow(icon: "globe", title: localized("settings.language"), value: localized((AppLanguage(rawValue: appLanguage) ?? .system).labelKey))
                            }
                        }

                        settingsCard(title: localized("settings.experience")) {
                            Toggle(isOn: $ambientSoundsEnabled) {
                                settingsToggleLabel(icon: "speaker.wave.2.fill", title: localized("settings.ambientSounds"), subtitle: localized("settings.ambientSounds.detail"))
                            }.tint(AppTheme.accent)
                            Divider().overlay(Color.white.opacity(0.08))
                            Toggle(isOn: notificationsBinding) {
                                settingsToggleLabel(icon: "bell.badge.fill", title: localized("settings.notifications"), subtitle: localized("settings.notifications.detail"))
                            }.tint(AppTheme.accent)
                        }

                        settingsCard(title: localized("settings.account")) {
                            statLine(icon: "clock.fill",            text: localizedFormat("settings.totalFocus",        totalFocusMinutes))
                            statLine(icon: "checkmark.circle.fill", text: localizedFormat("settings.completedSessions", completedSessions))
                            statLine(icon: "flame.fill",             text: localizedFormat("settings.streak",            focusStreak))
                        }

                        settingsCard(title: localized("settings.data")) {
                            Button(role: .destructive) { showResetConfirmation = true } label: {
                                HStack {
                                    Label(localized("settings.reset"), systemImage: "arrow.counterclockwise")
                                    Spacer()
                                }
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58)).padding(.vertical, 6)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(localized("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .alert(localized("settings.reset.confirmTitle"), isPresented: $showResetConfirmation) {
                Button(localized("common.cancel"), role: .cancel) { }
                Button(localized("common.reset"), role: .destructive) { resetAll() }
            } message: {
                Text(localized("settings.reset.confirmMessage"))
            }
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("settings.title")).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(localized("settings.hero.subtitle")).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await FocusNotificationManager.shared.requestAuthorizationIfNeeded()
                        await MainActor.run { notificationsEnabled = granted }
                    }
                } else {
                    notificationsEnabled = false
                    FocusNotificationManager.shared.cancelSessionCompletion()
                    FocusNotificationManager.shared.cancelBreakEnd()
                }
            }
        )
    }

    private func resetAll() {
        totalFocusMinutes = 0
        completedSessions = 0
        focusStreak = 0
        for s in sessions { modelContext.delete(s) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            content()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.card.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.accentBright)
                .frame(width: 38, height: 38).background(AppTheme.cardSoft).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(value).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func settingsToggleLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.accentBright)
                .frame(width: 38, height: 38).background(AppTheme.cardSoft).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func statLine(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.accentBright).frame(width: 28)
            Text(text).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white)
        }.padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
