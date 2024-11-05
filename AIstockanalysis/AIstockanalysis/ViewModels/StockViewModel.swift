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
    @Published var currentPrice: Double = 0.0
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
    private var translationCache: [String: String] = [:]
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        if let savedLanguageData = UserDefaults.standard.data(forKey: "selectedLanguage"),
           let savedLanguage = try? JSONDecoder().decode(AppLanguage.self, from: savedLanguageData) {
            self.selectedLanguage = savedLanguage
        } else {
            self.selectedLanguage = AppLanguage.systemLanguage
        }
        
        if let savedFavorites = UserDefaults.standard.stringArray(forKey: "favorites") {
            favorites = savedFavorites
        }
    }
    
    // MARK: - Translation Methods
    
    func translateText(_ text: String) async throws -> String {
        if selectedLanguage.code == "en" {
            return text
        }
        
        if let cached = translationCache[text] {
            return cached
        }
        
        let translated = try await TranslationManager.shared.translate(
            text,
            from: "en",
            to: selectedLanguage.code
        )
        
        translationCache[text] = translated
        return translated
    }
    
    func translateAnalysis(_ analysis: StockAnalysis) async -> StockAnalysis {
        guard selectedLanguage.code != "en" else { return analysis }
        
        do {
            let translatedReason = try await translateText(analysis.reason)
            
            return StockAnalysis(
                decision: analysis.decision,
                percentage: analysis.percentage,
                reason: translatedReason,
                expectedNextDayPrice: analysis.expectedNextDayPrice
            )
        } catch {
            print("Translation error: \(error)")
            return analysis
        }
    }
    
    private func clearTranslationCache() {
        translationCache.removeAll()
    }
    
    // MARK: - Stock Data Methods
    
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
                
                if let currentPrice = getCurrentPrice(day) {
                    self.currentPrice = currentPrice
                }
                
                self.chartViewModel.fetchChartData(symbol: self.stockSymbol, period: .oneDay)
            }
            
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
    
    private func getCurrentPrice(_ dayData: [StockData]) -> Double? {
        if let chartResult = chartViewModel.chartData[.oneDay],
           let firstPoint = chartResult.first {
            switch firstPoint.sessionType {
            case .postMarket, .preMarket, .regular:
                return firstPoint.close
            }
        }
        return dayData.first?.close
    }
    
    // MARK: - OpenAI Analysis
    
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
                self.lastAPIUsage = self.openAIService.getCurrentSessionUsage()
            }
        } catch {
            print("❌ OpenAI Analysis error: \(error.localizedDescription)")
            await MainActor.run {
                self.isAnalyzing = false
            }
        }
    }
    
    // MARK: - Search Methods
    
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
    
    // MARK: - Favorites Management
    
    func addToFavorites(_ symbol: String) {
        if !dayData.isEmpty {
            if let index = favorites.firstIndex(of: symbol) {
                favorites.remove(at: index)
            }
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
    
    private func saveFavorites() {
        UserDefaults.standard.set(favorites, forKey: "favorites")
    }
    
    // MARK: - History Management
    
    private func saveAnalysisToHistory(_ analysis: StockAnalysis, currentPrice: Double) {
        let historyItem = AnalysisHistoryEntity(context: viewContext)
        let symbol = stockSymbol.uppercased()  // 대문자로 변환
        
        historyItem.id = UUID()
        historyItem.symbol = symbol
        historyItem.timestamp = Date()
        historyItem.decision = analysis.decision.rawValue
        historyItem.confidence = Int16(analysis.percentage)
        historyItem.currentPrice = currentPrice
        historyItem.expectedPrice = analysis.expectedNextDayPrice
        historyItem.reason = analysis.reason
        historyItem.language = selectedLanguage.code
        
        // lastAccessedSymbols 업데이트
        if let data = UserDefaults.standard.data(forKey: "lastAccessedSymbols"),
           var symbols = try? JSONDecoder().decode([String].self, from: data) {
            symbols.removeAll { $0 == symbol }
            symbols.insert(symbol, at: 0)
            if symbols.count > 20 {
                symbols.removeLast()
            }
            if let encoded = try? JSONEncoder().encode(symbols) {
                UserDefaults.standard.set(encoded, forKey: "lastAccessedSymbols")
            }
        } else {
            if let encoded = try? JSONEncoder().encode([symbol]) {
                UserDefaults.standard.set(encoded, forKey: "lastAccessedSymbols")
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving analysis history: \(error)")
        }
    }

    // 최근 접근 심볼 업데이트 함수 추가
    private func updateLastAccessedSymbols(_ symbol: String) {
        if let data = UserDefaults.standard.data(forKey: "lastAccessedSymbols"),
           var symbols = try? JSONDecoder().decode([String].self, from: data) {
            symbols.removeAll { $0 == symbol }
            symbols.insert(symbol, at: 0)
            if symbols.count > 20 {
                symbols.removeLast()
            }
            if let encoded = try? JSONEncoder().encode(symbols) {
                UserDefaults.standard.set(encoded, forKey: "lastAccessedSymbols")
            }
        } else {
            if let encoded = try? JSONEncoder().encode([symbol]) {
                UserDefaults.standard.set(encoded, forKey: "lastAccessedSymbols")
            }
        }
    }
    
    func deleteHistoryItem(_ item: AnalysisHistoryEntity) {
        viewContext.delete(item)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting history item: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func validateSymbol(_ symbol: String) -> Bool {
        let pattern = "^[A-Za-z]{1,5}$"
        let symbolTest = NSPredicate(format:"SELF MATCHES %@", pattern)
        return symbolTest.evaluate(with: symbol)
    }
    
    private func mapTranslatedDecision(_ decision: String) -> StockAnalysis.Decision {
        let uppercasedDecision = decision.uppercased()
        
        let bullishTerms = ["BULLISH", "강세", "強気", "强势", "強勢", "ALCISTA", "HAUSSIER", "BULLENMARKT", "RIALZISTA", "БЫЧИЙ"]
        let bearishTerms = ["BEARISH", "약세", "弱気", "弱势", "弱勢", "BAJISTA", "BAISSIER", "BÄRENMARKT", "RIBASSISTA", "МЕДВЕЖИЙ"]
        
        if bullishTerms.contains(where: { uppercasedDecision.contains($0.uppercased()) }) {
            return .bullish
        } else if bearishTerms.contains(where: { uppercasedDecision.contains($0.uppercased()) }) {
            return .bearish
        } else {
            return .neutral
        }
    }
}
