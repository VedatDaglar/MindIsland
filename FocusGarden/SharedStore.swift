import Foundation

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
        "notificationsEnabled",
        // TODO: "deepFocusModeEnabled" — gelecek sürümde eklenecek
        // TODO: "autoPomodoroEnabled" — gelecek sürümde eklenecek
        "lastSelectedCategory",
        "focusCoins",
        "unlockedItems",
        "activeThemeId",
        "activeSoundId",
        "appearanceMode"
    ]
}
