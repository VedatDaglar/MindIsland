import SwiftUI

struct RewardsView: View {
    @AppStorage("appLanguage", store: SharedStore.defaults) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("totalFocusMinutes", store: SharedStore.defaults) private var totalFocusMinutes = 0
    @AppStorage("activeAtmosphereId", store: SharedStore.defaults) private var activeAtmosphereId = "atmosphere.zen"
    @AppStorage("activeThemeId", store: SharedStore.defaults) private var activeThemeId = "theme.zen"
    @AppStorage("activeSoundId", store: SharedStore.defaults) private var activeSoundId = "zen_garden"

    private let unlockAllAtmospheresForTesting = false

    private var baseBackground: Color { AppTheme.backgroundTop }
    private var cardBackground: Color { AppTheme.card }

    private var selectedAtmosphere: Atmosphere {
        atmospheres.first(where: { $0.id == activeAtmosphereId }) ?? atmospheres[0]
    }

    private var unlockedCount: Int {
        atmospheres.filter { isUnlocked($0) }.count
    }

    private var nextUnlockAtmosphere: Atmosphere? {
        atmospheres
            .filter { !isUnlocked($0) }
            .sorted { effectiveRequiredMinutes(for: $0) < effectiveRequiredMinutes(for: $1) }
            .first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroSection

                        LazyVStack(spacing: 18) {
                            ForEach(atmospheres) { atmosphere in
                                atmosphereRow(atmosphere)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(rewardsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(baseBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            //.toolbarColorScheme removed for dynamic light/dark
            .onAppear {
                syncStoredSelection()
            }
        }
    }

    private var backgroundLayer: some View {
        AppTheme.backgroundTop.ignoresSafeArea()
    }

    private var heroSection: some View {
        let palette = selectedAtmosphere.glowPalette

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(palette.gradient)
                        .opacity(0.22)
                        .frame(width: 72, height: 72)
                        .blur(radius: 6)

                    Circle()
                        .fill(AppTheme.cardSoft.opacity(0.6))
                        .frame(width: 62, height: 62)

                    Image(systemName: selectedAtmosphere.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(palette.gradient)
                        .shadow(color: palette.glow.opacity(0.75), radius: 16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(heroOverline)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(1.8)

                    Text(localized("rewards.hero.title"))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(localized("rewards.hero.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(focusMinutesLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.3)

                Text(localizedFormat("format.minutes", totalFocusMinutes))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .shadow(color: palette.glow.opacity(0.35), radius: 18)
            }

            HStack(spacing: 12) {
                heroPill(
                    title: selectedTitle,
                    value: selectedAtmosphere.title,
                    palette: palette
                )

                heroPill(
                    title: nextUnlockTitle,
                    value: nextUnlockAtmosphere.map { "\(max(effectiveRequiredMinutes(for: $0) - totalFocusMinutes, 0)) \(minutesShort)" } ?? allUnlockedTitle,
                    palette: nextUnlockAtmosphere?.glowPalette ?? palette
                )

                heroPill(
                    title: unlockedTitle,
                    value: "\(unlockedCount)/\(atmospheres.count)",
                    palette: palette
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.90, blue: 1.00).opacity(0.70),
                            Color(red: 0.90, green: 0.20, blue: 0.80).opacity(0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .shadow(color: Color(red: 0.10, green: 0.90, blue: 1.00).opacity(0.24), radius: 20)
                .shadow(color: Color(red: 0.90, green: 0.20, blue: 0.80).opacity(0.18), radius: 26)
        }
    }

    private func heroPill(title: String, value: String, palette: AtmosphereGlowPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardSoft.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.gradient, lineWidth: 1)
                .opacity(0.38)
        }
    }

    private func atmosphereRow(_ atmosphere: Atmosphere) -> some View {
        let palette = atmosphere.glowPalette
        let unlocked = isUnlocked(atmosphere)
        let selected = activeAtmosphereId == atmosphere.id
        let requiredMinutes = effectiveRequiredMinutes(for: atmosphere)
        let remainingMinutes = max(requiredMinutes - totalFocusMinutes, 0)
        let progress = progressValue(for: atmosphere)

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBackground.opacity(unlocked ? 0.96 : 0.88))

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(palette.gradient)
                            .opacity(unlocked ? 0.20 : 0.10)
                            .frame(width: 62, height: 62)
                            .blur(radius: 6)

                        Circle()
                            .fill(AppTheme.cardSoft.opacity(unlocked ? 0.6 : 0.4))
                            .frame(width: 56, height: 56)

                        Image(systemName: atmosphere.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(unlocked ? palette.gradient : palette.mutedGradient)
                            .shadow(color: palette.glow.opacity(unlocked ? 0.70 : 0.22), radius: unlocked ? 16 : 8)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(atmosphere.title)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)

                            if selected {
                                capsuleLabel(text: selectedBadge, gradient: palette.gradient, isBright: true)
                            } else if unlocked {
                                capsuleLabel(text: unlockedBadge, gradient: palette.gradient, isBright: false)
                            } else {
                                capsuleLabel(text: lockedBadge, gradient: palette.mutedGradient, isBright: false)
                            }
                        }

                        Text(atmosphereSubtitle(for: atmosphere))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary.opacity(unlocked ? 0.95 : 0.75))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(requiredMinutes == 0 ? instantUnlockText : localizedFormat("format.minutes", requiredMinutes))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(unlocked ? palette.accent.opacity(0.92) : AppTheme.textSecondary.opacity(0.6))
                    }

                    Spacer(minLength: 0)
                }

                if unlocked {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(equipmentLabel)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(selected ? activeStateText : readyToActivateText)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Spacer(minLength: 0)

                        Button {
                            activate(atmosphere)
                        } label: {
                            Text(selected ? selectedButtonLabel : activateButtonLabel)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(palette.gradient)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(AppTheme.textPrimary.opacity(0.18), lineWidth: 0.8)
                                }
                                .shadow(color: palette.glow.opacity(0.45), radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary.opacity(0.82))
                            Text(unlockMessage(remainingMinutes: remainingMinutes))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        NeonProgressBar(progress: progress, palette: palette, locked: true)

                        HStack {
                            Text("\(totalFocusMinutes) / \(requiredMinutes) \(minutesShort)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("\(remainingMinutes) \(minutesShort)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.accent.opacity(0.85))
                        }
                    }
                }
            }
            .padding(20)
            .overlay(alignment: .topTrailing) {
                if !unlocked {
                    ZStack {
                        Circle()
                            .fill(AppTheme.backgroundTop.opacity(0.80))
                            .frame(width: 38, height: 38)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.88))
                    }
                    .padding(14)
                }
            }

            if !unlocked {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.backgroundTop.opacity(0.30))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(unlocked ? palette.gradient : palette.mutedGradient, lineWidth: 1.05)
                .shadow(color: palette.glow.opacity(unlocked ? (selected ? 0.55 : 0.28) : 0.10), radius: unlocked ? (selected ? 22 : 14) : 8)
                .shadow(color: palette.accent.opacity(unlocked ? 0.18 : 0.06), radius: unlocked ? 10 : 5)
        }
        .opacity(unlocked ? 1.0 : 0.88)
    }

    private func capsuleLabel(text: String, gradient: LinearGradient, isBright: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary.opacity(isBright ? 0.95 : 0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isBright {
                    Capsule()
                        .fill(gradient)
                        .opacity(0.24)
                } else {
                    Capsule()
                        .fill(AppTheme.cardSoft.opacity(0.4))
                }
            }
            .overlay {
                Capsule()
                    .stroke(gradient, lineWidth: 0.9)
                    .opacity(isBright ? 0.72 : 0.25)
            }
    }

    private func isUnlocked(_ atmosphere: Atmosphere) -> Bool {
        totalFocusMinutes >= effectiveRequiredMinutes(for: atmosphere)
    }

    private func effectiveRequiredMinutes(for atmosphere: Atmosphere) -> Int {
        if unlockAllAtmospheresForTesting {
            return 0
        }

        if atmosphere.requiredMinutes > 0 || atmosphere.id == "atmosphere.zen" {
            return atmosphere.requiredMinutes
        }

        switch atmosphere.id {
        case "atmosphere.neon":
            return 250
        case "atmosphere.campfire":
            return 500
        case "atmosphere.deepfocus":
            return 1000
        case "atmosphere.cafe":
            return 1500
        default:
            return 0
        }
    }

    private func progressValue(for atmosphere: Atmosphere) -> Double {
        let requiredMinutes = effectiveRequiredMinutes(for: atmosphere)
        guard requiredMinutes > 0 else { return 1.0 }
        return min(max(Double(totalFocusMinutes) / Double(requiredMinutes), 0), 1)
    }

    private func activate(_ atmosphere: Atmosphere) {
        activeAtmosphereId = atmosphere.id
        activeThemeId = atmosphere.themeId
        activeSoundId = atmosphere.soundName
    }

    private func syncStoredSelection() {
        guard let stored = atmospheres.first(where: { $0.id == activeAtmosphereId }) else {
            activate(atmospheres[0])
            return
        }

        if isUnlocked(stored) {
            activeThemeId = stored.themeId
            activeSoundId = stored.soundName
        } else {
            activate(atmospheres[0])
        }
    }

    private func atmosphereSubtitle(for atmosphere: Atmosphere) -> String {
        switch atmosphere.id {
        case "atmosphere.zen":
            return subtitle(
                tr: "Koyu orman tonlarıyla sakin ama elektrikli bir matcha nefesi.",
                en: "A calm matcha pulse wrapped in dark forest depth.",
                zh: "深色森林中的抹茶脉冲，安静却充满能量。"
            )
        case "atmosphere.neon":
            return subtitle(
                tr: "Yağmur, neon ve gece akışını tek panelde toplar.",
                en: "Rain, neon and night-drive energy in one stream.",
                zh: "把雨夜、霓虹与深夜节奏融合成一个场景。"
            )
        case "atmosphere.campfire":
            return subtitle(
                tr: "Korunmalı, sıcak ve yoğun bir ateş başında odak modülü.",
                en: "A warm ember-lit module for long, grounded focus.",
                zh: "像围坐篝火般温暖而沉浸的专注模块。"
            )
        case "atmosphere.deepfocus":
            return subtitle(
                tr: "Saf siyah, temiz frekanslar ve dağılmayan dikkat alanı.",
                en: "Pure black, clean frequencies and zero visual noise.",
                zh: "纯黑背景、干净频率与极低视觉干扰。"
            )
        case "atmosphere.cafe":
            return subtitle(
                tr: "Gece kahvesi, lo-fi enerji ve uzun seans akışı.",
                en: "Late-night espresso energy for smooth long sessions.",
                zh: "深夜咖啡馆氛围，适合平稳而漫长的专注。"
            )
        default:
            return ""
        }
    }

    private func unlockMessage(remainingMinutes: Int) -> String {
        switch currentLanguage {
        case .turkish:
            return "Kilidi açmak için \(remainingMinutes) dakika daha odaklan"
        case .english:
            return "Focus \(remainingMinutes) more minutes to unlock"
        case .chinese:
            return "再专注 \(remainingMinutes) 分钟即可解锁"
        case .system:
            return fallbackSystemMessage(remainingMinutes: remainingMinutes)
        }
    }

    private func fallbackSystemMessage(remainingMinutes: Int) -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("tr") {
            return "Kilidi açmak için \(remainingMinutes) dakika daha odaklan"
        }
        if preferred.hasPrefix("zh") {
            return "再专注 \(remainingMinutes) 分钟即可解锁"
        }
        return "Focus \(remainingMinutes) more minutes to unlock"
    }

    private func subtitle(tr: String, en: String, zh: String) -> String {
        switch currentLanguage {
        case .turkish:
            return tr
        case .english:
            return en
        case .chinese:
            return zh
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("tr") { return tr }
            if preferred.hasPrefix("zh") { return zh }
            return en
        }
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }

    private var rewardsTitle: String {
        localized("rewards.title")
    }

    private var heroOverline: String {
        subtitle(tr: "CYBER ATMOSPHERES", en: "CYBER ATMOSPHERES", zh: "赛博氛围")
    }

    private var focusMinutesLabel: String {
        subtitle(tr: "TOPLAM ODAK", en: "TOTAL FOCUS", zh: "累计专注")
    }

    private var selectedTitle: String {
        subtitle(tr: "Seçili", en: "Selected", zh: "当前选择")
    }

    private var nextUnlockTitle: String {
        subtitle(tr: "Sıradaki", en: "Next Drop", zh: "下一个")
    }

    private var unlockedTitle: String {
        localized("rewards.unlocked")
    }

    private var allUnlockedTitle: String {
        localized("rewards.allUnlocked")
    }

    private var selectedBadge: String {
        subtitle(tr: "SEÇİLİ", en: "SELECTED", zh: "已选择")
    }

    private var unlockedBadge: String {
        subtitle(tr: "AÇIK", en: "OPEN", zh: "已开放")
    }

    private var lockedBadge: String {
        subtitle(tr: "KİLİTLİ", en: "LOCKED", zh: "已锁定")
    }

    private var selectedButtonLabel: String {
        subtitle(tr: "Aktif", en: "Live", zh: "启用中")
    }

    private var activateButtonLabel: String {
        subtitle(tr: "Atmosferi Seç", en: "Activate", zh: "启用氛围")
    }

    private var equipmentLabel: String {
        subtitle(tr: "Atmosfer Durumu", en: "Atmosphere Status", zh: "氛围状态")
    }

    private var activeStateText: String {
        subtitle(tr: "Bu atmosfer şu an aktif.", en: "This atmosphere is currently active.", zh: "当前正在使用这个氛围。")
    }

    private var readyToActivateText: String {
        subtitle(tr: "Açıldı. Tek dokunuşla etkinleştir.", en: "Unlocked and ready to launch.", zh: "已解锁，可一键启用。")
    }

    private var instantUnlockText: String {
        subtitle(tr: "Anında açık", en: "Instant unlock", zh: "立即开放")
    }

    private var minutesShort: String {
        subtitle(tr: "dk", en: "min", zh: "分钟")
    }
}

private struct AtmosphereGlowPalette {
    let accent: Color
    let glow: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, glow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var mutedGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.30),
                glow.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct NeonProgressBar: View {
    let progress: Double
    let palette: AtmosphereGlowPalette
    let locked: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clamped = min(max(progress, 0), 1)
            let fillWidth = max(width * clamped, clamped > 0 ? 16 : 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.cardSoft)

                Capsule()
                    .fill(locked ? palette.mutedGradient : palette.gradient)
                    .frame(width: fillWidth)
                    .shadow(color: palette.glow.opacity(locked ? 0.18 : 0.42), radius: locked ? 10 : 16)
            }
        }
        .frame(height: 10)
    }
}

private extension Atmosphere {
    var title: String {
        switch id {
        case "atmosphere.zen":
            return "Zen Garden"
        case "atmosphere.neon":
            return "Neon Rain"
        case "atmosphere.campfire":
            return "Campfire"
        case "atmosphere.deepfocus":
            return "Deep Focus"
        case "atmosphere.cafe":
            return "Cafe Flow"
        default:
            return id
        }
    }

    var glowPalette: AtmosphereGlowPalette {
        switch id {
        case "atmosphere.zen":
            return AtmosphereGlowPalette(
                accent: Color(red: 0.35, green: 0.95, blue: 0.60),
                glow: Color(red: 0.15, green: 0.85, blue: 0.45)
            )
        case "atmosphere.neon":
            return AtmosphereGlowPalette(
                accent: Color(red: 0.10, green: 0.90, blue: 1.00),
                glow: Color(red: 0.90, green: 0.20, blue: 0.80)
            )
        case "atmosphere.campfire":
            return AtmosphereGlowPalette(
                accent: Color(red: 0.98, green: 0.60, blue: 0.20),
                glow: Color(red: 0.85, green: 0.35, blue: 0.15)
            )
        case "atmosphere.deepfocus":
            return AtmosphereGlowPalette(
                accent: Color(red: 0.95, green: 0.96, blue: 0.98),
                glow: Color(red: 0.55, green: 0.65, blue: 0.85)
            )
        case "atmosphere.cafe":
            return AtmosphereGlowPalette(
                accent: Color(red: 0.90, green: 0.70, blue: 0.40),
                glow: Color(red: 0.70, green: 0.50, blue: 0.30)
            )
        default:
            return AtmosphereGlowPalette(
                accent: Color.white,
                glow: Color.gray
            )
        }
    }
}
