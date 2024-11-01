// Views/AnalysisView.swift
import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var viewModel: StockViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showDeleteConfirmation = false
    @State private var symbolToDelete: String?
    @State private var showSuggestions = false
    @State private var showTickerGuide = false
    @State private var showLanguageSheet = false
    @State private var currentPrice: Double = 0.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    searchBarSection
                    recentSearchesSection
                    mainContentSection
                }
            }
            .navigationTitle("Analysis")
            .alert("Delete Symbol", isPresented: $showDeleteConfirmation, presenting: symbolToDelete) { symbol in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    withAnimation {
                        viewModel.removeFromFavorites(symbol)
                    }
                }
            } message: { symbol in
                Text("Are you sure you want to delete '\(symbol)' from recent searches?")
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil,
                                             from: nil,
                                             for: nil)
                showSuggestions = false
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguageListView(selectedLanguage: $viewModel.selectedLanguage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var languageSelector: some View {
        HStack {
            Spacer()
            Button(action: {
                showLanguageSheet = true
            }) {
                HStack {
                    Text(viewModel.selectedLanguage.name)
                        .lineLimit(1)
                    Image(systemName: "globe")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var searchBarSection: some View {
        VStack(alignment: .leading) {
            // 첫 번째 줄: 검색창과 번역 버튼
            HStack(spacing: 8) {
                TextField("Enter stock symbol or company name", text: $viewModel.stockSymbol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .submitLabel(.search)
                    .focused($isTextFieldFocused)
                    .onChange(of: viewModel.stockSymbol) { oldValue, newValue in  // 수정된 부분
                        handleSearchTextChange(newValue)
                    }
                    .onSubmit {
                        if !viewModel.stockSymbol.isEmpty {
                            startSearch()
                        }
                    }
                
                if !viewModel.stockSymbol.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                // 번역 버튼
                Button(action: {
                    showLanguageSheet = true
                }) {
                    Text(viewModel.selectedLanguage.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: 80)  // 번역 버튼 너비 고정
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // 두 번째 줄: AI 분석 버튼
            Button(action: {
                if !viewModel.stockSymbol.isEmpty {
                    startSearch()
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("AI Stock Analysis")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(viewModel.stockSymbol.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.stockSymbol.isEmpty)
            
            if showTickerGuide {
                Text("Stock ticker should be 1-5 letters (e.g., AAPL, MSFT, GOOGL)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            
            if showSuggestions && !viewModel.searchResults.isEmpty && isTextFieldFocused {
                searchSuggestionsView
            }
            
            if viewModel.isSearching {
                ProgressView()
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
    
    private var searchSuggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.searchResults, id: \.symbol) { result in
                    Button(action: {
                        selectSearchResult(result.symbol)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.symbol)
                                .font(.headline)
                            Text(result.name)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                    Divider()
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var recentSearchesSection: some View {
        Group {
            if !viewModel.favorites.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.favorites, id: \.self) { symbol in
                            recentSearchItem(symbol)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var mainContentSection: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else if !viewModel.stockSymbol.isEmpty && !viewModel.dayData.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    stockInfoHeader
                    stockChartSection
                    analysisSection
                    marketSentimentSection
                    newsSection
                }
            }
        }
    }
    
    private var stockInfoHeader: some View {
        HStack {
            Text(viewModel.stockSymbol)
                .font(.title)
                .bold()
            
            Text("$\(String(format: "%.2f", currentPrice))")
                .font(.title2)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: currentPrice)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // AnalysisView의 stockChartSection 수정
    private var stockChartSection: some View {
        YahooFinanceChartView(symbol: viewModel.stockSymbol, currentPrice: $currentPrice)
            .frame(height: 300)
            .padding(.horizontal, -4) // 패딩 값을 줄임
    }
    
    private var analysisSection: some View {
        Group {
            if viewModel.isAnalyzing {
                VStack {
                    ProgressView()
                    Text("AI is analyzing the stock data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            } else if let analysis = viewModel.stockAnalysis {
                aiAnalysisSection(analysis)
            }
        }
    }
    
    private var marketSentimentSection: some View {
        VStack(spacing: 10) {
            Text("Market Sentiment")
                .font(.headline)
                .padding(.top)
            
            HStack {
                SentimentCard(title: "VIX", value: viewModel.marketSentiment.vix)
                SentimentCard(title: "F&G Index", value: viewModel.marketSentiment.fearAndGreedIndex)
            }
        }
        .padding(.horizontal)
    }
    
    private var newsSection: some View {
        Group {
            if !viewModel.newsData.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent News")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.newsData, id: \.title) { news in
                                NewsCard(news: news)
                                    .frame(width: 300)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func aiAnalysisSection(_ analysis: StockAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("AI Analysis")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text("Confidence:")
                        .font(.caption)
                    Text("\(analysis.percentage)%")
                        .font(.caption)
                        .bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
            
            HStack {
                Text(analysis.decision.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Group {
                            switch analysis.decision {
                            case .bullish: Color.green
                            case .bearish: Color.red
                            case .neutral: Color.orange
                            }
                        }
                    )
                    .cornerRadius(8)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Expected Next Day")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("$\(analysis.expectedNextDayPrice, specifier: "%.2f")")
                        .font(.headline)
                }
            }
            
            Text(analysis.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func handleSearchTextChange(_ newValue: String) {
        let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
        if filtered != newValue {
            viewModel.stockSymbol = filtered
            showTickerGuide = true
        } else {
            showTickerGuide = filtered.count > 5 || (!filtered.isEmpty && !viewModel.validateSymbol(filtered))
        }
        viewModel.searchSymbol(query: filtered)
        showSuggestions = !filtered.isEmpty
    }
    
    private func clearSearch() {
        viewModel.stockSymbol = ""
        showSuggestions = false
        showTickerGuide = false
    }
    
    private func selectSearchResult(_ symbol: String) {
        viewModel.stockSymbol = symbol
        showSuggestions = false
        isTextFieldFocused = false
        startSearch()
    }
    
    private func startSearch() {
        isTextFieldFocused = false
        Task {
            let success = await viewModel.fetchStockData()
            if !success {
                await MainActor.run {
                    isTextFieldFocused = true
                }
            } else {
                if let latestPrice = viewModel.dayData.first?.close {
                    await MainActor.run {
                        currentPrice = latestPrice
                    }
                }
            }
        }
    }
    
    private func recentSearchItem(_ symbol: String) -> some View {
        Text(symbol)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            .foregroundColor(.primary)
            .onTapGesture {
                viewModel.stockSymbol = symbol  // 검색창에 심볼만 입력
            }
            .contextMenu {
                Button(role: .destructive) {
                    symbolToDelete = symbol
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

// MARK: - Support Views

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
        Link(destination: URL(string: news.link) ?? URL(string: "https://finance.yahoo.com")!) {
            VStack(alignment: .leading, spacing: 5) {
                Text(news.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                Text(news.pubDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
