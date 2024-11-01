// Views/AnalysisView.swift

import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var viewModel: StockViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                // 검색 바 추가
                HStack {
                    TextField("Enter stock symbol (e.g., AAPL)", text: $viewModel.stockSymbol)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .submitLabel(.search)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            startSearch()
                        }
                    
                    Button(action: {
                        startSearch()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else if let error = viewModel.errorMessage {
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
                } else if !viewModel.stockSymbol.isEmpty && !viewModel.dayData.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(viewModel.stockSymbol)
                                    .font(.title)
                                    .bold()
                                
                                if let latestPrice = viewModel.dayData.first?.close {
                                    Text("$\(String(format: "%.2f", latestPrice))")
                                        .font(.title2)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Market Sentiment
                            HStack {
                                SentimentCard(title: "VIX", value: viewModel.marketSentiment.vix)
                                SentimentCard(title: "F&G Index", value: viewModel.marketSentiment.fearAndGreedIndex)
                            }
                            .padding(.horizontal)
                            
                            // Recent News Section
                            if !viewModel.newsData.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Recent News")
                                        .font(.headline)
                                        .padding(.horizontal)
                                        .padding(.top)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(viewModel.newsData, id: \.title) { news in
                                            NewsCard(news: news)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Enter a stock symbol to see details")
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .navigationTitle("Analysis")
        }
    }
    
    private func startSearch() {
        isTextFieldFocused = false
        Task {
            await viewModel.fetchStockData()
        }
    }
}

// SentimentCard와 NewsCard 컴포넌트는 그대로 유지
struct SentimentCard: View {
    let title: String
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(String(format: "%.2f", value))
                .font(.headline)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NewsCard: View {
    let news: StockNews
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(news.title)
                .font(.subheadline)
                .lineLimit(2)
            Text(news.pubDate)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
