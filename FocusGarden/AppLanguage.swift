import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish  = "tr"
    case english  = "en"
    case chinese  = "zh-Hans"

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:  return nil
        case .turkish: return "tr"
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }

    var bundleLanguageCode: String? { localeIdentifier }

    var labelKey: String {
        switch self {
        case .system:  return "settings.language.system"
        case .turkish: return "settings.language.turkish"
        case .english: return "settings.language.english"
        case .chinese: return "settings.language.chinese"
        }
    }
}

func activeLocalizationBundle() -> Bundle {
    let stored = SharedStore.defaults?.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
    let lang   = AppLanguage(rawValue: stored) ?? .system
    guard let code = lang.bundleLanguageCode,
          let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return .main }
    return bundle
}

func activeAppLocale() -> Locale {
    let stored = SharedStore.defaults?.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
    let lang = AppLanguage(rawValue: stored) ?? .system
    if let localeIdentifier = lang.localeIdentifier {
        return Locale(identifier: localeIdentifier)
    }
    return .autoupdatingCurrent
}

func localized(_ key: String) -> String {
    activeLocalizationBundle().localizedString(forKey: key, value: nil, table: nil)
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    let fmt = activeLocalizationBundle().localizedString(forKey: key, value: nil, table: nil)
    return String(format: fmt, locale: activeAppLocale(), arguments: arguments)
}
