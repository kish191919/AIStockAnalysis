//
// ViewModels/StockViewModel.swift
import SwiftUI
import Combine

@MainActor
class StockViewModel: ObservableObject {
    @Published var stockSymbol: String = ""
    @Published var dayData: [StockData] = []
    @Published var monthData: [StockData] = []
    @Published var newsData: [StockNews] = []
    @Published var marketSentiment: MarketSentiment = MarketSentiment(vix: 0.0, fearAndGreedIndex: 0.0)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var favorites: [String] = []
    @Published var searchResults: [(symbol: String, name: String)] = []
    @Published var isSearching = false
    @Published var stockAnalysis: StockAnalysis?
    @Published var isAnalyzing = false
    @Published var lastJSONOutput: String?
    @Published var chartViewModel: YahooChartViewModel = YahooChartViewModel()
    @Published var selectedLanguage: AppLanguage {
        didSet {
            // 선택된 언어를 UserDefaults에 저장
            if let encoded = try? JSONEncoder().encode(selectedLanguage) {
                UserDefaults.standard.set(encoded, forKey: "selectedLanguage")
            }
            // 언어가 변경되면 기존 분석 결과를 새 언어로 번역
            if let analysis = stockAnalysis {
                Task {
                    let translatedAnalysis = await translateAnalysis(analysis)
                    await MainActor.run {
                        self.stockAnalysis = translatedAnalysis
                    }
                }
            }
        }
    }
    
    private var searchTask: Task<Void, Never>?
    private let openAIService = OpenAIService()
    
    init() {
        // 저장된 언어 설정을 불러오거나, 없으면 시스템 언어 또는 영어를 기본값으로 설정
        if let savedLanguageData = UserDefaults.standard.data(forKey: "selectedLanguage"),
           let savedLanguage = try? JSONDecoder().decode(AppLanguage.self, from: savedLanguageData) {
            self.selectedLanguage = savedLanguage
        } else {
            self.selectedLanguage = AppLanguage.systemLanguage
        }
        
        // 저장된 즐겨찾기 불러오기
        if let savedFavorites = UserDefaults.standard.stringArray(forKey: "favorites") {
            favorites = savedFavorites
        }
    }
    
    func fetchStockData() async -> Bool {
        guard !stockSymbol.isEmpty else { return false }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            dayData = []
            monthData = []
            newsData = []
            marketSentiment = MarketSentiment(vix: 0.0, fearAndGreedIndex: 0.0)
            lastJSONOutput = nil
        }
        
        do {
            let (day, month, news, sentiment) = try await StockService.fetchStockData(symbol: stockSymbol.uppercased())
            
            await MainActor.run {
                self.dayData = day
                self.monthData = month
                self.newsData = news
                self.marketSentiment = sentiment
                self.isLoading = false
                self.addToFavorites(self.stockSymbol.uppercased())
                
                // 차트 데이터 로드
                self.chartViewModel.fetchChartData(symbol: self.stockSymbol, period: .oneDay)
            }
            
            // createJSONOutput 호출 부분 수정
            Task {
                if let jsonData = createJSONOutput(day: day, month: month, news: news, sentiment: sentiment) {
                    await MainActor.run {
                        self.lastJSONOutput = jsonData
                    }
                    await analyzeWithOpenAI(jsonData: jsonData)
                }
            }
            
            return true
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.showAlert = true
            }
            return false
        }
    }
    
    
    func translateAnalysis(_ analysis: StockAnalysis) async -> StockAnalysis {
        guard selectedLanguage.code != "en" else { return analysis }
        
        do {
            let translationPrompt = """
            Translate the following stock analysis from English to \(selectedLanguage.name).
            Keep the format but translate the content naturally into the target language.
            For the decision, translate:
            - BULLISH appropriately (e.g., "강세" for Korean, "強気" for Japanese)
            - BEARISH appropriately (e.g., "약세" for Korean, "弱気" for Japanese)
            - NEUTRAL appropriately (e.g., "중립" for Korean, "中立" for Japanese)

            Original text:
            Decision: \(analysis.decision.rawValue)
            Confidence: \(analysis.percentage)%
            Expected Price: $\(analysis.expectedNextDayPrice)
            Reason: \(analysis.reason)
            """
            
            let translatedResponse = try await openAIService.getTranslation(prompt: translationPrompt)
            
            // 번역된 응답에서 결정과 이유 추출
            var translatedDecision = analysis.decision
            var translatedReason = analysis.reason
            
            // 번역된 텍스트에서 결정과 이유 파싱
            if let decisionRange = translatedResponse.range(of: "Decision:") ??
                                 translatedResponse.range(of: "결정:") ??
                                 translatedResponse.range(of: "決定:") {
                let afterDecision = String(translatedResponse[decisionRange.upperBound...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if let endOfDecision = afterDecision.firstIndex(of: "\n") {
                    let decision = String(afterDecision[..<endOfDecision]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    translatedDecision = mapTranslatedDecision(decision)
                }
            }
            
            if let reasonRange = translatedResponse.range(of: "Reason:") ??
                               translatedResponse.range(of: "이유:") ??
                               translatedResponse.range(of: "理由:") {
                let afterReason = String(translatedResponse[reasonRange.upperBound...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                translatedReason = afterReason
            }
            
            return StockAnalysis(
                decision: translatedDecision,
                percentage: analysis.percentage,
                reason: translatedReason,
                expectedNextDayPrice: analysis.expectedNextDayPrice
            )
            
        } catch {
            print("Translation error: \(error)")
            return analysis
        }
    }
    
    private func mapTranslatedDecision(_ decision: String) -> StockAnalysis.Decision {
        // 다양한 언어의 강세/약세/중립 표현을 매핑
        let bullishTerms = ["BULLISH", "강세", "強気", "强势", "強勢", "ALCISTA", "HAUSSIER", "BULLENMARKT", "RIALZISTA", "БЫЧИЙ"]
        let bearishTerms = ["BEARISH", "약세", "弱気", "弱势", "弱勢", "BAJISTA", "BAISSIER", "BÄRENMARKT", "RIBASSISTA", "МЕДВЕЖИЙ"]
        let neutralTerms = ["NEUTRAL", "중립", "中立", "中性", "NEUTRO", "NEUTRE", "NEUTRAL", "NEUTRALE", "НЕЙТРАЛЬНЫЙ"]
        
        let upperDecision = decision.uppercased()
        
        if bullishTerms.contains(where: { upperDecision.contains($0.uppercased()) }) {
            return .bullish
        } else if bearishTerms.contains(where: { upperDecision.contains($0.uppercased()) }) {
            return .bearish
        } else {
            return .neutral
        }
    }
    
    @MainActor
    func searchSymbol(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            self.searchResults = []
            return
        }
        
        searchTask = Task {
            do {
                self.isSearching = true
                let results = try await StockService.searchSymbol(query: query)
                
                if !Task.isCancelled {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
    
    @MainActor
    func addToFavorites(_ symbol: String) {
        if !dayData.isEmpty && !favorites.contains(symbol) {
            if favorites.count >= 10 {
                favorites.removeLast()
            }
            favorites.insert(symbol, at: 0)
            saveFavorites()
        }
    }
    
    @MainActor
    func removeFromFavorites(_ symbol: String) {
        if let index = favorites.firstIndex(of: symbol) {
            favorites.remove(at: index)
            saveFavorites()
        }
    }
    
    func validateSymbol(_ symbol: String) -> Bool {
        let pattern = "^[A-Za-z]{1,5}$"
        let symbolTest = NSPredicate(format:"SELF MATCHES %@", pattern)
        return symbolTest.evaluate(with: symbol)
    }
    
    private func createJSONOutput(day: [StockData], month: [StockData], news: [StockNews], sentiment: MarketSentiment) -> String? {
        let data: [String: Any] = [
            "symbol": stockSymbol,
            "currentPrice": day.first?.close ?? 0,
            "dailyData": day.map { [
                "date": StockService.formatDateWithMinutes($0.date),
                "open": $0.open,
                "close": $0.close,
                "high": $0.high,
                "low": $0.low,
                "volume": $0.volume
            ]},
            "monthlyData": month.map { [
                "date": StockService.formatDateOnly($0.date),
                "close": $0.close
            ]},
            "news": news.map { [
                "title": $0.title,
                "date": $0.pubDate
            ]},
            "marketSentiment": [
                "vix": sentiment.vix,
                "fearAndGreedIndex": sentiment.fearAndGreedIndex
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error creating JSON output: \(error)")
            return nil
        }
    }
    
    private func analyzeWithOpenAI(jsonData: String) async {
        await MainActor.run {
            isAnalyzing = true
            stockAnalysis = nil
        }
        
        do {
            print("📤 Sending data to OpenAI: \(jsonData)")
            
            let analysis = try await openAIService.analyzeStock(jsonData: jsonData)
            
            // 선택된 언어로 번역
            let translatedAnalysis = await translateAnalysis(analysis)
            
            await MainActor.run {
                self.stockAnalysis = translatedAnalysis
                self.isAnalyzing = false
            }
        } catch {
            print("❌ OpenAI Analysis error: \(error.localizedDescription)")
            await MainActor.run {
                self.isAnalyzing = false
            }
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(favorites, forKey: "favorites")
    }
}
