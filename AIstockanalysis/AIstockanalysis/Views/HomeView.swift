// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var stockSymbol: String = ""
    @State private var dayData: [StockData] = []
    @State private var monthData: [StockData] = []
    @State private var newsData: [StockNews] = []
    @State private var marketSentiment: MarketSentiment = MarketSentiment(vix: 0.0, fearAndGreedIndex: 0.0)
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 검색 바
                HStack {
                    TextField("Enter stock symbol (e.g., AAPL)", text: $stockSymbol)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await fetchStockData()
                            }
                        }
                    
                    Button(action: {
                        Task {
                            await fetchStockData()
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.largeTitle)
                            .padding()
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if !monthData.isEmpty {
                    StockDetailView(
                        symbol: stockSymbol,
                        dayData: dayData,
                        monthData: monthData,
                        newsData: newsData,
                        marketSentiment: marketSentiment
                    )
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Enter a stock symbol to see details")
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Stock Search")
        }
    }
    
    private func fetchStockData() async {
        guard !stockSymbol.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        dayData = []
        monthData = []
        newsData = []
        marketSentiment = MarketSentiment(vix: 0.0, fearAndGreedIndex: 0.0)
        
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
