
//Models/StockData.swift
import Foundation

// MARK: - Data Models
public struct StockData: Identifiable {
    public let id = UUID()
    public let date: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int
    
    public init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Int) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

// 최적화된 데이터 응답을 위한 구조체
public struct OptimizedStockData: Codable {
    let columns: [String]
    let currentPrice: Double
    let data: DataValues
    let news: [SimpleNewsTitle]
    let marketSentiment: MarketSentiment  // 추가
    
    struct DataValues: Codable {
        let daily: [[CustomValue]]
        let monthly: [[CustomValue]]
        
        init(daily: [[Any]], monthly: [[Any]]) {
            self.daily = daily.map { row in
                row.map { CustomValue(value: $0) }
            }
            self.monthly = monthly.map { row in
                row.map { CustomValue(value: $0) }
            }
        }
    }
}

// Custom Value type for handling mixed types
struct CustomValue: Codable {
    let value: Any
    
    init(value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let double as Double:
            try container.encode(double)
        case let int as Int:
            try container.encode(int)
        default:
            try container.encode(String(describing: value))
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else {
            value = ""
        }
    }
}

public struct YahooFinanceResponse: Codable {
    public let chart: Chart
    
    public struct Chart: Codable {
        public let result: [Result]?
        public let error: ChartError?
        
        public struct Result: Codable {
            public let meta: Meta
            public let timestamp: [Int]
            public let indicators: Indicators
            
            public struct Meta: Codable {
                public let currency: String
                public let symbol: String
                public let regularMarketPrice: Double?
                public let previousClose: Double?
            }
            
            public struct Indicators: Codable {
                public let quote: [Quote]
                
                public struct Quote: Codable {
                    public let open: [Double?]
                    public let high: [Double?]
                    public let low: [Double?]
                    public let close: [Double?]
                    public let volume: [Int?]
                }
            }
        }
        
        public struct ChartError: Codable {
            public let code: String
            public let description: String
        }
    }
}

// MARK: - Error Types
public enum StockError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case noDataAvailable
    case invalidSymbol
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .noDataAvailable:
            return "No data available for this stock"
        case .invalidSymbol:
            return "Invalid stock symbol"
        case .networkError:
            return "Network connection error"
        }
    }
}

// StockData.swift 수정
public struct StockNews: Codable {
    let title: String
    let pubDate: String
    let link: String
}

// JSON 출력용 간단한 뉴스 구조체
public struct SimpleNewsTitle: Codable {
    let title: String
}

public struct MarketSentiment: Codable {
    let vix: Double
    let fearAndGreedIndex: Double
}
