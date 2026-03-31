import SwiftUI

struct NeonEggEvolutionView: View {
    let completedSessions: Int
    let timerIsRunning: Bool
    let sessionCompleted: Bool
    let isBreak: Bool
    let size: CGFloat

    @AppStorage("activeThemeId", store: SharedStore.defaults) private var activeThemeId = "theme.zen"

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
        if isBreak { return AppTheme.accentBreak }
        switch activeThemeId {
        case "theme.neon":
            switch stage {
            case 4: return Color(red: 0.96, green: 0.40, blue: 0.88)
            case 3: return Color(red: 0.58, green: 0.96, blue: 1.00)
            case 2: return Color(red: 0.18, green: 0.88, blue: 0.98)
            case 1: return Color(red: 0.12, green: 0.66, blue: 0.92)
            default: return Color(red: 0.10, green: 0.34, blue: 0.56)
            }
        case "theme.campfire":
            switch stage {
            case 4: return Color(red: 1.00, green: 0.70, blue: 0.34)
            case 3: return Color(red: 0.99, green: 0.53, blue: 0.18)
            case 2: return Color(red: 0.96, green: 0.34, blue: 0.12)
            case 1: return Color(red: 0.76, green: 0.23, blue: 0.10)
            default: return Color(red: 0.38, green: 0.15, blue: 0.08)
            }
        case "theme.void":
            switch stage {
            case 4: return Color(red: 0.96, green: 0.98, blue: 1.00)
            case 3: return Color(red: 0.84, green: 0.88, blue: 0.95)
            case 2: return Color(red: 0.68, green: 0.73, blue: 0.84)
            case 1: return Color(red: 0.48, green: 0.54, blue: 0.66)
            default: return Color(red: 0.26, green: 0.29, blue: 0.36)
            }
        case "theme.cafe":
            switch stage {
            case 4: return Color(red: 0.97, green: 0.82, blue: 0.56)
            case 3: return Color(red: 0.88, green: 0.66, blue: 0.42)
            case 2: return Color(red: 0.70, green: 0.48, blue: 0.30)
            case 1: return Color(red: 0.50, green: 0.34, blue: 0.22)
            default: return Color(red: 0.28, green: 0.20, blue: 0.15)
            }
        case "theme.zen":
            fallthrough
        default:
            switch stage {
            case 4: return Color(red: 0.82, green: 1.00, blue: 0.84)
            case 3: return Color(red: 0.56, green: 0.98, blue: 0.70)
            case 2: return Color(red: 0.34, green: 0.88, blue: 0.56)
            case 1: return AppTheme.accent
            default: return Color(red: 0.18, green: 0.36, blue: 0.28)
            }
        }
    }

    private var stageIcon: String {
        if isBreak { return "cup.and.saucer.fill" }
        switch activeThemeId {
        case "theme.campfire":
            switch stage {
            case 4: return "flame.fill"
            case 3: return "fireplace.fill"
            case 2: return "bonfire.fill"
            case 1: return "flame.circle.fill"
            default: return "circle.hexagongrid.fill"
            }
        case "theme.void":
            switch stage {
            case 4: return "moonphase.full.moon.inverse"
            case 3: return "sparkles"
            case 2: return "moon.stars.fill"
            case 1: return "circle.hexagonpath.fill"
            default: return "circle.dashed"
            }
        case "theme.cafe":
            switch stage {
            case 4: return "cup.and.saucer.fill"
            case 3: return "mug.fill"
            case 2: return "takeoutbag.and.cup.and.straw.fill"
            case 1: return "cup.and.heat.waves.fill"
            default: return "circle.bottomhalf.filled.inverse"
            }
        case "theme.neon":
            switch stage {
            case 4: return "sparkles.tv.fill"
            case 3: return "bolt.fill"
            case 2: return "cpu"
            case 1: return "antenna.radiowaves.left.and.right"
            default: return "atom"
            }
        case "theme.zen":
            fallthrough
        default:
            switch stage {
            case 4: return "sun.max.fill"
            case 3: return "tree.fill"
            case 2: return "leaf.fill"
            case 1: return "leaf.circle.fill"
            default: return "seedling.fill"
            }
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
                    .fill(bright ? AppTheme.textPrimary.opacity(0.90) : stageColor.opacity(0.78))
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
                        colors: [AppTheme.textPrimary, stageColor.opacity(0.85)],
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
