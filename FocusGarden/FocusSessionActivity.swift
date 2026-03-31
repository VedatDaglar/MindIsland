import Foundation
import ActivityKit

struct FocusSessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var isRunning: Bool
        var sessionTitle: String
        var dailyTotalMinutes: Int?
    }

    var sessionName: String
}
