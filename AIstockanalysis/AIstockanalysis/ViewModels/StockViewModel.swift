//
// ViewModels/StockViewModel.swift
import SwiftUI
import Combine
import CoreData

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
    @Published var currentPrice: Double = 0.0  // 추가
    @Published var lastAPIUsage: String?
    @Published var selectedLanguage: AppLanguage {
        didSet {
            if let encoded = try? JSONEncoder().encode(selectedLanguage) {
                UserDefaults.standard.set(encoded, forKey: "selectedLanguage")
            }
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
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // 저장된 언어 설정을 불러오거나, 없으면 시스템 언어를 기본값으로 설정
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
    
    private func saveAnalysisToHistory(_ analysis: StockAnalysis, currentPrice: Double) {
        let historyItem = AnalysisHistoryEntity(context: viewContext)
        historyItem.id = UUID()
        historyItem.symbol = stockSymbol
        historyItem.timestamp = Date()
        historyItem.decision = analysis.decision.rawValue
        historyItem.confidence = Int16(analysis.percentage)
        historyItem.currentPrice = currentPrice
        historyItem.expectedPrice = analysis.expectedNextDayPrice
        historyItem.reason = analysis.reason
        historyItem.language = selectedLanguage.code
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving analysis history: \(error)")
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
            currentPrice = 0.0
        }
        
        do {
            let (day, month, news, sentiment, jsonOutput) = try await StockService.fetchStockData(symbol: stockSymbol.uppercased())
            
            await MainActor.run {
                self.dayData = day
                self.monthData = month
                self.newsData = news
                self.marketSentiment = sentiment
                self.isLoading = false
                self.addToFavorites(self.stockSymbol.uppercased())
                
                // 현재 가격 설정 (장외 시간 포함)
                if let currentPrice = getCurrentPrice(day) {
                    self.currentPrice = currentPrice
                }
                
                self.chartViewModel.fetchChartData(symbol: self.stockSymbol, period: .oneDay)
            }
            
            // OpenAI 분석을 별도의 Task로 실행
            if let jsonOutput = jsonOutput {
                Task {
                    await MainActor.run {
                        self.lastJSONOutput = jsonOutput
                    }
                    await analyzeWithOpenAI(jsonData: jsonOutput)
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

    // 현재 가격을 가져오는 helper 메서드
    private func getCurrentPrice(_ dayData: [StockData]) -> Double? {
        // chartViewModel의 데이터에서 현재 시장 상태와 가격 확인
        if let chartResult = chartViewModel.chartData[.oneDay],
           let firstPoint = chartResult.first {
            switch firstPoint.sessionType {
            case .postMarket:
                return firstPoint.close
            case .preMarket:
                return firstPoint.close
            case .regular:
                return firstPoint.close
            }
        }
        
        // 차트 데이터가 없는 경우 일일 데이터의 최신 종가 사용
        return dayData.first?.close
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
            Expected Price: $\(String(format: "%.2f", analysis.expectedNextDayPrice))
            Reason: \(analysis.reason)
            """
            
            let translatedResponse = try await openAIService.getTranslation(prompt: translationPrompt)
            
            var translatedDecision = analysis.decision
            var translatedReason = analysis.reason
            
            if let decisionRange = translatedResponse.range(of: "Decision:") ??
                translatedResponse.range(of: "결정:") ??
                translatedResponse.range(of: "決定:") {
                let afterDecision = String(translatedResponse[decisionRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let endOfDecision = afterDecision.firstIndex(of: "\n") {
                    let decision = String(afterDecision[..<endOfDecision])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    translatedDecision = mapTranslatedDecision(decision)
                }
            }
            
            if let reasonRange = translatedResponse.range(of: "Reason:") ??
                translatedResponse.range(of: "이유:") ??
                translatedResponse.range(of: "理由:") {
                let afterReason = String(translatedResponse[reasonRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                translatedReason = afterReason
            }
            
            // 수정된 부분: 직접 StockAnalysis 인스턴스 생성
            let translatedAnalysis = StockAnalysis(
                decision: translatedDecision,
                percentage: analysis.percentage,
                reason: translatedReason,
                expectedNextDayPrice: analysis.expectedNextDayPrice
            )
            
            return translatedAnalysis
            
        } catch {
            print("Translation error: \(error)")
            return analysis
        }
    }
    private func mapTranslatedDecision(_ decision: String) -> StockAnalysis.Decision {
            let uppercasedDecision = decision.uppercased()
            
            // 각 언어별 용어 매핑
            let bullishTerms = ["BULLISH", "강세", "強気", "强势", "強勢", "ALCISTA", "HAUSSIER", "BULLENMARKT", "RIALZISTA", "БЫЧИЙ"]
            let bearishTerms = ["BEARISH", "약세", "弱気", "弱势", "弱勢", "BAJISTA", "BAISSIER", "BÄRENMARKT", "RIBASSISTA", "МЕДВЕЖИЙ"]
            _ = ["NEUTRAL", "중립", "中立", "中性", "NEUTRO", "NEUTRE", "NEUTRAL", "NEUTRALE", "НЕЙТРАЛЬНЫЙ"]  // _ 로 변경
            
            if bullishTerms.contains(where: { uppercasedDecision.contains($0.uppercased()) }) {
                return .bullish
            } else if bearishTerms.contains(where: { uppercasedDecision.contains($0.uppercased()) }) {
                return .bearish
            } else {
                return .neutral
            }
        }
    
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
    
    // StockViewModel.swift에서 addToFavorites 메서드 수정
    func addToFavorites(_ symbol: String) {
        if !dayData.isEmpty {
            // 이미 있는 경우 제거
            if let index = favorites.firstIndex(of: symbol) {
                favorites.remove(at: index)
            }
            // 최신 위치에 추가
            if favorites.count >= 10 {
                favorites.removeLast()
            }
            favorites.insert(symbol, at: 0)
            saveFavorites()
        }
    }
    
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
                let analysis = try await openAIService.analyzeStock(jsonData: jsonData)
                let translatedAnalysis = await translateAnalysis(analysis)
                
                await MainActor.run {
                    self.stockAnalysis = translatedAnalysis
                    self.isAnalyzing = false
                    if let currentPrice = self.dayData.first?.close {
                        self.saveAnalysisToHistory(translatedAnalysis, currentPrice: currentPrice)
                    }
                    // API 사용량 정보 업데이트
                    self.lastAPIUsage = self.openAIService.getCurrentSessionUsage()
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
    
    func deleteHistoryItem(_ item: AnalysisHistoryEntity) {
        viewContext.delete(item)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting history item: \(error)")
        }
    }
}


