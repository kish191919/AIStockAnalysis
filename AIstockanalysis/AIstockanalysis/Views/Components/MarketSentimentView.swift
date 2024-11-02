// Views/Components/MarketSentimentView.swift

import SwiftUI
import Foundation

struct MarketSentimentView: View {
    let vix: Double
    let fearAndGreedIndex: Double
    @EnvironmentObject private var viewModel: StockViewModel
    @State private var translatedTexts: [String: String] = [:]
    
    // 텍스트 키 맵은 그대로 유지
    private let textKeys = [
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
    ]
    
    private func getText(_ key: String) -> String {
            if viewModel.selectedLanguage.code == "en" {
                return textKeys[key] ?? key
            }
            return translatedTexts[key] ?? textKeys[key] ?? key
        }

    private func translateTexts() async {
        guard viewModel.selectedLanguage.code != "en" else {
            translatedTexts.removeAll()
            return
        }
        
        let textsToTranslate = Array(textKeys.values)
        var newTranslations: [String: String] = [:]
        
        for (index, text) in textsToTranslate.enumerated() {
            do {
                let translated = try await TranslationManager.shared.translate(
                    text,
                    from: "en",
                    to: viewModel.selectedLanguage.code
                )
                if let key = textKeys.first(where: { $0.value == text })?.key {
                    newTranslations[key] = translated
                }
            } catch {
                print("Translation error for text at index \(index): \(error)")
            }
        }
        
        await MainActor.run {
            translatedTexts = newTranslations
        }
    
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
           
           // Fear & Greed 카드 부분을 수정
           VStack(alignment: .leading, spacing: 12) {
               HStack {
                   Text(getText("fearGreedIndex"))  // 번역된 텍스트만 표시
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
               
               Text(getText("fearGreedDesc"))  // fearGreedDesc 번역 추가
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
       .onAppear {
           Task {
               await translateTexts()
           }
       }
       .onChange(of: viewModel.selectedLanguage) { oldValue, newValue in
                   Task {
                       await translateTexts()
                   }
               }
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
