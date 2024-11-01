
//  Views/DecisionBadge.swift
import SwiftUI

struct DecisionBadge: View {
    let decision: StockAnalysis.Decision
    
    var body: some View {
        Text(decision.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch decision {
        case .bullish:
            return .green
        case .bearish:
            return .red
        case .neutral:
            return .orange
        }
    }
}

