import Foundation

/// The app's languages. Strings are keyed by their English text in
/// `Resources/Localizations/<code>.lproj/Localizable.strings` (English needs no table).
/// `.system` follows macOS: the language set for Cameo in System Settings › Language & Region ›
/// Applications, else the system list. A choice is stored as the standard `AppleLanguages`
/// default in Cameo's own domain, the key System Settings writes, so the two agree and AppKit's
/// own strings (About panel, open panel) follow it from the next launch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt-BR"
    case russian = "ru"
    case italian = "it"

    var id: String { rawValue }

    /// Each language names itself; only "System" is translated.
    var label: String {
        switch self {
        case .system: L("System")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português (Brasil)"
        case .russian: "Русский"
        case .italian: "Italiano"
        }
    }

    /// The choice stored in Cameo's own domain (not inherited from the global one).
    static var stored: AppLanguage {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName)
        guard let first = (domain?["AppleLanguages"] as? [String])?.first else { return .system }
        return AppLanguage(rawValue: first) ?? .system
    }

    /// Stores the choice and switches the app's strings to it.
    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
        strings = Self.table()
    }

    /// The strings table for the best match between the app's languages and `AppleLanguages`
    /// (Cameo's own choice if it has one, else the system list); nil for English.
    fileprivate static func table() -> Bundle? {
        let available = ["en"] + allCases.map(\.rawValue).filter { $0 != "system" && $0 != "en" }
        let preferred = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        guard let code = Bundle.preferredLocalizations(from: available, forPreferences: preferred).first,
              code != "en",
              let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}

nonisolated(unsafe) private var strings = AppLanguage.table()

/// A user-facing string, by its English text, in the current language.
func L(_ english: String) -> String {
    strings?.localizedString(forKey: english, value: english, table: nil) ?? english
}

/// A user-facing format string (`%@` placeholders), by its English text, in the current language.
func L(_ english: String, _ arguments: CVarArg...) -> String {
    String(format: L(english), arguments: arguments)
}
