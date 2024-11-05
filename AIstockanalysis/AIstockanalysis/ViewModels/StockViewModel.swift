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
    // 분석 결과를 저장할 키
    private let lastSearchKey = "lastSearchResult"
    private let lastAnalysisKey = "lastAnalysisResult"
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
            
            // 마지막 데이터 로드
            loadLastData()
        }
    
    
    
        private func loadLastData() {
                print("🔄 Starting to load last data...")
                
            // 1. 먼저 마지막 검색 결과 로드
                if let savedSearchData = UserDefaults.standard.data(forKey: lastSearchKey) {
                    do {
                        let lastSearch = try JSONDecoder().decode(LastSearchData.self, from: savedSearchData) // 여기를 수정
                        self.stockSymbol = lastSearch.symbol
                        self.dayData = lastSearch.dayData
                        self.monthData = lastSearch.monthData
                        self.newsData = lastSearch.newsData
                        self.marketSentiment = lastSearch.marketSentiment
                        self.currentPrice = lastSearch.currentPrice
                        
                        if let savedAnalysis = lastSearch.stockAnalysis {
                            print("📊 Found analysis in search data for symbol: \(lastSearch.symbol)")
                            self.stockAnalysis = savedAnalysis
                        }
                        
                        self.chartViewModel.fetchChartData(symbol: self.stockSymbol, period: .oneDay)
                        print("✅ Successfully loaded search data for symbol: \(lastSearch.symbol)")
                    } catch {
                        print("❌ Error loading search data: \(error)")
                    }
                }
                
                // 2. 별도 저장된 분석 결과 확인
                if self.stockAnalysis == nil {
                    if let savedAnalysisData = UserDefaults.standard.data(forKey: lastAnalysisKey) {
                        do {
                            let analysisData = try JSONDecoder().decode(AnalysisData.self, from: savedAnalysisData)
                            print("📊 Found separate analysis data for symbol: \(analysisData.symbol)")
                            if analysisData.symbol == self.stockSymbol {
                                self.stockAnalysis = analysisData.analysis
                                print("✅ Loaded analysis from separate storage")
                            }
                        } catch {
                            print("❌ Error loading analysis data: \(error)")
                        }
                    }
                }
            }
        
    private func saveLastData() {
            print("💾 Starting to save current data...")
            
            // 1. 검색 결과 저장
            if !dayData.isEmpty {
                let lastSearchData = LastSearchData(
                    symbol: stockSymbol,
                    dayData: dayData,
                    monthData: monthData,
                    newsData: newsData,
                    marketSentiment: marketSentiment,
                    stockAnalysis: stockAnalysis,
                    currentPrice: currentPrice
                )
                
                do {
                    let encoded = try JSONEncoder().encode(lastSearchData)
                    UserDefaults.standard.set(encoded, forKey: lastSearchKey)
                    print("✅ Successfully saved search data for \(stockSymbol)")
                } catch {
                    print("❌ Error saving search data: \(error)")
                }
            }
            
            // 2. 분석 결과 별도 저장
            if let analysis = stockAnalysis {
                let analysisData = AnalysisData(
                    symbol: stockSymbol,
                    analysis: analysis,
                    timestamp: Date(),
                    currentPrice: currentPrice
                )
                
                do {
                    let encoded = try JSONEncoder().encode(analysisData)
                    UserDefaults.standard.set(encoded, forKey: lastAnalysisKey)
                    print("✅ Successfully saved analysis data for \(stockSymbol)")
                } catch {
                    print("❌ Error saving analysis data: \(error)")
                }
            }
            
            // 3. 변경사항 즉시 저장
            UserDefaults.standard.synchronize()
        }
            
        private func saveLastSearchResult() {
            guard !dayData.isEmpty else { return }
            
            let lastSearchData = LastSearchData(
                symbol: stockSymbol,
                dayData: dayData,
                monthData: monthData,
                newsData: newsData,
                marketSentiment: marketSentiment,
                stockAnalysis: stockAnalysis,  // 추가된 부분
                currentPrice: currentPrice
            )
            
            do {
                let encoded = try JSONEncoder().encode(lastSearchData)
                UserDefaults.standard.set(encoded, forKey: lastSearchKey)
                print("✓ Successfully saved search result")
            } catch {
                print("❌ Error saving search result: \(error)")
            }
        }
    private func saveAnalysisResult(_ analysis: StockAnalysis) {
            let analysisData = AnalysisData(
                symbol: stockSymbol,
                analysis: analysis,
                timestamp: Date(),
                currentPrice: currentPrice
            )
            
            do {
                let encoded = try JSONEncoder().encode(analysisData)
                UserDefaults.standard.set(encoded, forKey: lastAnalysisKey)
                print("✓ Successfully saved analysis result for \(stockSymbol)")
            } catch {
                print("❌ Error saving analysis result: \(error)")
            }
        }
        
    private func loadLastSearchResult() {
        guard let savedData = UserDefaults.standard.data(forKey: lastSearchKey) else {
            print("ℹ️ No saved search result found")
            return
        }
        
        do {
            let lastSearch = try JSONDecoder().decode(LastSearchData.self, from: savedData)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.stockSymbol = lastSearch.symbol
                self.dayData = lastSearch.dayData
                self.monthData = lastSearch.monthData
                self.newsData = lastSearch.newsData
                self.marketSentiment = lastSearch.marketSentiment
                self.currentPrice = lastSearch.currentPrice
                self.stockAnalysis = lastSearch.stockAnalysis  // stockAnalysis도 함께 로드
                self.chartViewModel.fetchChartData(symbol: self.stockSymbol, period: .oneDay)
            }
            print("✓ Successfully loaded search result with analysis")
        } catch {
            print("❌ Error loading search result: \(error)")
        }
    }

    private func loadLastAnalysis() {
        guard let savedData = UserDefaults.standard.data(forKey: lastAnalysisKey) else {
            print("ℹ️ No saved analysis result found")
            return
        }
        
        do {
            let analysisData = try JSONDecoder().decode(AnalysisData.self, from: savedData)
            // 현재 심볼과 일치할 때만 로드하는 조건 제거
            DispatchQueue.main.async { [weak self] in
                self?.stockAnalysis = analysisData.analysis
                print("✓ Successfully loaded analysis for symbol: \(analysisData.symbol)")
            }
        } catch {
            print("❌ Error loading analysis result: \(error)")
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
                
                // 데이터 저장
                self.saveLastData()
                
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
                        // 분석 결과 저장
                        self.saveAnalysisResult(analysis)
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


// LastSearchData 구조체 수정
struct LastSearchData: Codable {
    let symbol: String
    let dayData: [StockData]
    let monthData: [StockData]
    let newsData: [StockNews]
    let marketSentiment: MarketSentiment
    let stockAnalysis: StockAnalysis?  // Optional로 추가
    let currentPrice: Double
}

struct AnalysisData: Codable {
    let symbol: String
    let analysis: StockAnalysis
    let timestamp: Date
    let currentPrice: Double
}

