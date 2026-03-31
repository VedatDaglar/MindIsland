import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("totalFocusMinutes",    store: SharedStore.defaults) private var totalFocusMinutes    = 0
    @AppStorage("completedSessions",    store: SharedStore.defaults) private var completedSessions    = 0
    @AppStorage("focusStreak",          store: SharedStore.defaults) private var focusStreak          = 0
    @AppStorage("ambientSoundsEnabled", store: SharedStore.defaults) private var ambientSoundsEnabled  = true
    @AppStorage("notificationsEnabled", store: SharedStore.defaults) private var notificationsEnabled  = false
    @AppStorage("appLanguage",          store: SharedStore.defaults) private var appLanguage           = AppLanguage.system.rawValue
    @AppStorage("appearanceMode",       store: SharedStore.defaults) private var appearanceMode        = "dark"

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection

                        VStack(spacing: 16) {
                            // Appearance mode
                            settingsGroup(title: localized("settings.appearance")) {
                                VStack(spacing: 12) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "circle.lefthalf.filled")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .frame(width: 36, height: 36)
                                            .background(AppTheme.accent.opacity(0.15))
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(localized("settings.appearance.title"))
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text(localized("settings.appearance.detail"))
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(AppTheme.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(.vertical, 4)

                                    HStack(spacing: 10) {
                                        appearanceButton(
                                            title: localized("settings.appearance.light"),
                                            icon: "sun.max.fill",
                                            isSelected: appearanceMode == "light"
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                appearanceMode = "light"
                                            }
                                        }

                                        appearanceButton(
                                            title: localized("settings.appearance.dark"),
                                            icon: "moon.fill",
                                            isSelected: appearanceMode == "dark"
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                appearanceMode = "dark"
                                            }
                                        }
                                    }
                                }
                            }

                            settingsGroup(title: localized("settings.experience")) {
                                Toggle(isOn: $ambientSoundsEnabled) {
                                    settingRow(icon: "speaker.wave.2.fill", color: AppTheme.accentBreakBright, title: localized("settings.ambientSounds"), subtitle: localized("settings.ambientSounds.detail"))
                                }
                                .tint(AppTheme.accent)
                                .onChange(of: ambientSoundsEnabled) { newValue in
                                    if newValue { FocusSoundPlayer.shared.startAmbient() }
                                    else { FocusSoundPlayer.shared.stopAmbient() }
                                }

                                Divider().background(AppTheme.border)

                                Toggle(isOn: $notificationsEnabled) {
                                    settingRow(icon: "bell.badge.fill", color: AppTheme.accentBright, title: localized("settings.notifications"), subtitle: localized("settings.notifications.detail"))
                                }
                                .tint(AppTheme.accent)
                                .onChange(of: notificationsEnabled) { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await FocusNotificationManager.shared.requestAuthorizationIfNeeded()
                                            if !granted { notificationsEnabled = false }
                                        }
                                    }
                                }

                                Divider().background(AppTheme.border)

                                Menu {
                                    Picker("Language", selection: $appLanguage) {
                                        ForEach(AppLanguage.allCases) { lang in
                                            Text(localized(lang.labelKey)).tag(lang.rawValue)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        settingRow(icon: "globe", color: AppTheme.accentBright, title: localized("settings.language"), subtitle: nil)
                                        Spacer()
                                        Text(localized(AppLanguage(rawValue: appLanguage)?.labelKey ?? "settings.language.system"))
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }

                            settingsGroup(title: localized("settings.account")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(localizedFormat("settings.totalFocus", totalFocusMinutes))
                                    Text(localizedFormat("settings.completedSessions", completedSessions))
                                    Text(localizedFormat("settings.streak", focusStreak))
                                }
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }

                            settingsGroup(title: localized("settings.musicSounds")) {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localized("settings.allAtmospheres"))
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(AppTheme.textPrimary)

                                        HStack(spacing: 4) {
                                            Text(localized("settings.generatedBy"))
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(AppTheme.textSecondary)

                                            Link("ElevenLabs", destination: URL(string: "https://elevenlabs.io")!)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                                }
                            }

                            settingsGroup(title: localized("settings.data")) {
                                Button(role: .destructive) {
                                    showResetConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill").font(.system(size: 16, weight: .semibold))
                                        Text(localized("settings.reset")).font(.system(size: 16, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .padding(24).padding(.bottom, 36)
                }
            }
            .navigationTitle(localized("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(localized("settings.reset.confirmTitle"), isPresented: $showResetConfirmation) {
                Button(localized("common.cancel"), role: .cancel) { }
                Button(localized("common.reset"), role: .destructive) { resetAllData() }
            } message: { Text(localized("settings.reset.confirmMessage")) }
        }
    }

    private func appearanceButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.20) : AppTheme.cardSoft)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.50) : AppTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 80, height: 80)
                .background(AppTheme.cardSoft)
                .clipShape(Circle())

            Text(localized("settings.hero.subtitle"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary).padding(.horizontal, 4)
            VStack(spacing: 16) { content() }.padding(20).background(AppTheme.card.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
        }
    }

    private func settingRow(icon: String, color: Color, title: String, subtitle: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                .frame(width: 36, height: 36).background(color.opacity(0.15)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                if let sub = subtitle {
                    Text(sub).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func resetAllData() {
        totalFocusMinutes = 0
        completedSessions = 0
        focusStreak       = 0
        SharedStore.defaults?.set("", forKey: "lastSessionDate")
        do {
            try modelContext.delete(model: FocusSession.self)
        } catch {
            print("⚠️ Failed to delete session data: \(error)")
        }
    }
}
