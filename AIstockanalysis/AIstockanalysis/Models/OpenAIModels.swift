// Models/OpenAIModels.swift
import Foundation

// OpenAI 응답을 위한 모델
struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
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
}
