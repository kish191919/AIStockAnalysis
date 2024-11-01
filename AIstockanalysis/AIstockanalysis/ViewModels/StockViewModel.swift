//
//  StockViewModel.swift
import SwiftUI
import Combine

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
   
   private var searchTask: Task<Void, Never>?
   
   init() {
       if let savedFavorites = UserDefaults.standard.stringArray(forKey: "favorites") {
           favorites = savedFavorites
       }
   }
   
   func searchSymbol(query: String) {
       // 이전 검색 작업 취소
       searchTask?.cancel()
       
       guard !query.isEmpty else {
           DispatchQueue.main.async {
               self.searchResults = []
           }
           return
       }
       
       searchTask = Task { @MainActor in
           do {
               self.isSearching = true
               let results = try await StockService.searchSymbol(query: query)
               
               // 취소되지 않았다면 결과 업데이트
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
   
   func addToFavorites(_ symbol: String) {
       // 데이터가 있는 경우에만 즐겨찾기에 추가
       if !dayData.isEmpty && !favorites.contains(symbol) {
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
   
   func fetchStockData() async -> Bool {
       guard !stockSymbol.isEmpty else {
           return false
       }
       
       await MainActor.run {
           self.isLoading = true
           self.errorMessage = nil
           self.dayData = []
           self.monthData = []
           self.newsData = []
           self.marketSentiment = MarketSentiment(vix: 0.0, fearAndGreedIndex: 0.0)
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
           }
           return true
       } catch {
           await MainActor.run {
               self.isLoading = false
           }
           return false
       }
   }
   
   private func saveFavorites() {
       UserDefaults.standard.set(favorites, forKey: "favorites")
   }
}
