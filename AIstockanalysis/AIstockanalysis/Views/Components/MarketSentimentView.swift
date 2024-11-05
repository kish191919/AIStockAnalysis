// Views/Components/MarketSentimentView.swift

import SwiftUI
import Foundation

struct MarketSentimentView: View {
    let vix: Double
    let fearAndGreedIndex: Double
    @EnvironmentObject private var viewModel: StockViewModel
    
    private let localizedTexts: [String: [String: String]] = [
        "en": [
            "marketSentiment": "Market Sentiment",
            "vixIndex": "VIX Index",
            "vixDesc": "VIX indicates market volatility and anxiety level.",
            "stable": "Stable",
            "normal": "Normal",
            "unstable": "Unstable",
            "vixBelow20": "Below 20: Market is stable",
            "vix2030": "20-30: Normal volatility",
            "vixAbove30": "Above 30: High anxiety",
            "fearGreedIndex": "Fear & Greed Index",
            "fearGreedDesc": "Shows overall investor sentiment in the market.",
            "extremeFear": "Extreme Fear",
            "fear": "Fear",
            "neutral": "Neutral",
            "greed": "Greed",
            "extremeGreed": "Extreme Greed",
            "fg025": "0-25: Extreme Fear",
            "fg2545": "26-45: Fear",
            "fg4555": "46-55: Neutral",
            "fg5575": "56-75: Greed",
            "fg75100": "76-100: Extreme Greed",
            "investmentTip": "💡 Investment Tip",
            "tipDesc": "Successful investors often 'buy when others are fearful and sell when others are greedy'. However, these indicators are just references. Investment decisions should always be based on overall market conditions and individual stock analysis."
        ],
        "ko": [
            "marketSentiment": "시장 심리",
            "vixIndex": "VIX 지수",
            "vixDesc": "VIX는 시장의 변동성과 불안 수준을 나타냅니다.",
            "stable": "안정적",
            "normal": "보통",
            "unstable": "불안정",
            "vixBelow20": "20 미만: 시장이 안정적",
            "vix2030": "20-30: 일반적인 변동성",
            "vixAbove30": "30 이상: 높은 불안감",
            "fearGreedIndex": "공포/탐욕 지수",
            "fearGreedDesc": "시장 전반의 투자자 심리를 보여줍니다.",
            "extremeFear": "극도의 공포",
            "fear": "공포",
            "neutral": "중립",
            "greed": "탐욕",
            "extremeGreed": "극도의 탐욕",
            "fg025": "0-25: 극도의 공포",
            "fg2545": "26-45: 공포",
            "fg4555": "46-55: 중립",
            "fg5575": "56-75: 탐욕",
            "fg75100": "76-100: 극도의 탐욕",
            "investmentTip": "💡 투자 팁",
            "tipDesc": "성공적인 투자자들은 '다른 사람들이 두려워할 때 매수하고 탐욕스러울 때 매도'하는 경향이 있습니다. 하지만 이러한 지표들은 단순한 참고사항일 뿐입니다. 투자 결정은 항상 전반적인 시장 상황과 개별 주식 분석을 기반으로 이루어져야 합니다."
        ],
        // 다른 언어들도 필요에 따라 추가
    ]
    
    private func getText(_ key: String) -> String {
        let languageCode = viewModel.selectedLanguage.code
        // 선택된 언어에 해당하는 번역이 있으면 사용, 없으면 영어 사용
        return localizedTexts[languageCode]?[key] ?? localizedTexts["en"]?[key] ?? key
    }
   
    private func getVixMood() -> (text: String, color: Color) {
        switch vix {
        case ..<20:
            return (getText("stable"), .green)
        case 20..<30:
            return (getText("normal"), .yellow)
        default:
            return (getText("unstable"), .red)
        }
    }
   
    private func getFearGreedMood() -> (text: String, color: Color) {
        switch fearAndGreedIndex {
        case ..<25:
            return (getText("extremeFear"), .red)
        case 25..<45:
            return (getText("fear"), .orange)
        case 45..<55:
            return (getText("neutral"), .yellow)
        case 55..<75:
            return (getText("greed"), .green)
        default:
            return (getText("extremeGreed"), .blue)
        }
    }
   
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(getText("marketSentiment"))
                .font(.headline)
           
            // VIX 카드
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(getText("vixIndex"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.1f", vix))
                        .font(.title3)
                        .fontWeight(.bold)
                }
               
                let vixMood = getVixMood()
                HStack {
                    Circle()
                        .fill(vixMood.color)
                        .frame(width: 8, height: 8)
                    Text(vixMood.text)
                        .font(.subheadline)
                        .foregroundColor(vixMood.color)
                }
               
                // VIX 설명 부분
                Text(getText("vixDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
               
                VStack(alignment: .leading, spacing: 4) {
                    bulletPoint(getText("vixBelow20"), .green)
                    bulletPoint(getText("vix2030"), .yellow)
                    bulletPoint(getText("vixAbove30"), .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
           
            // Fear & Greed 카드
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(getText("fearGreedIndex"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.1f", fearAndGreedIndex))
                        .font(.title3)
                        .fontWeight(.bold)
                }
               
                let fgMood = getFearGreedMood()
                HStack {
                    Circle()
                        .fill(fgMood.color)
                        .frame(width: 8, height: 8)
                    Text(fgMood.text)
                        .font(.subheadline)
                        .foregroundColor(fgMood.color)
                }
               
                Text(getText("fearGreedDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
               
                VStack(alignment: .leading, spacing: 4) {
                    bulletPoint(getText("fg025"), .red)
                    bulletPoint(getText("fg2545"), .orange)
                    bulletPoint(getText("fg4555"), .yellow)
                    bulletPoint(getText("fg5575"), .green)
                    bulletPoint(getText("fg75100"), .blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
           
            // 투자 팁 부분
            DisclosureGroup(
                content: {
                    Text(getText("tipDesc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                },
                label: {
                    Text(getText("investmentTip"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            )
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
    }
   
    private func bulletPoint(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
        }
    }
}
