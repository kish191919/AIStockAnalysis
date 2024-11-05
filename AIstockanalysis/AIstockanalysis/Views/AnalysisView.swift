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
            .navigationTitle("AI Analysis")
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

    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                TextField("Enter stock symbol or company name", text: $viewModel.stockSymbol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .submitLabel(.search)
                    .focused($isTextFieldFocused)
                    .onChange(of: viewModel.stockSymbol) { oldValue, newValue in
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
                
                Button(action: {
                    showLanguageSheet = true
                }) {
                    Text(viewModel.selectedLanguage.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: 80)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
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
    // MARK: - Search Suggestions and Recent Searches
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                let filteredFavorites = viewModel.favorites.filter { $0 != viewModel.stockSymbol }
                if !filteredFavorites.isEmpty {
                    ForEach(filteredFavorites, id: \.self) { symbol in
                        Text(symbol)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(15)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                viewModel.stockSymbol = symbol
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
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
    }
    
    // MARK: - Main Content Section
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
    
    private var stockChartSection: some View {
        YahooFinanceChartView(
            symbol: viewModel.stockSymbol,
            currentPrice: Binding(
                get: { viewModel.currentPrice },
                set: { viewModel.currentPrice = $0 }
            )
        )
        .frame(height: 300)
        .padding(.horizontal, -4)
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
        MarketSentimentView(
            vix: viewModel.marketSentiment.vix,
            fearAndGreedIndex: viewModel.marketSentiment.fearAndGreedIndex
        )
    }
    
    // MARK: - News Section
    private var newsSection: some View {
        Group {
            if !viewModel.newsData.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(viewModel.selectedLanguage.code == "en" ? "Recent News" : "최근 뉴스")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    TabView {
                        GeometryReader { geometry in
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(viewModel.newsData.prefix(5)), id: \.title) { news in
                                    NewsCardLink(news: news)
                                }
                            }
                            .frame(width: geometry.size.width)
                            .padding(.horizontal)
                        }
                        
                        if viewModel.newsData.count > 5 {
                            GeometryReader { geometry in
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(viewModel.newsData.dropFirst(5).prefix(5)), id: \.title) { news in
                                        NewsCardLink(news: news)
                                    }
                                }
                                .frame(width: geometry.size.width)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 5 * 80)
                }
            }
        }
    }
    
    // CompanyLogo 컴포넌트 추가
    struct CompanyLogo: View {
        let symbol: String
        let size: CGFloat
        
        private var logoUrl: URL? {
            URL(string: "https://logo.clearbit.com/\(getCompanyDomain(symbol)).com")
        }
        
        private func getCompanyDomain(_ symbol: String) -> String {
            let domainMap: [String: String] = [
                // 기술 기업
                "AAPL": "apple",
                "MSFT": "microsoft",
                "GOOGL": "google",
                "GOOG": "google",
                "AMZN": "amazon",
                "META": "meta",
                "NFLX": "netflix",
                "TSLA": "tesla",
                "IBM": "ibm",
                "NVDA": "nvidia",
                "AMD": "amd",
                "INTC": "intel",
                "ORCL": "oracle",
                "CRM": "salesforce",
                "ADBE": "adobe",
                "CSCO": "cisco",
                "PYPL": "paypal",
                "UBER": "uber",
                "LYFT": "lyft",
                "SNAP": "snapchat",
                "SPOT": "spotify",
                "ZM": "zoom",
                "TWTR": "twitter",
                
                // 금융
                "V": "visa",
                "MA": "mastercard",
                "JPM": "jpmorgan",
                "BAC": "bankofamerica",
                "WFC": "wellsfargo",
                "GS": "goldmansachs",
                "MS": "morganstanley",
                "AXP": "americanexpress",
                "C": "citigroup",
                
                // 소매/소비재
                "WMT": "walmart",
                "TGT": "target",
                "COST": "costco",
                "HD": "homedepot",
                "SBUX": "starbucks",
                "MCD": "mcdonalds",
                "NKE": "nike",
                "LULU": "lululemon",
                "ETSY": "etsy",
                
                // 자동차
                "F": "ford",
                "GM": "gm",
                "TM": "toyota",
                "HMC": "honda",
                "RACE": "ferrari",
                
                // 통신
                "T": "att",
                "VZ": "verizon",
                "TMUS": "tmobile",
                
                // 미디어/엔터테인먼트
                "DIS": "disney",
                "CMCSA": "comcast",
                "SONY": "sony",
                
                // 제약/의료
                "JNJ": "jnj",
                "PFE": "pfizer",
                "MRK": "merck",
                "ABBV": "abbvie",
                "BMY": "bms",
                
                // 소비재
                "PG": "pg",
                "KO": "coca-cola",
                "PEP": "pepsi",
                "UL": "unilever",
                "NVS": "novartis",
                
                // 아시아 기업
                "BABA": "alibaba",
                "TSM": "tsmc",
                "BIDU": "baidu",
                "9988.HK": "alibaba",
                "005930.KS": "samsung",
                "000660.KS": "skhynix",
                "035420.KS": "naver",
                "035720.KS": "kakao",
                
                // 항공/여행
                "DAL": "delta",
                "UAL": "united",
                "AAL": "americanairlines",
                "MAR": "marriott",
                "HLT": "hilton",
                
                // 에너지
                "XOM": "exxonmobil",
                "CVX": "chevron",
                "BP": "bp",
                "SHELL": "shell"
            ]
            return domainMap[symbol.uppercased()] ?? symbol.lowercased()
        }
        
        var body: some View {
            AsyncImage(url: logoUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                    Text(symbol.prefix(1))
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(width: size, height: size)
            }
        }
    }
    
    private var stockInfoHeader: some View {
        HStack(spacing: 12) {
            // 회사 로고
            CompanyLogo(symbol: viewModel.stockSymbol, size: 32)
            
            // 주식 심볼과 가격을 포함하는 HStack
            HStack(spacing: 8) {
                // 주식 심볼
                Text(viewModel.stockSymbol)
                    .font(.title2)
                    .bold()
                
                // 가격
                Text("$\(String(format: "%.2f", viewModel.currentPrice))")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    
    struct NewsCardLink: View {
        let news: StockNews
        
        var body: some View {
            Link(destination: getURL()) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(news.title)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(news.pubDate)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(NewsCardButtonStyle())
        }
        
        private func getURL() -> URL {
            var urlString = news.link.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // URL이 프로토콜을 포함하지 않는 경우 https를 추가
            if !urlString.lowercased().hasPrefix("http") {
                urlString = "https://" + urlString
            }
            
            return URL(string: urlString) ?? URL(string: "https://finance.yahoo.com")!
        }
    }

    // 버튼 스타일 수정
    struct NewsCardButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
        
        // MARK: - Analysis Section Components
    // AnalysisView의 aiAnalysisSection 수정
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
                                            viewModel.stockSymbol = symbol
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

                                struct RecommendationBar: View {
                                    let value: Int
                                    let total: Int
                                    let color: Color
                                    
                                    var height: CGFloat {
                                        let percentage = CGFloat(value) / CGFloat(total)
                                        return max(percentage * 100, 4) // 최소 높이 4
                                    }
                                    
                                    var body: some View {
                                        VStack {
                                            if value > 0 {
                                                Text("\(value)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(color)
                                                .frame(width: 30, height: height)
                                        }
                                    }
                                }
                            }
