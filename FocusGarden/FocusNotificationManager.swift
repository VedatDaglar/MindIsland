import Foundation
import UserNotifications

final class FocusNotificationManager {
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
        Task {
            do {
                try await center.add(request)
            } catch {
                print("⚠️ Failed to schedule notification '\(identifier)': \(error)")
            }
        }
    }

    func cancelSessionCompletion() { center.removePendingNotificationRequests(withIdentifiers: [completeID]) }
    func cancelBreakEnd()          { center.removePendingNotificationRequests(withIdentifiers: [breakID]) }
}
