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
            // 언어가 변경되면 현재 분석된 데이터를 새로운 언어로 다시 분석
            if let jsonOutput = lastJSONOutput {
                Task {
                    await analyzeWithOpenAI(jsonData: jsonOutput)
                }
            }
        }
    }
    
    private var searchTask: Task<Void, Never>?
    let openAIService = OpenAIService()
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // 저장된 언어 설정 불러오기
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
                await MainActor.run {
                    self.lastJSONOutput = jsonOutput
                }
                await analyzeWithOpenAI(jsonData: jsonOutput)
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
            let analysis = try await openAIService.analyzeStock(
                jsonData: jsonData,
                targetLanguage: selectedLanguage.code
            )
            
            await MainActor.run {
                self.stockAnalysis = analysis
                self.isAnalyzing = false
                if let currentPrice = self.dayData.first?.close {
                    self.saveAnalysisToHistory(analysis, currentPrice: currentPrice)
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
        let symbol = stockSymbol.uppercased()
        
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
    
    // MARK: - Utility Methods
    
    func validateSymbol(_ symbol: String) -> Bool {
        let pattern = "^[A-Za-z]{1,5}$"
        let symbolTest = NSPredicate(format:"SELF MATCHES %@", pattern)
        return symbolTest.evaluate(with: symbol)
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
