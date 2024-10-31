// Models/StockData.swift
import Foundation

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
