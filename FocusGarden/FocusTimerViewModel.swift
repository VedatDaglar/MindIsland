import Foundation
import SwiftUI
import SwiftData
import ActivityKit
import WidgetKit
import Observation

@Observable
final class FocusTimerViewModel {
    private enum Keys {
        static let totalFocusMinutes = "totalFocusMinutes"
        static let completedSessions = "completedSessions"
        static let focusStreak = "focusStreak"
        static let lastSessionDate = "lastSessionDate"
        static let ambientSoundsEnabled = "ambientSoundsEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let lastSelectedCategory = "lastSelectedCategory"
        static let focusCoins = "focusCoins"
        static let focusDuration = "focusDuration"
        static let breakDuration = "breakDuration"
        static let timerIsRunning = "timerIsRunning"
        static let breakIsRunning = "breakIsRunning"
        static let sessionEndDate = "sessionEndDate"
        static let breakEndDate = "breakEndDate"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var modelContext: ModelContext?

    var totalFocusMinutes: Int
    var completedSessions: Int
    var focusStreak: Int
    var lastSessionDate: String
    var ambientSoundsEnabled: Bool
    var notificationsEnabled: Bool
    var selectedCategory: String
    var focusCoins: Int

    var focusDuration: Int
    var timeRemaining: Int
    var timerIsRunning: Bool
    var sessionCompleted: Bool
    var showCelebration: Bool
    var sessionFailed: Bool
    var sessionEndDate: Date?

    var breakDuration: Int
    var breakTimeRemaining: Int
    var breakIsRunning: Bool
    var breakEndDate: Date?

    var showCustomSheet: Bool
    var customMinutes: Double

    init(defaults: UserDefaults = SharedStore.defaults ?? .standard) {
        self.defaults = defaults

        let initialFocusMinutes = 25
        let initialFocusDuration = initialFocusMinutes * 60
        let initialBreakDuration = FocusTimerViewModel.suggestedBreakDuration(forFocusMinutes: initialFocusMinutes)
        let storedFocusDuration = defaults.object(forKey: Keys.focusDuration) as? Int ?? initialFocusDuration
        let storedBreakDuration = defaults.object(forKey: Keys.breakDuration) as? Int ?? initialBreakDuration

        totalFocusMinutes = defaults.integer(forKey: Keys.totalFocusMinutes)
        completedSessions = defaults.integer(forKey: Keys.completedSessions)
        focusStreak = defaults.integer(forKey: Keys.focusStreak)
        lastSessionDate = defaults.string(forKey: Keys.lastSessionDate) ?? ""
        ambientSoundsEnabled = defaults.object(forKey: Keys.ambientSoundsEnabled) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? false
        selectedCategory = defaults.string(forKey: Keys.lastSelectedCategory) ?? "general"
        focusCoins = defaults.integer(forKey: Keys.focusCoins)

        focusDuration = storedFocusDuration
        timeRemaining = storedFocusDuration
        timerIsRunning = false
        sessionCompleted = false
        showCelebration = false
        sessionFailed = false
        sessionEndDate = nil

        breakDuration = storedBreakDuration
        breakTimeRemaining = storedBreakDuration
        breakIsRunning = false
        breakEndDate = nil

        showCustomSheet = false
        customMinutes = 30

        restorePersistedTimerState()
    }

    var timeString: String {
        let source = breakIsRunning ? breakTimeRemaining : timeRemaining
        return String(format: "%02d:%02d", source / 60, source % 60)
    }

    var progressValue: Double {
        if breakIsRunning {
            guard breakDuration > 0 else { return 0 }
            return min(max(Double(breakDuration - breakTimeRemaining) / Double(breakDuration), 0), 1)
        }

        guard focusDuration > 0 else { return 0 }
        return min(max(Double(focusDuration - timeRemaining) / Double(focusDuration), 0), 1)
    }

    var statusText: String {
        if sessionFailed { return localized("home.status.failed") }
        if breakIsRunning { return localized("home.status.break") }
        if timerIsRunning { return localized("home.status.running") }
        if sessionCompleted { return localized("home.status.completed") }
        return localizedFormat("home.status.ready", selectedMinutes)
    }

    var orbTitle: String {
        if breakIsRunning { return localized("home.break.title") }
        if timerIsRunning { return localized("home.timer.remaining") }
        if sessionCompleted { return localized("home.timer.completed") }
        return localized("home.timer.ready")
    }

    var selectedMinutes: Int { focusDuration / 60 }
    var isCustomSelected: Bool { ![15, 25, 45, 60].contains(selectedMinutes) }

    var buttonTitle: String {
        timerIsRunning ? localized("home.stopSession") : localizedFormat("home.startSession", selectedMinutes)
    }

    var todayPreviewMinutes: Int {
        if timerIsRunning {
            return max(totalFocusMinutes + ((focusDuration - timeRemaining) / 60), 0)
        }
        return totalFocusMinutes
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func reloadStoredValues() {
        totalFocusMinutes = defaults.integer(forKey: Keys.totalFocusMinutes)
        completedSessions = defaults.integer(forKey: Keys.completedSessions)
        focusStreak = defaults.integer(forKey: Keys.focusStreak)
        lastSessionDate = defaults.string(forKey: Keys.lastSessionDate) ?? ""
        ambientSoundsEnabled = defaults.object(forKey: Keys.ambientSoundsEnabled) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? false
        selectedCategory = defaults.string(forKey: Keys.lastSelectedCategory) ?? "general"
        focusCoins = defaults.integer(forKey: Keys.focusCoins)
        restorePersistedTimerState()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            reloadStoredValues()
            syncWithCurrentTime()
            if timerIsRunning {
                updateLiveActivity()
            }
        case .background, .inactive:
            persistTimerState()
            break
        @unknown default:
            break
        }
    }

    func requestNotificationAuthorizationIfNeeded() async {
        guard notificationsEnabled else { return }

        let isAuthorized = await FocusNotificationManager.shared.requestAuthorizationIfNeeded()
        guard !isAuthorized else { return }

        notificationsEnabled = false
        defaults.set(false, forKey: Keys.notificationsEnabled)
    }

    func startSession() {
        guard !timerIsRunning else { return }

        sessionCompleted = false
        sessionFailed = false
        showCelebration = false
        timeRemaining = focusDuration
        timerIsRunning = true
        sessionEndDate = Date().addingTimeInterval(TimeInterval(focusDuration))
        breakIsRunning = false
        breakEndDate = nil
        breakDuration = Self.suggestedBreakDuration(forFocusMinutes: focusDuration / 60)
        breakTimeRemaining = breakDuration
        persistTimerState()

        startLiveActivity()

        if ambientSoundsEnabled {
            FocusSoundPlayer.shared.stopAmbient()
            FocusSoundPlayer.shared.play(.start)
            FocusSoundPlayer.shared.startAmbient()
        }

        if notificationsEnabled {
            FocusNotificationManager.shared.scheduleSessionCompletion(after: focusDuration)
        }
    }

    func stopSession() {
        timerIsRunning = false
        timeRemaining = focusDuration
        sessionEndDate = nil
        persistTimerState()

        endLiveActivity()
        FocusSoundPlayer.shared.stopAmbient()
        FocusNotificationManager.shared.cancelSessionCompletion()
    }

    func failSession() {
        showCelebration = false
        timerIsRunning = false
        sessionCompleted = false
        sessionFailed = true
        timeRemaining = focusDuration
        sessionEndDate = nil
        persistTimerState()

        endLiveActivity(finalState: .init(
            startDate: Date(),
            endDate: Date(),
            isRunning: false,
            sessionTitle: localized("home.status.failed"),
            dailyTotalMinutes: nil
        ))

        FocusSoundPlayer.shared.stopAmbient()
        FocusNotificationManager.shared.cancelSessionCompletion()
        FocusNotificationManager.shared.cancelBreakEnd()
    }

    func startBreakFromCelebration() {
        showCelebration = false
        startBreak()
    }

    func dismissCelebration() {
        showCelebration = false
        timeRemaining = focusDuration
        sessionCompleted = false
        persistTimerState()
    }

    func dismissFailure() {
        sessionFailed = false
    }

    func skipBreak() {
        breakIsRunning = false
        breakEndDate = nil
        breakTimeRemaining = breakDuration
        timeRemaining = focusDuration
        sessionCompleted = false
        persistTimerState()
        FocusNotificationManager.shared.cancelBreakEnd()
    }

    func selectDuration(_ minutes: Int) {
        guard !timerIsRunning else { return }

        focusDuration = minutes * 60
        timeRemaining = focusDuration
        sessionCompleted = false
        showCelebration = false
        sessionEndDate = nil
        breakDuration = Self.suggestedBreakDuration(forFocusMinutes: minutes)
        breakTimeRemaining = breakDuration
        persistTimerState()
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        defaults.set(category, forKey: Keys.lastSelectedCategory)
    }

    func presentCustomSheet() {
        guard !timerIsRunning else { return }
        showCustomSheet = true
    }

    func dismissCustomSheet() {
        showCustomSheet = false
    }

    func confirmCustomDurationSelection() {
        selectDuration(Int(customMinutes))
        showCustomSheet = false
    }

    func handleTick() {
        if timerIsRunning {
            guard let end = sessionEndDate else {
                timerIsRunning = false
                return
            }

            let remaining = max(Int(ceil(end.timeIntervalSinceNow)), 0)
            if remaining == 0 {
                timeRemaining = 0
                completeSession()
            } else {
                timeRemaining = remaining
            }
        }

        if breakIsRunning {
            guard let end = breakEndDate else {
                breakIsRunning = false
                return
            }

            let remaining = max(Int(ceil(end.timeIntervalSinceNow)), 0)
            if remaining == 0 {
                breakTimeRemaining = 0
                completeBreak()
            } else {
                breakTimeRemaining = remaining
            }
        }
    }

    private func syncWithCurrentTime() {
        if timerIsRunning, let end = sessionEndDate {
            let remaining = Int(end.timeIntervalSince(Date()))
            if remaining <= 0 {
                timeRemaining = 0
                completeSession()
            } else {
                timeRemaining = remaining
            }
        } else if breakIsRunning, let end = breakEndDate {
            let remaining = Int(end.timeIntervalSince(Date()))
            if remaining <= 0 {
                breakTimeRemaining = 0
                completeBreak()
            } else {
                breakTimeRemaining = remaining
            }
        }
    }

    private func completeSession() {
        guard timerIsRunning else { return }

        timerIsRunning = false
        sessionCompleted = true

        let addedMinutes = focusDuration / 60
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dailyTotal = dailyCompletedMinutes(on: today) + addedMinutes

        totalFocusMinutes += addedMinutes
        completedSessions += 1
        focusCoins += addedMinutes

        let todayString = ISO8601DateFormatter().string(from: today)
        if lastSessionDate != todayString {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let yesterdayString = ISO8601DateFormatter().string(from: yesterday)
            focusStreak = (lastSessionDate == yesterdayString) ? focusStreak + 1 : 1
            lastSessionDate = todayString
        }

        persistProgress()

        if let modelContext {
            modelContext.insert(FocusSession(
                date: Date(),
                durationMinutes: addedMinutes,
                completed: true,
                category: selectedCategory
            ))
            do {
                try modelContext.save()
            } catch {
                print("⚠️ Failed to save focus session: \(error)")
            }
        }

        sessionEndDate = nil
        persistTimerState()

        endLiveActivity(finalState: .init(
            startDate: Date(),
            endDate: Date(),
            isRunning: false,
            sessionTitle: localized("home.timer.completed"),
            dailyTotalMinutes: dailyTotal
        ))

        WidgetCenter.shared.reloadAllTimelines()
        FocusNotificationManager.shared.cancelSessionCompletion()

        if ambientSoundsEnabled {
            FocusSoundPlayer.shared.stopAmbient()
            FocusSoundPlayer.shared.play(.complete)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showCelebration = true
        }
    }

    private func startBreak() {
        guard !breakIsRunning else { return }

        breakIsRunning = true
        breakTimeRemaining = breakDuration
        breakEndDate = Date().addingTimeInterval(TimeInterval(breakDuration))
        persistTimerState()

        if ambientSoundsEnabled {
            FocusSoundPlayer.shared.play(.breakStart)
        }

        if notificationsEnabled {
            FocusNotificationManager.shared.scheduleBreakEnd(after: breakDuration)
        }
    }

    private func completeBreak() {
        guard breakIsRunning else { return }

        breakIsRunning = false
        breakEndDate = nil
        timeRemaining = focusDuration
        sessionCompleted = false
        persistTimerState()

        if ambientSoundsEnabled {
            FocusSoundPlayer.shared.play(.breakEnd)
        }

        FocusNotificationManager.shared.cancelBreakEnd()
    }

    private func persistProgress() {
        defaults.set(totalFocusMinutes, forKey: Keys.totalFocusMinutes)
        defaults.set(completedSessions, forKey: Keys.completedSessions)
        defaults.set(focusStreak, forKey: Keys.focusStreak)
        defaults.set(lastSessionDate, forKey: Keys.lastSessionDate)
        defaults.set(focusCoins, forKey: Keys.focusCoins)
    }

    private func persistTimerState() {
        defaults.set(focusDuration, forKey: Keys.focusDuration)
        defaults.set(breakDuration, forKey: Keys.breakDuration)
        defaults.set(timerIsRunning, forKey: Keys.timerIsRunning)
        defaults.set(breakIsRunning, forKey: Keys.breakIsRunning)

        if let sessionEndDate {
            defaults.set(sessionEndDate, forKey: Keys.sessionEndDate)
        } else {
            defaults.removeObject(forKey: Keys.sessionEndDate)
        }

        if let breakEndDate {
            defaults.set(breakEndDate, forKey: Keys.breakEndDate)
        } else {
            defaults.removeObject(forKey: Keys.breakEndDate)
        }
    }

    private func restorePersistedTimerState() {
        focusDuration = defaults.object(forKey: Keys.focusDuration) as? Int ?? focusDuration
        breakDuration = defaults.object(forKey: Keys.breakDuration) as? Int ?? breakDuration
        timerIsRunning = defaults.object(forKey: Keys.timerIsRunning) as? Bool ?? timerIsRunning
        breakIsRunning = defaults.object(forKey: Keys.breakIsRunning) as? Bool ?? breakIsRunning
        sessionEndDate = defaults.object(forKey: Keys.sessionEndDate) as? Date
        breakEndDate = defaults.object(forKey: Keys.breakEndDate) as? Date

        if timerIsRunning, let sessionEndDate {
            timeRemaining = max(Int(ceil(sessionEndDate.timeIntervalSinceNow)), 0)
        } else {
            timeRemaining = focusDuration
        }

        if breakIsRunning, let breakEndDate {
            breakTimeRemaining = max(Int(ceil(breakEndDate.timeIntervalSinceNow)), 0)
        } else {
            breakTimeRemaining = breakDuration
        }
    }

    private func dailyCompletedMinutes(on day: Date) -> Int {
        guard let modelContext else { return 0 }

        let descriptor = FetchDescriptor<FocusSession>()
        let sessions: [FocusSession]
        do {
            sessions = try modelContext.fetch(descriptor)
        } catch {
            print("⚠️ Failed to fetch sessions for daily stats: \(error)")
            sessions = []
        }
        let calendar = Calendar.current

        return sessions
            .filter { $0.completed && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private static func suggestedBreakDuration(forFocusMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<20: return 3 * 60
        case ..<40: return 5 * 60
        case ..<70: return 10 * 60
        default: return 15 * 60
        }
    }

    private func startLiveActivity() {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let end = sessionEndDate ?? Date().addingTimeInterval(TimeInterval(focusDuration))
        let start = end.addingTimeInterval(TimeInterval(-focusDuration))
        let attributes = FocusSessionActivityAttributes(sessionName: localized("app.name"))
        let state = FocusSessionActivityAttributes.ContentState(
            startDate: start,
            endDate: end,
            isRunning: true,
            sessionTitle: localized("home.timer.remaining"),
            dailyTotalMinutes: nil
        )

        Task {
            for activity in Activity<FocusSessionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            do {
                _ = try Activity<FocusSessionActivityAttributes>.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: end.addingTimeInterval(3600)),
                    pushType: nil
                )
            } catch {
                print("Live activity start failed: \(error)")
            }
        }
    }

    private func updateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }

        let end = sessionEndDate ?? Date().addingTimeInterval(TimeInterval(timeRemaining))
        let start = end.addingTimeInterval(TimeInterval(-focusDuration))
        let state = FocusSessionActivityAttributes.ContentState(
            startDate: start,
            endDate: end,
            isRunning: timerIsRunning,
            sessionTitle: timerIsRunning ? localized("home.timer.remaining") : localized("home.timer.completed"),
            dailyTotalMinutes: nil
        )

        Task {
            for activity in Activity<FocusSessionActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: end.addingTimeInterval(60)))
            }
        }
    }

    private func endLiveActivity(finalState: FocusSessionActivityAttributes.ContentState? = nil) {
        guard #available(iOS 16.2, *) else { return }

        let state: FocusSessionActivityAttributes.ContentState
        if let finalState {
            state = finalState
        } else {
            state = FocusSessionActivityAttributes.ContentState(
                startDate: Date(),
                endDate: Date(),
                isRunning: false,
                sessionTitle: localized("home.timer.completed"),
                dailyTotalMinutes: dailyCompletedMinutes(on: Calendar.current.startOfDay(for: Date()))
            )
        }

        Task {
            for activity in Activity<FocusSessionActivityAttributes>.activities {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default)
            }
        }
    }
}
