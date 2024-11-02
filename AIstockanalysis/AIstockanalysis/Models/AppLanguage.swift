
// Models/AppLanguage.swift
import Foundation

struct AppLanguage: Identifiable, Hashable, Codable {
    private enum CodingKeys: String, CodingKey {
        case name, code, locale
    }
    
    let id = UUID()
    let name: String
    let code: String
    let locale: String
    
    static let allLanguages: [AppLanguage] = [
        AppLanguage(name: "Afrikaans", code: "af", locale: "af"),        // 아프리칸스어는 영어로 표기
        AppLanguage(name: "Shqip", code: "sq", locale: "sq"),            // Albanian
        AppLanguage(name: "አማርኛ", code: "am", locale: "am"),            // Amharic
        AppLanguage(name: "العربية", code: "ar", locale: "ar"),          // Arabic
        AppLanguage(name: "Հայերեն", code: "hy", locale: "hy"),         // Armenian
        AppLanguage(name: "অসমীয়া", code: "as", locale: "as"),          // Assamese
        AppLanguage(name: "Azərbaycan", code: "az", locale: "az"),       // Azerbaijani
        AppLanguage(name: "বাংলা", code: "bn", locale: "bn"),            // Bengali
        AppLanguage(name: "Bosanski", code: "bs", locale: "bs"),         // Bosnian
        AppLanguage(name: "Български", code: "bg", locale: "bg"),        // Bulgarian
        AppLanguage(name: "中文", code: "zh-Hans", locale: "zh"),        // Chinese (Simplified)
        AppLanguage(name: "中文繁體", code: "zh-Hant", locale: "zh-TW"), // Chinese (Traditional)
        AppLanguage(name: "Hrvatski", code: "hr", locale: "hr"),         // Croatian
        AppLanguage(name: "Čeština", code: "cs", locale: "cs"),          // Czech
        AppLanguage(name: "Dansk", code: "da", locale: "da"),            // Danish
        AppLanguage(name: "دری", code: "prs", locale: "prs"),           // Dari
        AppLanguage(name: "Nederlands", code: "nl", locale: "nl"),       // Dutch
        AppLanguage(name: "English", code: "en", locale: "en"),          // English
        AppLanguage(name: "Eesti", code: "et", locale: "et"),            // Estonian
        AppLanguage(name: "Suomi", code: "fi", locale: "fi"),            // Finnish
        AppLanguage(name: "Français", code: "fr", locale: "fr"),         // French
        AppLanguage(name: "ქართული", code: "ka", locale: "ka"),         // Georgian
        AppLanguage(name: "Deutsch", code: "de", locale: "de"),          // German
        AppLanguage(name: "Ελληνικά", code: "el", locale: "el"),        // Greek
        AppLanguage(name: "ગુજરાતી", code: "gu", locale: "gu"),         // Gujarati
        AppLanguage(name: "Kreyòl Ayisyen", code: "ht", locale: "ht"),  // Haitian Creole
        AppLanguage(name: "עברית", code: "he", locale: "he"),           // Hebrew
        AppLanguage(name: "हिंदी", code: "hi", locale: "hi"),            // Hindi
        AppLanguage(name: "Magyar", code: "hu", locale: "hu"),           // Hungarian
        AppLanguage(name: "Íslenska", code: "is", locale: "is"),         // Icelandic
        AppLanguage(name: "Bahasa Indonesia", code: "id", locale: "id"), // Indonesian
        AppLanguage(name: "Gaeilge", code: "ga", locale: "ga"),         // Irish
        AppLanguage(name: "Italiano", code: "it", locale: "it"),         // Italian
        AppLanguage(name: "日本語", code: "ja", locale: "ja"),           // Japanese
        AppLanguage(name: "ಕನ್ನಡ", code: "kn", locale: "kn"),           // Kannada
        AppLanguage(name: "Қазақ", code: "kk", locale: "kk"),           // Kazakh
        AppLanguage(name: "한국어", code: "ko", locale: "ko"),           // Korean
        AppLanguage(name: "Latviešu", code: "lv", locale: "lv"),        // Latvian
        AppLanguage(name: "Lietuvių", code: "lt", locale: "lt"),        // Lithuanian
        AppLanguage(name: "Bahasa Melayu", code: "ms", locale: "ms"),   // Malay
        AppLanguage(name: "മലയാളം", code: "ml", locale: "ml"),          // Malayalam
        AppLanguage(name: "Malti", code: "mt", locale: "mt"),           // Maltese
        AppLanguage(name: "मराठी", code: "mr", locale: "mr"),           // Marathi
        AppLanguage(name: "Norsk", code: "nb", locale: "nb"),           // Norwegian
        AppLanguage(name: "فارسی", code: "fa", locale: "fa"),           // Persian
        AppLanguage(name: "Polski", code: "pl", locale: "pl"),          // Polish
        AppLanguage(name: "Português", code: "pt", locale: "pt"),       // Portuguese
        AppLanguage(name: "Română", code: "ro", locale: "ro"),          // Romanian
        AppLanguage(name: "Русский", code: "ru", locale: "ru"),         // Russian
        AppLanguage(name: "Српски", code: "sr", locale: "sr"),          // Serbian
        AppLanguage(name: "Slovenčina", code: "sk", locale: "sk"),      // Slovak
        AppLanguage(name: "Slovenščina", code: "sl", locale: "sl"),     // Slovenian
        AppLanguage(name: "Español", code: "es", locale: "es"),         // Spanish
        AppLanguage(name: "Kiswahili", code: "sw", locale: "sw"),       // Swahili
        AppLanguage(name: "Svenska", code: "sv", locale: "sv"),         // Swedish
        AppLanguage(name: "தமிழ்", code: "ta", locale: "ta"),           // Tamil
        AppLanguage(name: "తెలుగు", code: "te", locale: "te"),          // Telugu
        AppLanguage(name: "ไทย", code: "th", locale: "th"),             // Thai
        AppLanguage(name: "Türkçe", code: "tr", locale: "tr"),         // Turkish
        AppLanguage(name: "Українська", code: "uk", locale: "uk"),      // Ukrainian
        AppLanguage(name: "اردو", code: "ur", locale: "ur"),            // Urdu
        AppLanguage(name: "Tiếng Việt", code: "vi", locale: "vi"),     // Vietnamese
        AppLanguage(name: "Cymraeg", code: "cy", locale: "cy")         // Welsh
    ]
    
    // 기본 언어를 반환하는 정적 프로퍼티
    static var `default`: AppLanguage {
        allLanguages.first { $0.code == "en" } ?? allLanguages[0]
    }
    
    // 언어 코드로 AppLanguage를 찾는 메서드
    static func language(for code: String) -> AppLanguage {
        allLanguages.first { $0.code == code } ?? .default
    }
    
    // 로케일 문자열로 AppLanguage를 찾는 메서드
    static func language(forLocale locale: String) -> AppLanguage {
        allLanguages.first { $0.locale == locale } ?? .default
    }
    
    // 시스템 언어에 해당하는 AppLanguage를 반환하는 메서드
    static var systemLanguage: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages[0]
        
        if #available(iOS 16, *) {
            let locale = Locale(identifier: preferredLanguage)
            let languageCode = locale.language.languageCode?.identifier ?? "en"
            return language(for: languageCode)
        } else {
            let locale = Locale(identifier: preferredLanguage)
            let languageCode = locale.languageCode ?? "en"
            return language(for: languageCode)
        }
    }
    
    // RTL(Right-to-Left) 언어인지 확인하는 프로퍼티
    var isRTL: Bool {
        let rtlLanguages = ["ar", "fa", "he", "ur"]
        return rtlLanguages.contains(code)
    }
    
    // 언어 표시 이름을 현재 선택된 언어로 가져오는 메서드
    func localizedName(in targetLanguage: AppLanguage) -> String {
        if #available(iOS 16, *) {
            let locale = Locale(identifier: targetLanguage.locale)
            return locale.language.languageCode?.identifier ?? name
        } else {
            let locale = Locale(identifier: targetLanguage.locale)
            return locale.localizedString(forLanguageCode: code) ?? name
        }
    }
    
    // 필요한 경우 커스텀 인코딩/디코딩 구현
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        code = try container.decode(String.self, forKey: .code)
        locale = try container.decode(String.self, forKey: .locale)
    }
    
    init(name: String, code: String, locale: String) {
        self.name = name
        self.code = code
        self.locale = locale
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(locale, forKey: .locale)
    }
}

// 파일의 최상위 레벨에 extension 선언
extension Array where Element == AppLanguage {
    func sortedByName() -> [AppLanguage] {
        self.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    func sortedByPopularity() -> [AppLanguage] {
            let popularCodes = ["en", "es", "zh", "ar", "fr", "ru", "pt", "ja", "de"]
            return self.sorted { first, second in
                let firstIndex = popularCodes.firstIndex(of: first.code) ?? Int.max
                let secondIndex = popularCodes.firstIndex(of: second.code) ?? Int.max
                return firstIndex < secondIndex
            }
        }
}
