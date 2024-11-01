// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: StockViewModel
    @FocusState private var isTextFieldFocused: Bool
    @Binding var selectedTab: Int  // 추가
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 검색 바
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
            }
            .navigationTitle("Stock Search")
        }
    }
    
    private func startSearch() {
        isTextFieldFocused = false
        Task {
            await viewModel.fetchStockData()
            if !viewModel.dayData.isEmpty {
                selectedTab = 1  // Analysis 탭으로 전환
            }
        }
    }
}
