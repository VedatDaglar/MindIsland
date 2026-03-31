import SwiftUI
import UIKit

extension Color {
    init(light: Color, dark: Color) {
        self.init(
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }
}

enum AppTheme {
    static var accent: Color { palette.accent }
    static var accentBright: Color { palette.accentBright }
    static var accentBreak: Color { palette.accentBreak }
    static var accentBreakBright: Color { palette.accentBreakBright }
    static var backgroundTop: Color { palette.backgroundTop }
    static var backgroundBottom: Color { palette.backgroundBottom }
    static var card: Color { palette.card }
    static var cardSoft: Color { palette.cardSoft }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var border: Color { palette.border }
    static var backgroundMid: Color { palette.backgroundMid }
    static var glowSecondary: Color { palette.glowSecondary }
    static var tabBarBackground: Color { palette.tabBarBackground }

    private struct Palette {
        let accent: Color
        let accentBright: Color
        let accentBreak: Color
        let accentBreakBright: Color
        let backgroundTop: Color
        let backgroundBottom: Color
        let card: Color
        let cardSoft: Color
        let textPrimary: Color
        let textSecondary: Color
        let border: Color
        let backgroundMid: Color
        let glowSecondary: Color
        let tabBarBackground: Color
    }

    static var isDarkMode: Bool {
        let stored = UserDefaults(suiteName: SharedStore.suiteName)?.string(forKey: "appearanceMode") ?? "dark"
        return stored == "dark"
    }

    private static var activeThemeId: String {
        UserDefaults(suiteName: SharedStore.suiteName)?.string(forKey: "activeThemeId") ?? "theme.zen"
    }

    private static var palette: Palette {
        if isDarkMode {
            return darkPalette
        } else {
            return lightPalette
        }
    }

    // MARK: - Dark Mode Palettes (RGB Neon Glow Ambiance)
    private static var darkPalette: Palette {
        switch activeThemeId {
        case "theme.neon":
            return Palette(
                accent: Color(red: 0.00, green: 0.85, blue: 0.98),
                accentBright: Color(red: 0.40, green: 0.95, blue: 1.00),
                accentBreak: Color(red: 0.95, green: 0.15, blue: 0.70),
                accentBreakBright: Color(red: 1.00, green: 0.45, blue: 0.85),
                backgroundTop: Color(red: 0.03, green: 0.03, blue: 0.06),
                backgroundBottom: Color(red: 0.05, green: 0.04, blue: 0.10),
                card: Color(red: 0.08, green: 0.08, blue: 0.14),
                cardSoft: Color(red: 0.12, green: 0.11, blue: 0.20),
                textPrimary: Color(red: 0.95, green: 0.97, blue: 1.00),
                textSecondary: Color(red: 0.60, green: 0.65, blue: 0.78),
                border: Color(red: 0.00, green: 0.85, blue: 0.98).opacity(0.18),
                backgroundMid: Color(red: 0.04, green: 0.04, blue: 0.12),
                glowSecondary: Color(red: 0.50, green: 0.20, blue: 0.90),
                tabBarBackground: Color(red: 0.05, green: 0.05, blue: 0.10)
            )

        case "theme.campfire":
            return Palette(
                accent: Color(red: 1.00, green: 0.45, blue: 0.08),
                accentBright: Color(red: 1.00, green: 0.70, blue: 0.28),
                accentBreak: Color(red: 0.92, green: 0.22, blue: 0.10),
                accentBreakBright: Color(red: 1.00, green: 0.50, blue: 0.22),
                backgroundTop: Color(red: 0.06, green: 0.03, blue: 0.02),
                backgroundBottom: Color(red: 0.10, green: 0.05, blue: 0.03),
                card: Color(red: 0.13, green: 0.08, blue: 0.05),
                cardSoft: Color(red: 0.18, green: 0.11, blue: 0.07),
                textPrimary: Color(red: 1.00, green: 0.96, blue: 0.90),
                textSecondary: Color(red: 0.82, green: 0.68, blue: 0.52),
                border: Color(red: 1.00, green: 0.45, blue: 0.08).opacity(0.16),
                backgroundMid: Color(red: 0.10, green: 0.06, blue: 0.03),
                glowSecondary: Color(red: 0.70, green: 0.30, blue: 0.10),
                tabBarBackground: Color(red: 0.08, green: 0.04, blue: 0.02)
            )

        case "theme.void":
            return Palette(
                accent: Color(red: 0.78, green: 0.82, blue: 0.95),
                accentBright: Color(red: 0.92, green: 0.94, blue: 1.00),
                accentBreak: Color(red: 0.55, green: 0.58, blue: 0.72),
                accentBreakBright: Color(red: 0.75, green: 0.78, blue: 0.90),
                backgroundTop: Color(red: 0.02, green: 0.02, blue: 0.03),
                backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.02),
                card: Color(red: 0.07, green: 0.07, blue: 0.09),
                cardSoft: Color(red: 0.10, green: 0.10, blue: 0.13),
                textPrimary: Color.white,
                textSecondary: Color(red: 0.58, green: 0.60, blue: 0.68),
                border: Color.white.opacity(0.08),
                backgroundMid: Color(red: 0.03, green: 0.03, blue: 0.04),
                glowSecondary: Color(red: 0.40, green: 0.42, blue: 0.60),
                tabBarBackground: Color(red: 0.03, green: 0.03, blue: 0.05)
            )

        case "theme.cafe":
            return Palette(
                accent: Color(red: 0.92, green: 0.68, blue: 0.35),
                accentBright: Color(red: 1.00, green: 0.82, blue: 0.52),
                accentBreak: Color(red: 0.70, green: 0.42, blue: 0.20),
                accentBreakBright: Color(red: 0.88, green: 0.60, blue: 0.30),
                backgroundTop: Color(red: 0.07, green: 0.05, blue: 0.04),
                backgroundBottom: Color(red: 0.11, green: 0.08, blue: 0.06),
                card: Color(red: 0.14, green: 0.10, blue: 0.08),
                cardSoft: Color(red: 0.19, green: 0.14, blue: 0.10),
                textPrimary: Color(red: 1.00, green: 0.97, blue: 0.92),
                textSecondary: Color(red: 0.78, green: 0.68, blue: 0.56),
                border: Color(red: 0.92, green: 0.68, blue: 0.35).opacity(0.14),
                backgroundMid: Color(red: 0.10, green: 0.07, blue: 0.05),
                glowSecondary: Color(red: 0.60, green: 0.42, blue: 0.22),
                tabBarBackground: Color(red: 0.08, green: 0.06, blue: 0.04)
            )

        default: // theme.zen — RGB: Emerald Green + Cyan + Soft Magenta
            return Palette(
                accent: Color(red: 0.15, green: 0.95, blue: 0.55),
                accentBright: Color(red: 0.40, green: 1.00, blue: 0.75),
                accentBreak: Color(red: 0.95, green: 0.55, blue: 0.20),
                accentBreakBright: Color(red: 1.00, green: 0.75, blue: 0.38),
                backgroundTop: Color(red: 0.02, green: 0.03, blue: 0.05),
                backgroundBottom: Color(red: 0.04, green: 0.06, blue: 0.08),
                card: Color(red: 0.06, green: 0.08, blue: 0.12),
                cardSoft: Color(red: 0.09, green: 0.12, blue: 0.16),
                textPrimary: Color(red: 0.95, green: 0.98, blue: 1.00),
                textSecondary: Color(red: 0.55, green: 0.68, blue: 0.72),
                border: Color(red: 0.15, green: 0.95, blue: 0.55).opacity(0.16),
                backgroundMid: Color(red: 0.03, green: 0.05, blue: 0.08),
                glowSecondary: Color(red: 0.00, green: 0.75, blue: 0.85),
                tabBarBackground: Color(red: 0.03, green: 0.04, blue: 0.06)
            )
        }
    }

    // MARK: - Light Mode Palettes (Soft RGB Pastel)
    private static var lightPalette: Palette {
        switch activeThemeId {
        case "theme.neon":
            return Palette(
                accent: Color(red: 0.00, green: 0.60, blue: 0.82),
                accentBright: Color(red: 0.20, green: 0.78, blue: 0.95),
                accentBreak: Color(red: 0.82, green: 0.18, blue: 0.60),
                accentBreakBright: Color(red: 0.95, green: 0.40, blue: 0.75),
                backgroundTop: Color(red: 0.96, green: 0.97, blue: 1.00),
                backgroundBottom: Color(red: 0.92, green: 0.95, blue: 1.00),
                card: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardSoft: Color(red: 0.94, green: 0.96, blue: 1.00),
                textPrimary: Color(red: 0.10, green: 0.12, blue: 0.18),
                textSecondary: Color(red: 0.38, green: 0.42, blue: 0.55),
                border: Color(red: 0.00, green: 0.60, blue: 0.82).opacity(0.15),
                backgroundMid: Color(red: 0.94, green: 0.96, blue: 1.00),
                glowSecondary: Color(red: 0.60, green: 0.40, blue: 0.88),
                tabBarBackground: Color(red: 0.97, green: 0.98, blue: 1.00)
            )

        case "theme.campfire":
            return Palette(
                accent: Color(red: 0.88, green: 0.40, blue: 0.10),
                accentBright: Color(red: 1.00, green: 0.60, blue: 0.25),
                accentBreak: Color(red: 0.78, green: 0.28, blue: 0.12),
                accentBreakBright: Color(red: 0.95, green: 0.48, blue: 0.22),
                backgroundTop: Color(red: 1.00, green: 0.98, blue: 0.95),
                backgroundBottom: Color(red: 0.98, green: 0.94, blue: 0.90),
                card: Color(red: 1.00, green: 1.00, blue: 0.99),
                cardSoft: Color(red: 0.98, green: 0.95, blue: 0.91),
                textPrimary: Color(red: 0.18, green: 0.12, blue: 0.08),
                textSecondary: Color(red: 0.48, green: 0.38, blue: 0.28),
                border: Color(red: 0.88, green: 0.40, blue: 0.10).opacity(0.14),
                backgroundMid: Color(red: 0.99, green: 0.96, blue: 0.92),
                glowSecondary: Color(red: 0.85, green: 0.50, blue: 0.22),
                tabBarBackground: Color(red: 1.00, green: 0.97, blue: 0.94)
            )

        case "theme.void":
            return Palette(
                accent: Color(red: 0.42, green: 0.46, blue: 0.62),
                accentBright: Color(red: 0.58, green: 0.62, blue: 0.80),
                accentBreak: Color(red: 0.38, green: 0.40, blue: 0.55),
                accentBreakBright: Color(red: 0.52, green: 0.55, blue: 0.72),
                backgroundTop: Color(red: 0.97, green: 0.97, blue: 0.98),
                backgroundBottom: Color(red: 0.94, green: 0.94, blue: 0.96),
                card: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardSoft: Color(red: 0.95, green: 0.95, blue: 0.97),
                textPrimary: Color(red: 0.12, green: 0.12, blue: 0.16),
                textSecondary: Color(red: 0.42, green: 0.44, blue: 0.52),
                border: Color.black.opacity(0.08),
                backgroundMid: Color(red: 0.96, green: 0.96, blue: 0.97),
                glowSecondary: Color(red: 0.55, green: 0.58, blue: 0.72),
                tabBarBackground: Color(red: 0.97, green: 0.97, blue: 0.98)
            )

        case "theme.cafe":
            return Palette(
                accent: Color(red: 0.72, green: 0.50, blue: 0.24),
                accentBright: Color(red: 0.88, green: 0.68, blue: 0.38),
                accentBreak: Color(red: 0.55, green: 0.35, blue: 0.18),
                accentBreakBright: Color(red: 0.72, green: 0.48, blue: 0.26),
                backgroundTop: Color(red: 1.00, green: 0.98, blue: 0.95),
                backgroundBottom: Color(red: 0.97, green: 0.94, blue: 0.90),
                card: Color(red: 1.00, green: 1.00, blue: 0.99),
                cardSoft: Color(red: 0.97, green: 0.94, blue: 0.90),
                textPrimary: Color(red: 0.18, green: 0.14, blue: 0.10),
                textSecondary: Color(red: 0.46, green: 0.38, blue: 0.30),
                border: Color(red: 0.72, green: 0.50, blue: 0.24).opacity(0.14),
                backgroundMid: Color(red: 0.98, green: 0.96, blue: 0.92),
                glowSecondary: Color(red: 0.68, green: 0.50, blue: 0.30),
                tabBarBackground: Color(red: 1.00, green: 0.97, blue: 0.94)
            )

        default: // theme.zen
            return Palette(
                accent: Color(red: 0.12, green: 0.68, blue: 0.38),
                accentBright: Color(red: 0.30, green: 0.82, blue: 0.52),
                accentBreak: Color(red: 0.82, green: 0.62, blue: 0.18),
                accentBreakBright: Color(red: 0.92, green: 0.76, blue: 0.32),
                backgroundTop: Color(red: 0.97, green: 0.99, blue: 0.97),
                backgroundBottom: Color(red: 0.93, green: 0.97, blue: 0.94),
                card: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardSoft: Color(red: 0.94, green: 0.98, blue: 0.95),
                textPrimary: Color(red: 0.10, green: 0.18, blue: 0.14),
                textSecondary: Color(red: 0.35, green: 0.48, blue: 0.40),
                border: Color(red: 0.12, green: 0.68, blue: 0.38).opacity(0.14),
                backgroundMid: Color(red: 0.95, green: 0.98, blue: 0.96),
                glowSecondary: Color(red: 0.30, green: 0.65, blue: 0.45),
                tabBarBackground: Color(red: 0.97, green: 0.99, blue: 0.97)
            )
        }
    }
}
