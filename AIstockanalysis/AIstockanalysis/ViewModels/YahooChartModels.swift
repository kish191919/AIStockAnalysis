//
//  ViewModelsYahooChartModels.swift

import SwiftUI
import Combine
import Charts

// ViewModel and Data Models
public struct YahooChartDataPoint: Identifiable {  // 이름 변경
    public let id = UUID()
    public let timestamp: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int
}

public class YahooChartViewModel: ObservableObject {
    @Published public var chartData: [ChartPeriod: [YahooChartDataPoint]] = [:]  // 타입 변경
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var currentSymbol: String = ""
    
    public init() {}
    
    public func fetchChartData(symbol: String, period: ChartPeriod) {
        isLoading = true
        error = nil
        currentSymbol = symbol
        
        let baseUrl = "https://query1.finance.yahoo.com/v8/finance/chart/"
        let queryParams = "interval=\(period.interval)&range=\(period.range)"
        
        guard let url = URL(string: "\(baseUrl)\(symbol)?\(queryParams)") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
                
                // ViewModel 내의 fetchChartData 메서드에서 아래 부분을 수정
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
                    
                    var chartPoints: [YahooChartDataPoint] = []
                    
                    for i in 0..<timestamps.count {
                        // 수정된 부분: 옵셔널 체이닝 및 기본값 처리
                        let open = quote.open?[i] ?? quote.close?[i] ?? 0.0
                        let high = quote.high?[i] ?? quote.close?[i] ?? 0.0
                        let low = quote.low?[i] ?? quote.close?[i] ?? 0.0
                        let close = quote.close?[i] ?? quote.open?[i] ?? 0.0
                        let volume = quote.volume?[i] ?? 0
                        
                        let point = YahooChartDataPoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                            open: open,
                            high: high,
                            low: low,
                            close: close,
                            volume: volume
                        )
                        chartPoints.append(point)
                    }
                    
                    self?.chartData[period] = chartPoints
                    self?.isLoading = false
                } catch {
                    self?.error = "Failed to decode data: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }.resume()
    }
}


// Chart Period Enum
public enum ChartPeriod: String, CaseIterable {
    case oneDay = "1D"
    case fiveDay = "5D"
    case oneMonth = "1M"
    case sixMonth = "6M"
    case yearToDate = "YTD"
    case oneYear = "1Y"
    case twoYear = "2Y"
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
        case .twoYear: return "1wk"
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
        case .twoYear: return "2y"
        case .fiveYear: return "5y"
        case .max: return "max"
        }
    }
}

// Response Models
struct YahooChartResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooChartResult]?
    let error: YahooError?
}

struct YahooError: Codable {
    let code: String
    let description: String
}

struct YahooChartResult: Codable {
    let meta: YahooMeta
    let timestamp: [Int]?
    let indicators: YahooIndicators
}

struct YahooMeta: Codable {
    let currency: String
    let symbol: String
    let regularMarketPrice: Double?
    let previousClose: Double?
}

struct YahooIndicators: Codable {
    let quote: [YahooQuote]
}

struct YahooQuote: Codable {
    let high: [Double?]?
    let low: [Double?]?
    let open: [Double?]?
    let close: [Double?]?
    let volume: [Int?]?
}
