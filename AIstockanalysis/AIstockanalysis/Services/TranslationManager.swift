
// Services/TranslationManager.swift
import Foundation

import Foundation

@available(iOS 14.0, *)
class TranslationManager {
   static let shared = TranslationManager()
   private var translationCache: [String: String] = [:]
   private let apiKey = APIConfig.azureTranslatorKey
   private let region = "eastus"  // Azure 리전
   private let endpoint = "https://api.cognitive.microsofttranslator.com"
   
   // 비용 추적을 위한 구조체
   struct TranslationUsage {
       var characterCount: Int = 0
       var cost: Double = 0.0  // $10 per 1M characters
       
       var description: String {
           return String(format: "Translation Usage - Characters: %d, Cost: $%.4f",
                        characterCount, cost)
       }
   }
   
   @Published private(set) var currentUsage = TranslationUsage()
   
   private init() {}

   // API 에러 응답을 위한 구조체 추가
   struct AzureErrorResponse: Codable {
       let error: AzureError
       
       struct AzureError: Codable {
           let code: Int
           let message: String
       }
   }
   
   func translate(_ text: String, from sourceLanguage: String = "en", to targetLanguage: String) async throws -> String {
       // 같은 언어면 번역하지 않음
       if sourceLanguage == targetLanguage {
           return text
       }
       
       // 캐시 확인
       let cacheKey = "\(text)_\(sourceLanguage)_\(targetLanguage)"
       if let cachedTranslation = translationCache[cacheKey] {
           return cachedTranslation
       }
       
       // API 엔드포인트 구성
       let path = "/translate"
       let params = "api-version=3.0&from=\(sourceLanguage)&to=\(targetLanguage)"
       let constructedUrl = "\(endpoint)\(path)?\(params)"
       
       guard let url = URL(string: constructedUrl) else {
           throw TranslationError.invalidURL
       }
       
       // 요청 생성
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
       request.addValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
       if !region.isEmpty {
           request.addValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
       }
       request.addValue("application/json", forHTTPHeaderField: "Content-Type")
       
       let body = [["text": text]]
       request.httpBody = try JSONSerialization.data(withJSONObject: body)
       
       // API 호출 및 응답 처리
       let (data, response) = try await URLSession.shared.data(for: request)
       
       // 받은 JSON 데이터 출력
       if let jsonString = String(data: data, encoding: .utf8) {
           print("Received JSON response: \(jsonString)")
       }
       
       // HTTP 응답 코드 확인
       if let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode != 200 {
           // 에러 응답 파싱 시도
           if let errorResponse = try? JSONDecoder().decode(AzureErrorResponse.self, from: data) {
               throw TranslationError.azureError(
                   code: errorResponse.error.code,
                   message: errorResponse.error.message
               )
           }
           throw TranslationError.httpError(httpResponse.statusCode)
       }
       
       do {
           struct TranslationResponse: Codable {
               struct Translation: Codable {
                   let text: String
                   let to: String
               }
               let translations: [Translation]
           }
           
           let responses = try JSONDecoder().decode([TranslationResponse].self, from: data)
           
           guard let translatedText = responses.first?.translations.first?.text else {
               throw TranslationError.noTranslation
           }
           
           // 사용량 및 비용 계산
           let charCount = text.count
           currentUsage.characterCount += charCount
           currentUsage.cost += Double(charCount) * (10.0 / 1_000_000.0)
           
           print("💰 Azure Translator Usage: \(currentUsage.description)")
           
           // 캐시에 저장
           translationCache[cacheKey] = translatedText
           return translatedText
           
       } catch {
           print("Translation error: \(error)")
           print("Raw JSON response: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
           throw TranslationError.translationFailed(error)
       }
   }
   
   // 여러 텍스트 일괄 번역
   func batchTranslate(_ texts: [String], from sourceLanguage: String = "en", to targetLanguage: String) async throws -> [String] {
       return try await withThrowingTaskGroup(of: (Int, String).self) { group in
           for (index, text) in texts.enumerated() {
               group.addTask {
                   let translation = try await self.translate(text, from: sourceLanguage, to: targetLanguage)
                   return (index, translation)
               }
           }
           
           var results = [(Int, String)]()
           for try await result in group {
               results.append(result)
           }
           
           return results.sorted { $0.0 < $1.0 }.map { $0.1 }
       }
   }
   
   func clearCache() {
       translationCache.removeAll()
   }
   
   // 현재 세션의 총 사용량 조회
   func getCurrentSessionUsage() -> String {
       return currentUsage.description
   }
   
   enum TranslationError: Error, LocalizedError {
       case invalidURL
       case translationFailed(Error)
       case unsupportedLanguage
       case noTranslation
       case httpError(Int)
       case azureError(code: Int, message: String)
       
       var errorDescription: String? {
           switch self {
           case .invalidURL:
               return "Invalid URL for translation service"
           case .translationFailed(let error):
               return "Translation failed: \(error.localizedDescription)"
           case .unsupportedLanguage:
               return "One or both languages are not supported"
           case .noTranslation:
               return "No translation result available"
           case .httpError(let code):
               return "HTTP error: \(code)"
           case .azureError(let code, let message):
               return "Azure error (\(code)): \(message)"
           }
       }
   }
}
