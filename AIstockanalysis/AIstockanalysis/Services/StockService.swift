// Services/StockService.swift
import Foundation

public class StockService {
    private static var finnhubApiKey: String {
        guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["FinnhubAPIKey"] as? String else {
            fatalError("Couldn't find FinnhubAPIKey in APIKeys.plist")
        }
        return apiKey
    }
    
    public static func fetchStockData(symbol: String) async throws -> (dayData: [StockData], monthData: [StockData]) {
        do {
            print("⬇️ Attempting to fetch data from Finnhub for symbol: \(symbol)")
            let currentQuote = try await fetchQuote(symbol: symbol)
            print("📊 Successfully fetched current quote from Finnhub")
            
            let monthData = try await fetchCandles(symbol: symbol)
            print("📈 Successfully fetched historical data from Finnhub")
            print("📝 Finnhub Data Summary:")
            print("- Current day data: 1 record")
            print("- Historical data: \(monthData.count) records")
            
            let dayData = [StockData(
                date: Date(),
                open: currentQuote.o,
                high: currentQuote.h,
                low: currentQuote.l,
                close: currentQuote.c,
                volume: 0
            )]
            
            return (dayData, monthData)
            
        } catch {
            print("❌ Finnhub fetch failed: \(error.localizedDescription)")
            print("⬇️ Falling back to Yahoo Finance")
            let (dayData, monthData) = try await fetchFromYahoo(symbol: symbol)
            print("📝 Yahoo Finance Data Summary:")
            print("- Current day data: \(dayData.count) record")
            print("- Historical data: \(monthData.count) records")
            return (dayData, monthData)
        }
    }
    
    private static func fetchQuote(symbol: String) async throws -> QuoteResponse {
        print("🔍 Fetching current quote from Finnhub for \(symbol)")
        let baseURL = "https://finnhub.io/api/v1/quote"
        let urlString = "\(baseURL)?symbol=\(symbol)&token=\(finnhubApiKey)"
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw StockError.apiError("Finnhub returned status code: \(httpResponse.statusCode)")
        }
        
        let quote = try JSONDecoder().decode(QuoteResponse.self, from: data)
        return quote
    }
    
    private static func fetchCandles(symbol: String) async throws -> [StockData] {
        print("🔍 Fetching historical data from Finnhub for \(symbol)")
        let now = Int(Date().timeIntervalSince1970)
        let oneMonthAgo = Int((Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()).timeIntervalSince1970)
        
        let baseURL = "https://finnhub.io/api/v1/stock/candle"
        let urlString = "\(baseURL)?symbol=\(symbol)&resolution=D&from=\(oneMonthAgo)&to=\(now)&token=\(finnhubApiKey)"
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidSymbol
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw StockError.apiError("Finnhub returned status code: \(httpResponse.statusCode)")
        }
        
        struct CandlesResponse: Codable {
            let c: [Double]
            let h: [Double]
            let l: [Double]
            let o: [Double]
            let t: [Int]
            let v: [Int]
            let s: String
        }
        
        let candlesResponse = try JSONDecoder().decode(CandlesResponse.self, from: data)
        guard candlesResponse.s == "ok" else {
            throw StockError.noDataAvailable
        }
        
        var stockDataArray: [StockData] = []
        
        for i in 0..<candlesResponse.t.count {
            let stockData = StockData(
                date: Date(timeIntervalSince1970: TimeInterval(candlesResponse.t[i])),
                open: candlesResponse.o[i],
                high: candlesResponse.h[i],
                low: candlesResponse.l[i],
                close: candlesResponse.c[i],
                volume: candlesResponse.v[i]
            )
            stockDataArray.append(stockData)
        }
        
        stockDataArray.sort { $0.date > $1.date }
        return stockDataArray
    }
    
    private static func fetchFromYahoo(symbol: String) async throws -> (dayData: [StockData], monthData: [StockData]) {
        print("🔍 Fetching data from Yahoo Finance for \(symbol)")
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
        
        guard !stockDataArray.isEmpty else {
            throw StockError.noDataAvailable
        }
        
        stockDataArray.sort { $0.date > $1.date }
        let dayData = [stockDataArray[0]]
        let monthData = stockDataArray
        
        return (dayData, monthData)
    }
}

struct QuoteResponse: Codable {
    let c: Double  // Current price
    let h: Double  // High price of the day
    let l: Double  // Low price of the day
    let o: Double  // Open price of the day
    let pc: Double // Previous close price
    let t: Int    // Timestamp
}
