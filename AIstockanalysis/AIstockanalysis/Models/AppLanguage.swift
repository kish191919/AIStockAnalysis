//
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
        AppLanguage(name: "Afrikaans", code: "af", locale: "af_ZA"),
        AppLanguage(name: "Հայերեն", code: "hy", locale: "hy_AM"),
        AppLanguage(name: "Беларуская", code: "be", locale: "be_BY"),
        AppLanguage(name: "Català", code: "ca", locale: "ca_ES"),
        AppLanguage(name: "Hrvatski", code: "hr", locale: "hr_HR"),
        AppLanguage(name: "Nederlands", code: "nl", locale: "nl_NL"),
        AppLanguage(name: "Eesti", code: "et", locale: "et_EE"),
        AppLanguage(name: "Français", code: "fr", locale: "fr_FR"),
        AppLanguage(name: "Deutsch", code: "de", locale: "de_DE"),
        AppLanguage(name: "Magyar", code: "hu", locale: "hu_HU"),
        AppLanguage(name: "日本語", code: "ja", locale: "ja_JP"),
        AppLanguage(name: "Lietuvių", code: "lt", locale: "lt_LT"),
        AppLanguage(name: "മലയാളം", code: "ml", locale: "ml_IN"),
        AppLanguage(name: "فارسی", code: "fa", locale: "fa_IR"),
        AppLanguage(name: "Română", code: "ro", locale: "ro_RO"),
        AppLanguage(name: "Slovenčina", code: "sk", locale: "sk_SK"),
        AppLanguage(name: "Kiswahili", code: "sw", locale: "sw_KE"),
        AppLanguage(name: "ไทย", code: "th", locale: "th_TH"),
        AppLanguage(name: "Tiếng Việt", code: "vi", locale: "vi_VN"),
        AppLanguage(name: "Hausa", code: "ha", locale: "ha_NG"),
        AppLanguage(name: "Kreyòl ayisyen", code: "ht", locale: "ht_HT"),
        AppLanguage(name: "Shqip", code: "sq", locale: "sq_AL"),
        AppLanguage(name: "Azərbaycanca", code: "az", locale: "az_AZ"),
        AppLanguage(name: "Български", code: "bg", locale: "bg_BG"),
        AppLanguage(name: "中文（简体）", code: "zh", locale: "zh_CN"),
        AppLanguage(name: "Čeština", code: "cs", locale: "cs_CZ"),
        AppLanguage(name: "English", code: "en", locale: "en_US"),
        AppLanguage(name: "Filipino", code: "fil", locale: "fil_PH"),
        AppLanguage(name: "Galego", code: "gl", locale: "gl_ES"),
        AppLanguage(name: "Ελληνικά", code: "el", locale: "el_GR"),
        AppLanguage(name: "Íslenska", code: "is", locale: "is_IS"),
        AppLanguage(name: "한국어", code: "ko", locale: "ko_KR"),
        AppLanguage(name: "Македонски", code: "mk", locale: "mk_MK"),
        AppLanguage(name: "Монгол", code: "mn", locale: "mn_MN"),
        AppLanguage(name: "Polski", code: "pl", locale: "pl_PL"),
        AppLanguage(name: "Русский", code: "ru", locale: "ru_RU"),
        AppLanguage(name: "Slovenščina", code: "sl", locale: "sl_SI"),
        AppLanguage(name: "Svenska", code: "sv", locale: "sv_SE"),
        AppLanguage(name: "Türkçe", code: "tr", locale: "tr_TR"),
        AppLanguage(name: "Cymraeg", code: "cy", locale: "cy_GB"),
        AppLanguage(name: "हिन्दी", code: "hi", locale: "hi_IN"),
        AppLanguage(name: "Shona", code: "sn", locale: "sn_ZW"),
        AppLanguage(name: "العربية", code: "ar", locale: "ar_SA"),
        AppLanguage(name: "Euskara", code: "eu", locale: "eu_ES"),
        AppLanguage(name: "廣東話", code: "yue", locale: "yue_HK"),
        AppLanguage(name: "中文（繁體）", code: "zh-Hant", locale: "zh_TW"),
        AppLanguage(name: "Dansk", code: "da", locale: "da_DK"),
        AppLanguage(name: "Esperanto", code: "eo", locale: "eo"),
        AppLanguage(name: "Suomi", code: "fi", locale: "fi_FI"),
        AppLanguage(name: "ქართული", code: "ka", locale: "ka_GE"),
        AppLanguage(name: "ગુજરાતી", code: "gu", locale: "gu_IN"),
        AppLanguage(name: "Italiano", code: "it", locale: "it_IT"),
        AppLanguage(name: "Latviešu", code: "lv", locale: "lv_LV"),
        AppLanguage(name: "Bahasa Melayu", code: "ms", locale: "ms_MY"),
        AppLanguage(name: "Norsk", code: "no", locale: "nb_NO"),
        AppLanguage(name: "Português", code: "pt", locale: "pt_PT"),
        AppLanguage(name: "Српски", code: "sr", locale: "sr_RS"),
        AppLanguage(name: "Español", code: "es", locale: "es_ES"),
        AppLanguage(name: "தமிழ்", code: "ta", locale: "ta_IN"),
        AppLanguage(name: "Українська", code: "uk", locale: "uk_UA"),
        AppLanguage(name: "Gaeilge", code: "ga", locale: "ga_IE"),
        AppLanguage(name: "اردو", code: "ur", locale: "ur_PK"),
        AppLanguage(name: "සිංහල", code: "si", locale: "si_LK")
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
        let popularCodes = ["en", "es", "zh", "ar", "hi", "fr", "ru", "pt", "ja", "de"]
        return self.sorted { first, second in
            let firstIndex = popularCodes.firstIndex(of: first.code) ?? Int.max
            let secondIndex = popularCodes.firstIndex(of: second.code) ?? Int.max
            return firstIndex < secondIndex
        }
    }
}
