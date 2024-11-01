
//  Components/YahooFinanceChartView.swift
import SwiftUI
import Charts

struct YahooFinanceChartView: View {
    @StateObject private var viewModel: YahooChartViewModel
    @State private var selectedPeriod: ChartPeriod = .oneDay
    @State private var selectedPoint: YahooChartDataPoint?
    @State private var tooltipPosition: CGFloat = 0
    let symbol: String
    @Binding var currentPrice: Double
    
    init(symbol: String, currentPrice: Binding<Double>) {
        self.symbol = symbol
        self._currentPrice = currentPrice
        self._viewModel = StateObject(wrappedValue: YahooChartViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 차트 영역
            ZStack(alignment: .topLeading) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if let data = viewModel.chartData[selectedPeriod], !data.isEmpty {  // !data.isEmpty 조건 추가
                    chartContent(data)
                } else {
                    ProgressView()  // 데이터 로딩 중일 때는 ProgressView 표시
                        .onAppear {
                            viewModel.fetchChartData(symbol: symbol, period: selectedPeriod)
                        }
                }
            }
            .frame(height: 250)
            .background(Color(.systemBackground))
            .padding(.horizontal, 12) // 차트 영역의 좌우 패딩 조정
            .padding(.bottom, 16)
            
            // 구분선
            Divider()
                .padding(.horizontal)
            
            // 기간 선택 버튼
            ScrollView(.horizontal, showsIndicators: false) {
                periodSelector
                    .padding(.vertical, 8)
            }
        }
    }
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        Text(error)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    private var noDataView: some View {
        Text("No data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func chartContent(_ data: [YahooChartDataPoint]) -> some View {
        let validData = data.filter { $0.close > 0 }
        
        return ZStack(alignment: .topLeading) {
            Chart {
                ForEach(validData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.close)
                    )
                    .foregroundStyle(Color.blue)
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.close)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                if let selectedPoint = selectedPoint {
                    RuleMark(x: .value("Time", selectedPoint.timestamp))
                        .foregroundStyle(Color.gray.opacity(0.5))
                    
                    PointMark(
                        x: .value("Time", selectedPoint.timestamp),
                        y: .value("Price", selectedPoint.close)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: calculateYAxisRange(data: validData))
            .chartXAxis(.hidden) // X축 숨기기
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let price = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(price))")  // 정수로 표시
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Tooltip overlay
            if let point = selectedPoint {
                tooltipView(for: point)
                    .offset(x: max(0, min(tooltipPosition - 40, UIScreen.main.bounds.width - 100)))
                    .offset(y: 20)
            }
            
            // Gesture overlay
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleChartInteraction(value, in: geometry, data: validData)
                            }
                    )
            }
        }
        .clipped()
    }
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {  // spacing 증가
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        selectedPoint = nil
                        if viewModel.chartData[period] == nil {
                            viewModel.fetchChartData(symbol: symbol, period: period)
                        }
                    }) {
                        Text(period.rawValue)
                            .font(.system(size: 16, weight: .medium))  // 폰트 크기 증가
                            .padding(.horizontal, 12)  // 가로 패딩 증가
                            .padding(.vertical, 8)    // 세로 패딩 증가
                            .frame(minWidth: 60)      // 최소 너비 설정
                            .background(
                                selectedPeriod == period ?
                                    Color.blue :
                                    Color.gray.opacity(0.2)
                            )
                            .foregroundColor(
                                selectedPeriod == period ?
                                    .white :
                                    .primary
                            )
                            .cornerRadius(8)          // 모서리 반경 증가
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func tooltipView(for point: YahooChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDateTime(point.timestamp, for: selectedPeriod))
                .font(.caption2)
            Text("$\(formatPrice(point.close))")
                .font(.caption)
                .bold()
        }
        .padding(6)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .shadow(radius: 2)
    }
    
    private func handleChartInteraction(_ value: DragGesture.Value, in geometry: GeometryProxy, data: [YahooChartDataPoint]) {
        let currentX = value.location.x
        tooltipPosition = currentX
        
        guard currentX >= 0, currentX <= geometry.size.width,
              let startDate = data.first?.timestamp,
              let endDate = data.last?.timestamp else { return }
        
        let timeRange = endDate.timeIntervalSince(startDate)
        let xRatio = currentX / geometry.size.width
        let targetDate = startDate.addingTimeInterval(timeRange * xRatio)
        
        selectedPoint = data.min(by: {
            abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate))
        })
        
        if let point = selectedPoint {
            currentPrice = point.close
        }
    }
    
    private func calculateYAxisRange(data: [YahooChartDataPoint]) -> ClosedRange<Double> {
        guard !data.isEmpty else { return 0...100 }
        let values = data.map { $0.close }
        let minPrice = values.min() ?? 0
        let maxPrice = values.max() ?? 100
        let padding = (maxPrice - minPrice) * 0.05
        return (minPrice - padding)...(maxPrice + padding)
    }
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "%.2f", price)
    }
    
    private func formatDateTime(_ date: Date, for period: ChartPeriod) -> String {
        let formatter = DateFormatter()
        
        switch period {
        case .oneDay:
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        case .fiveDay:
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        case .oneMonth, .sixMonth:
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        default:
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
    
    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedPeriod {
        case .oneDay:
            formatter.dateFormat = "HH:mm"
        case .fiveDay:
            formatter.dateFormat = "MM/dd HH:mm"
        case .oneMonth, .sixMonth:
            formatter.dateFormat = "MM/dd"
        default:
            formatter.dateFormat = "yyyy/MM"
        }
        
        return formatter.string(from: date)
    }
}
