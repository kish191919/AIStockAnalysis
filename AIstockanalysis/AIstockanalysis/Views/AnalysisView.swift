// Views/AnalysisView.swift
import SwiftUI

struct AnalysisView: View {
   @EnvironmentObject private var viewModel: StockViewModel
   @FocusState private var isTextFieldFocused: Bool
   @State private var showDeleteConfirmation = false
   @State private var symbolToDelete: String?
   @State private var showSuggestions = false
   @State private var showTickerGuide = false
   
   var body: some View {
       NavigationView {
           ScrollView {
               VStack(spacing: 15) {
                   // 검색 바
                   VStack(alignment: .leading) {
                       HStack {
                           TextField("Enter stock symbol or company name", text: $viewModel.stockSymbol)
                               .textFieldStyle(RoundedBorderTextFieldStyle())
                               .autocapitalization(.none)
                               .submitLabel(.search)
                               .focused($isTextFieldFocused)
                               .onChange(of: viewModel.stockSymbol) { newValue in
                                   // 영문자만 입력 가능하도록 필터링
                                   let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
                                   if filtered != newValue {
                                       viewModel.stockSymbol = filtered
                                       showTickerGuide = true
                                   } else {
                                       showTickerGuide = filtered.count > 5 || (!filtered.isEmpty && !viewModel.validateSymbol(filtered))
                                   }
                                   viewModel.searchSymbol(query: filtered)
                                   showSuggestions = !filtered.isEmpty
                               }
                               .onSubmit {
                                   if !viewModel.stockSymbol.isEmpty {
                                       startSearch()
                                   }
                               }
                           
                           // 검색창 클리어 버튼
                           if !viewModel.stockSymbol.isEmpty {
                               Button(action: {
                                   viewModel.stockSymbol = ""
                                   showSuggestions = false
                                   showTickerGuide = false
                               }) {
                                   Image(systemName: "xmark.circle.fill")
                                       .foregroundColor(.gray)
                               }
                           }
                           
                           Button(action: {
                               if !viewModel.stockSymbol.isEmpty {
                                   startSearch()
                               }
                           }) {
                               Image(systemName: "magnifyingglass")
                                   .foregroundColor(.white)
                                   .padding(8)
                                   .background(viewModel.stockSymbol.isEmpty ? Color.gray : Color.blue)
                                   .cornerRadius(8)
                           }
                           .disabled(viewModel.stockSymbol.isEmpty)
                       }
                       
                       // Ticker 가이드 메시지
                       if showTickerGuide {
                           Text("Stock ticker should be 1-5 letters (e.g., AAPL, MSFT, GOOGL)")
                               .font(.caption)
                               .foregroundColor(.gray)
                               .padding(.horizontal, 4)
                               .padding(.top, 4)
                       }
                       
                       // 검색 제안 목록
                       if showSuggestions && !viewModel.searchResults.isEmpty && isTextFieldFocused {
                           ScrollView {
                               VStack(alignment: .leading, spacing: 8) {
                                   ForEach(viewModel.searchResults, id: \.symbol) { result in
                                       Button(action: {
                                           viewModel.stockSymbol = result.symbol
                                           showSuggestions = false
                                           isTextFieldFocused = false
                                           startSearch()
                                       }) {
                                           VStack(alignment: .leading, spacing: 4) {
                                               Text(result.symbol)
                                                   .font(.headline)
                                               Text(result.name)
                                                   .font(.subheadline)
                                                   .foregroundColor(.gray)
                                           }
                                           .frame(maxWidth: .infinity, alignment: .leading)
                                           .padding(.vertical, 4)
                                           .padding(.horizontal, 8)
                                       }
                                       Divider()
                                   }
                               }
                               .padding(.vertical, 8)
                           }
                           .frame(maxHeight: 200)
                           .background(Color(UIColor.systemBackground))
                           .cornerRadius(8)
                           .shadow(radius: 2)
                       }
                       
                       if viewModel.isSearching {
                           ProgressView()
                               .padding(.top, 8)
                       }
                   }
                   .padding(.horizontal)
                   
                   // 최근 검색 목록
                   if !viewModel.favorites.isEmpty {
                       ScrollView(.horizontal, showsIndicators: false) {
                           HStack(spacing: 10) {
                               ForEach(viewModel.favorites, id: \.self) { symbol in
                                   Text(symbol)
                                       .padding(.horizontal, 12)
                                       .padding(.vertical, 6)
                                       .background(Color.gray.opacity(0.1))
                                       .cornerRadius(15)
                                       .foregroundColor(.primary)
                                       .onTapGesture {
                                           viewModel.stockSymbol = symbol
                                       }
                                       .contextMenu {
                                           Button(role: .destructive) {
                                               symbolToDelete = symbol
                                               showDeleteConfirmation = true
                                           } label: {
                                               Label("Delete", systemImage: "trash")
                                           }
                                       }
                               }
                           }
                           .padding(.horizontal)
                       }
                   }
                   
                   if viewModel.isLoading {
                       ProgressView()
                           .scaleEffect(1.5)
                           .padding()
                   } else if !viewModel.stockSymbol.isEmpty && !viewModel.dayData.isEmpty {
                       ScrollView {
                           VStack(alignment: .leading, spacing: 8) {
                               HStack {
                                   Text(viewModel.stockSymbol)
                                       .font(.title)
                                       .bold()
                                   
                                   if let latestPrice = viewModel.dayData.first?.close {
                                       Text("$\(String(format: "%.2f", latestPrice))")
                                           .font(.title2)
                                   }
                               }
                               .padding(.horizontal)
                               
                               // Market Sentiment
                               HStack {
                                   SentimentCard(title: "VIX", value: viewModel.marketSentiment.vix)
                                   SentimentCard(title: "F&G Index", value: viewModel.marketSentiment.fearAndGreedIndex)
                               }
                               .padding(.horizontal)
                               
                               // Recent News Section
                               if !viewModel.newsData.isEmpty {
                                   VStack(alignment: .leading, spacing: 10) {
                                       Text("Recent News")
                                           .font(.headline)
                                           .padding(.horizontal)
                                           .padding(.top)
                                       
                                       ScrollView(.horizontal, showsIndicators: false) {
                                           HStack(spacing: 15) {
                                               ForEach(viewModel.newsData, id: \.title) { news in
                                                   NewsCard(news: news)
                                                       .frame(width: 300)
                                               }
                                           }
                                           .padding(.horizontal)
                                       }
                                   }
                               }
                           }
                       }
                   }

                   Spacer()
               }
           }
           .navigationTitle("Analysis")
           .alert("Delete Symbol", isPresented: $showDeleteConfirmation, presenting: symbolToDelete) { symbol in
               Button("Cancel", role: .cancel) { }
               Button("Delete", role: .destructive) {
                   withAnimation {
                       viewModel.removeFromFavorites(symbol)
                   }
               }
           } message: { symbol in
               Text("Are you sure you want to delete '\(symbol)' from recent searches?")
           }
           // 키보드 숨기기 개선
           .onTapGesture {
               UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil,
                                            from: nil,
                                            for: nil)
               showSuggestions = false
           }
       }
   }
   
   private func startSearch() {
       isTextFieldFocused = false
       Task {
           let success = await viewModel.fetchStockData()
           if !success {
               // 검색 실패 시 키보드 다시 표시
               await MainActor.run {
                   isTextFieldFocused = true
               }
           }
       }
   }
}

// MARK: - Supporting Views
struct SentimentCard: View {
   let title: String
   let value: Double
   
   var body: some View {
       VStack(alignment: .leading, spacing: 5) {
           Text(title)
               .font(.subheadline)
               .foregroundColor(.gray)
           Text(String(format: "%.2f", value))
               .font(.headline)
       }
       .padding()
       .background(Color.gray.opacity(0.1))
       .cornerRadius(8)
   }
}

struct NewsCard: View {
   let news: StockNews
   
   var body: some View {
       Link(destination: URL(string: news.link)!) {
           VStack(alignment: .leading, spacing: 5) {
               Text(news.title)
                   .font(.subheadline)
                   .lineLimit(2)
                   .foregroundColor(.primary)
               Text(news.pubDate)
                   .font(.caption)
                   .foregroundColor(.gray)
           }
           .padding()
           .frame(maxWidth: .infinity, alignment: .leading)
           .background(Color.gray.opacity(0.1))
           .cornerRadius(8)
       }
   }
}

#if DEBUG
struct AnalysisView_Previews: PreviewProvider {
   static var previews: some View {
       AnalysisView()
           .environmentObject(StockViewModel())
   }
}
#endif
