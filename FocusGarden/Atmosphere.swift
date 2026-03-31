import Foundation

struct Atmosphere: Identifiable {
    let id: String
    let icon: String
    let requiredMinutes: Int
    let soundName: String
    let themeId: String
}

let atmospheres: [Atmosphere] = [
    Atmosphere(id: "atmosphere.zen", icon: "leaf.fill", requiredMinutes: 0, soundName: "zen_garden", themeId: "theme.zen"),
    Atmosphere(id: "atmosphere.neon", icon: "cloud.rain.fill", requiredMinutes: 250, soundName: "heavy_rain", themeId: "theme.neon"),
    Atmosphere(id: "atmosphere.campfire", icon: "flame.fill", requiredMinutes: 500, soundName: "campfire", themeId: "theme.campfire"),
    Atmosphere(id: "atmosphere.deepfocus", icon: "headphones", requiredMinutes: 1000, soundName: "brown_noise", themeId: "theme.void"),
    Atmosphere(id: "atmosphere.cafe", icon: "cup.and.saucer.fill", requiredMinutes: 1500, soundName: "cafe", themeId: "theme.cafe")
]
