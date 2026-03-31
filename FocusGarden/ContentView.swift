import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appLanguage", store: SharedStore.defaults) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("appearanceMode", store: SharedStore.defaults) private var appearanceMode = "dark"

    private var currentLocale: Locale {
        let selectedLanguage = AppLanguage(rawValue: appLanguage) ?? .system
        if let identifier = selectedLanguage.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return .current
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(localized("tab.focus"), systemImage: "leaf.fill") }
                .tag(0)

            StatsView()
                .tabItem { Label(localized("tab.stats"), systemImage: "chart.bar.fill") }
                .tag(1)

            RewardsView()
                .tabItem { Label(localized("tab.rewards"), systemImage: "gift.fill") }
                .tag(2)

            SettingsView()
                .tabItem { Label(localized("tab.settings"), systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(appearanceMode == "dark" ? .dark : .light)
        .environment(\.locale, currentLocale)
    }
}
