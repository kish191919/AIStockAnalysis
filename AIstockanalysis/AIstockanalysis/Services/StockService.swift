// Services/StockService.swift
import Foundation

public class StockService {
    public static func fetchStockData(symbol: String) async throws -> (dayData: [StockData], monthData: [StockData], newsData: [StockNews]) {
            print("\n🔍 Fetching data from Yahoo Finance for \(symbol)")
            let (extendedData, monthData) = try await fetchAllData(symbol: symbol)
            let newsData = try await fetchNewsData(symbol: symbol)
            
            // 최적화된 데이터 구조 생성
            let optimizedData = createOptimizedOutput(dailyData: extendedData, monthlyData: monthData, newsData: newsData)
            printOptimizedJSONOutput(optimizedData)
            
            return (extendedData, monthData, newsData)  // newsData 포함하여 반환
        }
    
    private static func fetchNewsData(symbol: String) async throws -> [StockNews] {
            // Yahoo Finance Search API URL
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
                
                print("📡 News Response Status Code: \(httpResponse.statusCode)")
                
                // Search API 응답 구조체
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
                
                // NewsItem을 StockNews로 변환하고 필터링
                let filteredNews = (searchResponse.news ?? [])
                    .filter { item in
                        // 2일 이내의 뉴스만 필터링
                        item.providerPublishTime > twoDaysAgo
                    }
                    .sorted { item1, item2 in
                        // 최신순으로 정렬
                        item1.providerPublishTime > item2.providerPublishTime
                    }
                    .prefix(10) // 최대 10개까지만 표시
                    .map { item in
                        let date = Date(timeIntervalSince1970: item.providerPublishTime)
                        return StockNews(
                            title: item.title,
                            pubDate: formatNewsDate(date),
                            link: item.link
                        )
                    }
                
                print("📰 Filtered \(filteredNews.count) recent news items")
                return Array(filteredNews)
                
            } catch {
                print("❌ Error fetching news: \(error)")
                if let decodingError = error as? DecodingError {
                    print("Decoding Error: \(decodingError)")
                }
                return []
            }
        }
    
    // 뉴스 날짜 포맷팅을 위한 헬퍼 메서드
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
    
    // Alternative News API 엔드포인트 (위의 방법이 실패할 경우 사용)
        private static func fetchAlternativeNewsData(symbol: String) async throws -> [StockNews] {
            let baseURL = "https://query2.finance.yahoo.com/v2/finance/news"
            let urlString = "\(baseURL)?symbol=\(symbol)&count=10"
            
            guard let url = URL(string: urlString) else {
                throw StockError.invalidSymbol
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            // 디버깅을 위해 응답 데이터 출력
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Alternative News Response Data: \(responseString)")
            }
            
            // 여기서 실제 응답 구조에 맞게 파싱 로직 구현
            return []
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
    
    public static func createOptimizedOutput(dailyData: [StockData], monthlyData: [StockData], newsData: [StockNews]) -> OptimizedStockData {
            let columns = ["date", "open", "close", "high", "low", "volume"]
            
            let dailyValues = dailyData.map { data -> [Any] in
                return [
                    formatDateWithMinutes(data.date),
                    formatPrice(data.open),
                    formatPrice(data.close),
                    formatPrice(data.high),
                    formatPrice(data.low),
                    data.volume
                ]
            }
            
            let monthlyValues = monthlyData.map { data -> [Any] in
                return [
                    formatDateOnly(data.date),
                    formatPrice(data.open),
                    formatPrice(data.close),
                    formatPrice(data.high),
                    formatPrice(data.low),
                    data.volume
                ]
            }
            
            let currentPrice = formatCurrentPrice(dailyData.first?.close ?? 0.0)
            
            // 뉴스 제목만 포함
            let simplifiedNews = newsData.map { SimpleNewsTitle(title: $0.title) }
            
            return OptimizedStockData(
                columns: columns,
                currentPrice: currentPrice,
                data: OptimizedStockData.DataValues(
                    daily: dailyValues,
                    monthly: monthlyValues
                ),
                news: simplifiedNews
            )
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
    
    private static func printOptimizedJSONOutput(_ optimizedData: OptimizedStockData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(optimizedData)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n📊 Optimized Stock Data JSON Output:")
                print(jsonString)
            }
        } catch {
            print("Error converting to JSON: \(error)")
        }
    }
    
    public static func formatDateWithMinutes(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"  // 초 단위 제거
            return formatter.string(from: date)
        }
        
        public static func formatDateOnly(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        
    private static func formatPrice(_ price: Double) -> Double {
            // 소수점 4자리까지 버림
            return floor(price * 10000) / 10000
        }
        
        private static func formatCurrentPrice(_ price: Double) -> Double {
            // 소수점 2자리까지 버림
            return floor(price * 100) / 100
        }

}

// Extension for number formatting
extension Int {
    func formatWithCommas() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}
