
//Models/StockData.swift
import Foundation

// StockData에 Codable 추가
public struct StockData: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int
    
    enum CodingKeys: String, CodingKey {
        case id, date, open, high, low, close, volume
    }
    
    public init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Int) {
        self.id = UUID()
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
                public let marketState: String?  // PRE, REGULAR, POST 등의 시장 상태
                public let postMarketPrice: Double?  // 장 마감 후 가격
                public let postMarketTime: Int?     // 장 마감 후 시간
                public let preMarketPrice: Double?   // 장 시작 전 가격
                public let preMarketTime: Int?      // 장 시작 전 시간
            }
            
            public struct Indicators: Codable {
                public let quote: [Quote]
                public let adjclose: [AdjClose]?
                
                public struct Quote: Codable {
                    public let open: [Double?]
                    public let high: [Double?]
                    public let low: [Double?]
                    public let close: [Double?]
                    public let volume: [Int?]
                }
                
                public struct AdjClose: Codable {
                    public let adjclose: [Double?]
                }
            }
        }
        
        public struct ChartError: Codable {
            public let code: String
            public let description: String
        }
    }
}
