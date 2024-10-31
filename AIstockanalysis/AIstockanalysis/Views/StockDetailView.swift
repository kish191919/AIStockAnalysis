// Views/StockDetailView.swift
import SwiftUI
import Charts

public struct StockDetailView: View {
    let symbol: String
    let dayData: [StockData]
    let monthData: [StockData]
    
    public init(symbol: String, dayData: [StockData], monthData: [StockData]) {
        self.symbol = symbol
        self.dayData = dayData
        self.monthData = monthData
    }
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 최신 데이터 표시
                if let latestData = dayData.first {
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
                }
                
                // 월간 차트
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
            .padding()
        }
        .navigationTitle(symbol)
    }
}
