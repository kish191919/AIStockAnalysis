import Foundation

public class StockService {
    public static func fetchStockData(symbol: String) async throws -> (dayData: [StockData], monthData: [StockData], newsData: [StockNews], marketSentiment: MarketSentiment) {
        print("\n🔍 Fetching data from Yahoo Finance for \(symbol)")
        let (extendedData, monthData) = try await fetchAllData(symbol: symbol)
        let newsData = try await fetchNewsData(symbol: symbol)
        let sentiment = try await fetchMarketSentiment()
        
        // 최적화된 JSON 출력
        printOptimizedJSONOutput(extendedData, monthData, newsData, sentiment)
        
        return (extendedData, monthData, newsData, sentiment)
    }
    
    private static func fetchAllData(symbol: String) async throws -> (dayData: [StockData], monthData: [StockData]) {
        let now = Int(Date().timeIntervalSince1970)
        let threeDaysAgo = Int((Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()).timeIntervalSince1970)
        
        let baseURL = "https://query2.finance.yahoo.com/v8/finance/chart/"
        let urlString = "\(baseURL)\(symbol)?period1=\(threeDaysAgo)&period2=\(now)&interval=15m"
        
        print("🌐 Requesting URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("*/*", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StockError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw StockError.apiError("Server returned status code: \(httpResponse.statusCode)")
            }
            
            let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
            
            guard let result = yahooResponse.chart.result?.first else {
                if let error = yahooResponse.chart.error {
                    throw StockError.apiError(error.description)
                }
                throw StockError.invalidResponse
            }
            
            let timestamps = result.timestamp
            let quotes = result.indicators.quote.first
            
            guard let quotes = quotes else {
                throw StockError.noDataAvailable
            }
            
            var stockDataArray: [StockData] = []
            
            for i in 0..<timestamps.count {
                if let open = quotes.open[i],
                   let high = quotes.high[i],
                   let low = quotes.low[i],
                   let close = quotes.close[i],
                   let volume = quotes.volume[i] {
                    
                    let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                    let stockData = StockData(
                        date: date,
                        open: open,
                        high: high,
                        low: low,
                        close: close,
                        volume: volume
                    )
                    stockDataArray.append(stockData)
                }
            }
            
            stockDataArray.sort { $0.date > $1.date }
            let extendedData = Array(stockDataArray.prefix(30))
            
            // Monthly data fetch
            let monthData = try await fetchYahooMonthlyData(symbol: symbol)
            
            return (extendedData, monthData)
        } catch {
            throw StockError.networkError
        }
    }
    
    private static func fetchNewsData(symbol: String) async throws -> [StockNews] {
        let baseURL = "https://query2.finance.yahoo.com/v1/finance/search"
        let urlString = "\(baseURL)?q=\(symbol)&quotesCount=0&newsCount=20&enableFuzzyQuery=false&enableEnhancedTrivialQuery=false"
        
        print("📰 Fetching news for \(symbol) from URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StockError.invalidResponse
            }
            
            struct SearchResponse: Codable {
                let news: [NewsItem]?
                
                struct NewsItem: Codable {
                    let title: String
                    let link: String
                    let providerPublishTime: TimeInterval
                }
            }
            
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            
            // 현재 시간 기준으로 2일 전 타임스탬프 계산
            let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60).timeIntervalSince1970
            
            let filteredNews = (searchResponse.news ?? [])
                .filter { $0.providerPublishTime > twoDaysAgo }
                .sorted { $0.providerPublishTime > $1.providerPublishTime }
                .prefix(8)
                .map { item in
                    let date = Date(timeIntervalSince1970: item.providerPublishTime)
                    return StockNews(
                        title: item.title,
                        pubDate: formatNewsDate(date),
                        link: item.link
                    )
                }
            
            return Array(filteredNews)
        } catch {
            print("❌ Error fetching news: \(error)")
            return []
        }
    }
    
    private static func fetchMarketSentiment() async throws -> MarketSentiment {
        let vixData = try await fetchVIXData()
        let fearAndGreedData = try await fetchFearAndGreedIndex()
        
        return MarketSentiment(
            vix: vixData,
            fearAndGreedIndex: fearAndGreedData
        )
    }
    
    private static func fetchVIXData() async throws -> Double {
        let baseURL = "https://query2.finance.yahoo.com/v8/finance/chart/"
        let symbol = "%5EVIX"  // ^VIX encoded
        let urlString = "\(baseURL)\(symbol)?interval=1d&range=1d"
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        
        guard let result = yahooResponse.chart.result?.first,
              let quotes = result.indicators.quote.first,
              let lastClose = quotes.close.last ?? quotes.open.last else {
            throw StockError.noDataAvailable
        }
        
        return formatPrice(lastClose ?? 0.0)
    }
    
    private static func fetchFearAndGreedIndex() async throws -> Double {
        let vix = try await fetchVIXData()
        let normalized = max(0, min(100, (50 - vix) * 2.5))
        return formatPrice(normalized)
    }
    
    private static func fetchYahooMonthlyData(symbol: String) async throws -> [StockData] {
        let now = Int(Date().timeIntervalSince1970)
        let oneMonthAgo = Int((Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()).timeIntervalSince1970)
        
        let baseURL = "https://query2.finance.yahoo.com/v8/finance/chart/"
        let urlString = "\(baseURL)\(symbol)?period1=\(oneMonthAgo)&period2=\(now)&interval=1d"
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StockError.invalidResponse
        }
        
        let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        
        guard let result = yahooResponse.chart.result?.first else {
            throw StockError.invalidResponse
        }
        
        let timestamps = result.timestamp
        let quotes = result.indicators.quote.first
        
        guard let quotes = quotes else {
            throw StockError.noDataAvailable
        }
        
        var stockDataArray: [StockData] = []
        
        for i in 0..<timestamps.count {
            if let open = quotes.open[i],
               let high = quotes.high[i],
               let low = quotes.low[i],
               let close = quotes.close[i],
               let volume = quotes.volume[i] {
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                let stockData = StockData(
                    date: date,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
                stockDataArray.append(stockData)
            }
        }
        
        stockDataArray.sort { $0.date > $1.date }
        return stockDataArray
    }
    
    private static func createCompactJSONOutput(dailyData: [StockData], monthlyData: [StockData], newsData: [StockNews], marketSentiment: MarketSentiment) -> [String: Any] {
            // 일간 데이터 변환
            let dailyValues = dailyData.map { data -> [Any] in
                return [
                    formatDateWithMinutes(data.date),
                    formatPrice4(data.open),
                    formatPrice4(data.close),
                    formatPrice4(data.high),
                    formatPrice4(data.low),
                    data.volume
                ]
            }
            
            // 월간 데이터 변환
            let monthlyValues = monthlyData.map { data -> [Any] in
                return [
                    formatDateOnly(data.date),
                    formatPrice4(data.open),
                    formatPrice4(data.close),
                    formatPrice4(data.high),
                    formatPrice4(data.low),
                    data.volume
                ]
            }
            
            // 뉴스 데이터
            let newsItems = newsData.map { ["t": $0.title] }
            
            // 최종 JSON 구조
            return [
                "c": ["d","o","c","h","l","v"],
                "p": formatPrice2(dailyData.first?.close ?? 0.0),
                "d": [
                    "d": dailyValues,
                    "m": monthlyValues
                ],
                "n": newsItems,
                "Mkt Sentiment": [
                    "VIX": formatPrice2(marketSentiment.vix),
                    "F&G": formatPrice2(marketSentiment.fearAndGreedIndex)
                ]
            ]
        }
    private static func formatPrice4(_ price: Double) -> String {
            // 소수점 4자리까지 버림 후 문자열로 변환
            let truncated = floor(price * 10000) / 10000
            return String(format: "%.4f", truncated)
        }
        
    private static func formatPrice2(_ price: Double) -> String {
            // 소수점 2자리까지 버림 후 문자열로 변환
            let truncated = floor(price * 100) / 100
            return String(format: "%.2f", truncated)
        }
    
    private static func printOptimizedJSONOutput(_ dailyData: [StockData], _ monthlyData: [StockData], _ newsData: [StockNews], _ marketSentiment: MarketSentiment) {
            do {
                let compactData = createCompactJSONOutput(
                    dailyData: dailyData,
                    monthlyData: monthlyData,
                    newsData: newsData,
                    marketSentiment: marketSentiment
                )
                
                // JSONSerialization 옵션 수정
                let jsonData = try JSONSerialization.data(withJSONObject: compactData, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("\n📊 Compact JSON Output:")
                    print(jsonString)
                }
            } catch {
                print("Error converting to JSON: \(error)")
            }
        }
    
    public static func formatDateWithMinutes(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    public static func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private static func formatPrice(_ price: Double) -> Double {
        return floor(price * 10000) / 10000
    }
    
    private static func formatCurrentPrice(_ price: Double) -> Double {
        return floor(price * 100) / 100
    }
    
    private static func formatNewsDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute {
            return "\(max(minutes, 1))m ago"
        } else {
            return "Just now"
        }
    }
}
