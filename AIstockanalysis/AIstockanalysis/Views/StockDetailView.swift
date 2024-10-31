import SwiftUI
import Charts

public struct StockDetailView: View {
    let symbol: String
    let dayData: [StockData]
    let monthData: [StockData]
    let newsData: [StockNews]
    let marketSentiment: MarketSentiment
    
    public init(symbol: String, dayData: [StockData], monthData: [StockData], newsData: [StockNews], marketSentiment: MarketSentiment) {
        self.symbol = symbol
        self.dayData = dayData
        self.monthData = monthData
        self.newsData = newsData
        self.marketSentiment = marketSentiment
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stockPriceSection
                marketSentimentSection
                monthlyChartSection
                newsSection
            }
            .padding()
        }
        .navigationTitle(symbol)
    }
    
    private var stockPriceSection: some View {
        if let latestData = dayData.first {
            return AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    Text("Latest Data (\(dateFormatter.string(from: latestData.date)))")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Open")
                            Text("$\(String(format: "%.2f", latestData.open))")
                        }
                        VStack(alignment: .leading) {
                            Text("High")
                            Text("$\(String(format: "%.2f", latestData.high))")
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading) {
                            Text("Low")
                            Text("$\(String(format: "%.2f", latestData.low))")
                                .foregroundColor(.red)
                        }
                        VStack(alignment: .leading) {
                            Text("Close")
                            Text("$\(String(format: "%.2f", latestData.close))")
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    
                    Text("Volume: \(latestData.volume.formatted())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Performance")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(monthData) { data in
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Price", data.close)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
            } else {
                Text("Chart available in iOS 16+")
                    .foregroundColor(.gray)
            }
            
            if let firstPrice = monthData.last?.close,
               let lastPrice = monthData.first?.close {
                let change = ((lastPrice - firstPrice) / firstPrice) * 100
                Text("Monthly Change: \(String(format: "%.2f", change))%")
                    .foregroundColor(change >= 0 ? .green : .red)
                    .font(.caption)
                    .padding(.top)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Latest News")
                .font(.headline)
                .padding(.bottom, 5)
            
            if newsData.isEmpty {
                Text("No news available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(newsData, id: \.title) { news in
                    VStack(alignment: .leading, spacing: 5) {
                        Link(destination: URL(string: news.link) ?? URL(string: "https://finance.yahoo.com")!) {
                            Text(news.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Text(news.pubDate)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 5)
                    
                    if news.title != newsData.last?.title {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var marketSentimentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Market Sentiment")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("VIX Index")
                        .font(.subheadline)
                    Text(String(format: "%.2f", marketSentiment.vix))
                        .font(.title2)
                        .foregroundColor(vixColor(marketSentiment.vix))
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Fear & Greed")
                        .font(.subheadline)
                    Text(String(format: "%.1f", marketSentiment.fearAndGreedIndex))
                        .font(.title2)
                        .foregroundColor(fearAndGreedColor(marketSentiment.fearAndGreedIndex))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func vixColor(_ value: Double) -> Color {
        if value >= 30 {
            return .red
        } else if value >= 20 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func fearAndGreedColor(_ value: Double) -> Color {
        if value >= 75 {
            return .green
        } else if value >= 25 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
