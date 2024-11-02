
//  ViewModelsYahooChartModels.swift

import SwiftUI
import Combine
import Charts

// MARK: - Response Models
public struct YahooChartResponse: Codable {
    let chart: YahooChart
}

public struct YahooChart: Codable {
    let result: [YahooChartResult]?
    let error: YahooError?
}

public struct YahooError: Codable {
    let code: String
    let description: String
}

public struct YahooChartResult: Codable {
    let meta: YahooMeta
    let timestamp: [Int]?
    let indicators: YahooIndicators
}

public struct YahooMeta: Codable {
    let currency: String
    let symbol: String
    let regularMarketPrice: Double?
    let previousClose: Double?
    let marketState: String?         // PRE, REGULAR, POST
    let postMarketPrice: Double?     // 장 마감 후 가격
    let postMarketTime: Int?         // 장 마감 후 시간
    let preMarketPrice: Double?      // 장 시작 전 가격
    let preMarketTime: Int?          // 장 시작 전 시간
}

public struct YahooIndicators: Codable {
    let quote: [YahooQuote]
    let adjclose: [YahooAdjClose]?
}

public struct YahooQuote: Codable {
    let high: [Double?]?
    let low: [Double?]?
    let open: [Double?]?
    let close: [Double?]?
    let volume: [Int?]?
}

public struct YahooAdjClose: Codable {
    let adjclose: [Double?]?
}

// MARK: - Data Point Model
public struct YahooChartDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int
    public let sessionType: SessionType
    
    public enum SessionType {
        case preMarket
        case regular
        case postMarket
    }
}

// MARK: - Chart Period
public enum ChartPeriod: String, CaseIterable {
    case oneDay = "1D"
    case fiveDay = "5D"
    case oneMonth = "1M"
    case sixMonth = "6M"
    case yearToDate = "YTD"
    case oneYear = "1Y"
    case fiveYear = "5Y"
    case max = "MAX"
    
    public var interval: String {
        switch self {
        case .oneDay: return "2m"
        case .fiveDay: return "15m"
        case .oneMonth: return "30m"
        case .sixMonth: return "1d"
        case .yearToDate: return "1d"
        case .oneYear: return "1d"
        case .fiveYear: return "1wk"
        case .max: return "1mo"
        }
    }
    
    public var range: String {
        switch self {
        case .oneDay: return "1d"
        case .fiveDay: return "5d"
        case .oneMonth: return "1mo"
        case .sixMonth: return "6mo"
        case .yearToDate: return "ytd"
        case .oneYear: return "1y"
        case .fiveYear: return "5y"
        case .max: return "max"
        }
    }
}

// MARK: - View Model
public class YahooChartViewModel: ObservableObject {
    @Published public var chartData: [ChartPeriod: [YahooChartDataPoint]] = [:]
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var currentSymbol: String = ""
    @Published public var marketState: String = ""
    @Published public var currentPrice: Double = 0.0
    
    public init() {}
    
    public func fetchChartData(symbol: String, period: ChartPeriod) {
        isLoading = true
        error = nil
        currentSymbol = symbol
        
        let baseUrl = "https://query1.finance.yahoo.com/v8/finance/chart/"
        let queryParams = "interval=\(period.interval)&range=\(period.range)&includePrePost=true"
        
        guard let url = URL(string: "\(baseUrl)\(symbol)?\(queryParams)") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.isLoading = false
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    self?.isLoading = false
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
                    if let chartError = response.chart.error {
                        self?.error = chartError.description
                        self?.isLoading = false
                        return
                    }
                    
                    guard let result = response.chart.result?.first,
                          let timestamps = result.timestamp,
                          let quote = result.indicators.quote.first else {
                        self?.error = "Invalid data format"
                        self?.isLoading = false
                        return
                    }
                    
                    self?.marketState = result.meta.marketState ?? "REGULAR"
                    
                    var chartPoints: [YahooChartDataPoint] = []
                    
                    // 정규장 데이터 처리
                    for i in 0..<timestamps.count {
                        guard let open = quote.open?[i] ?? quote.close?[i],
                              let high = quote.high?[i] ?? quote.close?[i],
                              let low = quote.low?[i] ?? quote.close?[i],
                              let close = quote.close?[i] ?? quote.open?[i] else {
                            continue
                        }
                        
                        let volume = quote.volume?[i] ?? 0
                        
                        let point = YahooChartDataPoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                            open: open,
                            high: high,
                            low: low,
                            close: close,
                            volume: volume,
                            sessionType: .regular
                        )
                        chartPoints.append(point)
                    }
                    
                    // 장 마감 후 데이터 추가
                    if let postMarketPrice = result.meta.postMarketPrice,
                       let postMarketTime = result.meta.postMarketTime {
                        let postPoint = YahooChartDataPoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(postMarketTime)),
                            open: postMarketPrice,
                            high: postMarketPrice,
                            low: postMarketPrice,
                            close: postMarketPrice,
                            volume: 0,
                            sessionType: .postMarket
                        )
                        chartPoints.append(postPoint)
                    }
                    
                    // 장 시작 전 데이터 추가
                    if let preMarketPrice = result.meta.preMarketPrice,
                       let preMarketTime = result.meta.preMarketTime {
                        let prePoint = YahooChartDataPoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(preMarketTime)),
                            open: preMarketPrice,
                            high: preMarketPrice,
                            low: preMarketPrice,
                            close: preMarketPrice,
                            volume: 0,
                            sessionType: .preMarket
                        )
                        chartPoints.append(prePoint)
                    }
                    
                    // 현재 가격 업데이트
                    if let postMarketPrice = result.meta.postMarketPrice,
                       result.meta.marketState == "POST" {
                        self?.currentPrice = postMarketPrice
                    } else if let preMarketPrice = result.meta.preMarketPrice,
                              result.meta.marketState == "PRE" {
                        self?.currentPrice = preMarketPrice
                    } else {
                        self?.currentPrice = result.meta.regularMarketPrice ?? chartPoints.last?.close ?? 0.0
                    }
                    
                    chartPoints.sort { $0.timestamp < $1.timestamp }
                    self?.chartData[period] = chartPoints
                    self?.isLoading = false
                    
                } catch {
                    print("Decoding error: \(error)")
                    self?.error = "Failed to decode data: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }.resume()
    }
}
