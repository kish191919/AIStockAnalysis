// Services/OpenAIService.swift
import Foundation
import Combine
import SwiftUI

class OpenAIService: ObservableObject {
    private let apiKey: String
    
    // GPT-4 Turbo 가격 상수 (1K 토큰당 가격, 2024년 기준)
    private let gpt4TurboInputPrice = 0.01  // $0.01 per 1K tokens
    private let gpt4TurboOutputPrice = 0.03 // $0.03 per 1K tokens
    
    // 누적 사용량 추적을 위한 구조체
    private struct CumulativeUsage {
        var totalPromptTokens: Int = 0
        var totalCompletionTokens: Int = 0
        var totalCost: Double = 0
        
        mutating func add(cost: OpenAICost) {
            totalPromptTokens += cost.promptTokens
            totalCompletionTokens += cost.completionTokens
            totalCost += cost.cost
        }
        
        var description: String {
            return String(format: """
                Total Usage:
                - Prompt Tokens: %d
                - Completion Tokens: %d
                - Total Cost: $%.4f
                """,
                totalPromptTokens,
                totalCompletionTokens,
                totalCost
            )
        }
    }
    
    // 저장 프로퍼티들
    @Published private(set) var lastUsage: OpenAICost?
    private var cumulativeUsage = CumulativeUsage()
    
    init() {
        self.apiKey = APIConfig.openAIAPIKey
    }
    
    // 비용 계산 메서드
    private func calculateCost(usage: OpenAIResponse.Usage) -> OpenAICost {
        let promptCost = Double(usage.promptTokens) * gpt4TurboInputPrice / 1000.0
        let completionCost = Double(usage.completionTokens) * gpt4TurboOutputPrice / 1000.0
        let totalCost = promptCost + completionCost
        
        return OpenAICost(
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens,
            totalTokens: usage.totalTokens,
            cost: totalCost
        )
    }
    
    // 누적 사용량 업데이트
    private func updateCumulativeUsage(cost: OpenAICost) {
        cumulativeUsage.add(cost: cost)
    }
    
    // 현재 세션의 총 사용량 조회
    func getCurrentSessionUsage() -> String {
        return cumulativeUsage.description
    }
    
    // 주식 분석
    func analyzeStock(jsonData: String, targetLanguage: String) async throws -> StockAnalysis {
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
            Based on this stock data: \(jsonData)
            Analyze the data and provide your response in \(targetLanguage) language.
            Use the following JSON format:
            {
                "decision": "BULLISH/BEARISH/NEUTRAL",
                "percentage": <number between 1-100>,
                "reason": "<your analysis in \(targetLanguage)>",
                "expected_next_day_price": "<predicted price as string with 2 decimal places>"
            }
            """
        
        let payload: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": """
                You are a stock investment expert who can analyze market data and provide responses in multiple languages. 
                You explain market concepts in simple terms for beginners in their preferred language.
                Your analysis should include:
                1. Clear BULLISH, BEARISH, or NEUTRAL recommendation
                2. Confidence percentage (1-100)
                3. Detailed reasoning in the specified language
                4. Expected next day's closing price
                Focus on providing clear, actionable insights while maintaining accuracy.
                """],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        print("📤 Sending payload to OpenAI")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            print("❌ OpenAI API Error Response: \(String(data: data, encoding: .utf8) ?? "No error data")")
            throw OpenAIError.apiError(message: errorResponse?.error.message ?? "Unknown error")
        }
        
        print("📥 Received response from OpenAI")
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        // 사용량 및 비용 계산
        if let usage = openAIResponse.usage {
            let cost = calculateCost(usage: usage)
            lastUsage = cost
            updateCumulativeUsage(cost: cost)
            print("💰 OpenAI Analysis Usage: \(cost.description)")
        }
        
        guard let jsonString = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noResponseContent
        }
        
        print("📝 OpenAI Response Content: \(jsonString)")
        
        do {
            let analysisData = Data(jsonString.utf8)
            let analysis = try JSONDecoder().decode(StockAnalysis.self, from: analysisData)
            return analysis
        } catch {
            print("❌ JSON Decoding error: \(error)")
            throw error
        }
    }
}
