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
    
    func fetchStockData() async {
        guard !stockSymbol.isEmpty else { return }
        
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
            }
        } catch StockError.apiError(let message) {
            await MainActor.run {
                self.errorMessage = message
                self.isLoading = false
            }
        } catch StockError.noDataAvailable {
            await MainActor.run {
                self.errorMessage = "No data available for this symbol"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error fetching stock data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
