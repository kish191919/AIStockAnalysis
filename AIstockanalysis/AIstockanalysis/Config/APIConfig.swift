// Config/APIConfig.swift
import Foundation

struct APIConfig {
    static var finnhubApiKey: String {
        guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let apiKey = dict["FINNHUB_API_KEY"] as? String else {
            fatalError("Couldn't find 'APIKeys.plist' or 'FINNHUB_API_KEY' in it.")
        }
        return apiKey
    }
}
