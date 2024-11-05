// Configuration/APIConfig.swift
import Foundation

struct APIConfig {
    static func value(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let value = config[key] as? String else {
            fatalError("Could not find key '\(key)' in Config.plist")
        }
        return value
    }
    
    static var finnhubAPIKey: String {
        return value(for: "FINNHUB_API_KEY")
    }
    
    static var openAIAPIKey: String {
        return value(for: "OPENAI_API_KEY")
    }
    
}
