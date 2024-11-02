
//  Views/DecisionBadge.swift
import SwiftUI

struct DecisionBadge: View {
    let decision: StockAnalysis.Decision
    
    var body: some View {
        Text(decision.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(decisionColor)
            )
            .foregroundColor(.white)
    }
    
    private var decisionColor: Color {
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

