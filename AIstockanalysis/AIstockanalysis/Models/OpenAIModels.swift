// Models/OpenAIModels.swift
import Foundation
import SwiftUI

// OpenAI 응답을 위한 모델
struct OpenAIResponse: Codable {
    let choices: [Choice]
    let usage: Usage?  // 사용량 정보 추가
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// OpenAI 비용 계산을 위한 구조체
struct OpenAICost {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let cost: Double
    
    var description: String {
        return String(format: "Tokens - Prompt: %d, Completion: %d, Total: %d, Cost: $%.4f",
                     promptTokens, completionTokens, totalTokens, cost)
    }
}



// OpenAI 에러 응답 모델
struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
    
    struct OpenAIErrorDetail: Codable {
        let message: String
        let type: String
    }
}

// 커스텀 에러 타입
enum OpenAIError: LocalizedError {
    case apiError(message: String)
    case noResponseContent
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "OpenAI API Error: \(message)"
        case .noResponseContent:
            return "No content in OpenAI response"
        }
    }
}

// 주식 분석 결과 모델
struct StockAnalysis: Codable {
    let decision: Decision
    let percentage: Int
    let reason: String
    let expectedNextDayPrice: Double
    
    enum Decision: String, Codable {
        case bullish = "BULLISH"
        case bearish = "BEARISH"
        case neutral = "NEUTRAL"
    }
    
    enum CodingKeys: String, CodingKey {
        case decision
        case percentage
        case reason
        case expectedNextDayPrice = "expected_next_day_price"
    }
    
    init(decision: Decision, percentage: Int, reason: String, expectedNextDayPrice: Double) {
        self.decision = decision
        self.percentage = percentage
        self.reason = reason
        self.expectedNextDayPrice = expectedNextDayPrice
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        decision = try container.decode(Decision.self, forKey: .decision)
        percentage = try container.decode(Int.self, forKey: .percentage)
        reason = try container.decode(String.self, forKey: .reason)
        
        // expectedNextDayPrice를 문자열 또는 Double로 처리
        if let priceString = try? container.decode(String.self, forKey: .expectedNextDayPrice),
           let price = Double(priceString) {
            expectedNextDayPrice = price
        } else {
            expectedNextDayPrice = try container.decode(Double.self, forKey: .expectedNextDayPrice)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decision, forKey: .decision)
        try container.encode(percentage, forKey: .percentage)
        try container.encode(reason, forKey: .reason)
        try container.encode(String(format: "%.2f", expectedNextDayPrice), forKey: .expectedNextDayPrice)
    }
}

// MARK: - Utility Extensions
extension StockAnalysis {
    var formattedExpectedPrice: String {
        return String(format: "$%.2f", expectedNextDayPrice)
    }
    
    var decisionColor: Color {
        switch decision {
        case .bullish: return .green
        case .bearish: return .red
        case .neutral: return .orange
        }
    }
}

// MARK: - Preview Helper
extension StockAnalysis {
    static var preview: StockAnalysis {
        StockAnalysis(
            decision: .bullish,
            percentage: 75,
            reason: "Strong market sentiment and positive technical indicators",
            expectedNextDayPrice: 150.00
        )
    }
}
