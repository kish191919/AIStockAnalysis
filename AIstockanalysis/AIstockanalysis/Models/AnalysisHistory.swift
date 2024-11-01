//
//  Models/AnalysisHistory.swift

// Models/AnalysisHistory.swift
import Foundation

struct AnalysisHistory: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    let decision: StockAnalysis.Decision
    let confidence: Int
    let currentPrice: Double
    let expectedPrice: Double
    let reason: String
    let language: String  // 번역된 언어 코드
    
    init(symbol: String, analysis: StockAnalysis, currentPrice: Double, language: String) {
        self.id = UUID()
        self.symbol = symbol
        self.timestamp = Date()
        self.decision = analysis.decision
        self.confidence = analysis.percentage
        self.currentPrice = currentPrice
        self.expectedPrice = analysis.expectedNextDayPrice
        self.reason = analysis.reason
        self.language = language
    }
}

// 주식별 기록 그룹화를 위한 모델
struct StockHistoryGroup: Identifiable {
    let id: String  // 주식 심볼
    var analyses: [AnalysisHistory]
}
