// Views/ HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: StockViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showSuggestions = false
    @State private var showDeleteConfirmation = false
    @State private var symbolToDelete: String?
    @State private var showTickerGuide = false
    @State private var showLanguageSheet = false
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    searchBarSection
                    recentSearchesSection
                }
            }
            .navigationTitle("AI Analysis")
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
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil,
                                             from: nil,
                                             for: nil)
                showSuggestions = false
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguageListView(selectedLanguage: $viewModel.selectedLanguage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var languageSelector: some View {
        HStack {
            Spacer()
            Button(action: {
                showLanguageSheet = true
            }) {
                HStack {
                    Text(viewModel.selectedLanguage.name)
                        .lineLimit(1)
                    Image(systemName: "globe")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var searchBarSection: some View {
        VStack(alignment: .leading) {
            // 첫 번째 줄: 검색창과 번역 버튼
            HStack(spacing: 8) {
                TextField("Enter stock symbol or company name", text: $viewModel.stockSymbol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .submitLabel(.search)
                    .focused($isTextFieldFocused)
                    .onChange(of: viewModel.stockSymbol) { oldValue, newValue in  // 수정된 부분
                        handleSearchTextChange(newValue)
                    }
                    .onSubmit {
                        if !viewModel.stockSymbol.isEmpty {
                            startSearch()
                        }
                    }
                
                if !viewModel.stockSymbol.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                // 번역 버튼
                Button(action: {
                    showLanguageSheet = true
                }) {
                    Text(viewModel.selectedLanguage.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: 80)  // 번역 버튼 너비 고정
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // 두 번째 줄: AI 분석 버튼
            Button(action: {
                if !viewModel.stockSymbol.isEmpty {
                    startSearch()
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("AI Stock Analysis")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(viewModel.stockSymbol.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.stockSymbol.isEmpty)
            
            if showTickerGuide {
                Text("Stock ticker should be 1-5 letters (e.g., AAPL, MSFT, GOOGL)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            
            if showSuggestions && !viewModel.searchResults.isEmpty && isTextFieldFocused {
                searchSuggestionsView
            }
            
            if viewModel.isSearching {
                ProgressView()
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
    
    private var searchSuggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.searchResults, id: \.symbol) { result in
                    Button(action: {
                        selectSearchResult(result.symbol)
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
    
    private var recentSearchesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                let filteredFavorites = viewModel.favorites.filter { $0 != viewModel.stockSymbol }
                if !filteredFavorites.isEmpty {
                    ForEach(filteredFavorites, id: \.self) { symbol in
                        Text(symbol)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(15)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                // 검색창에 심볼만 입력
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
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
    }
    
    // MARK: - Helper Functions
    
    private func handleSearchTextChange(_ newValue: String) {
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
    
    private func clearSearch() {
        viewModel.stockSymbol = ""
        showSuggestions = false
        showTickerGuide = false
    }
    
    private func selectSearchResult(_ symbol: String) {
        viewModel.stockSymbol = symbol
        showSuggestions = false
        isTextFieldFocused = false
        startSearch()
    }
    
    private func startSearch() {
        isTextFieldFocused = false
        Task {
            let success = await viewModel.fetchStockData()
            if success {
                await MainActor.run {
                    selectedTab = 1  // Analysis 탭으로 전환
                }
            } else {
                await MainActor.run {
                    isTextFieldFocused = true
                }
            }
        }
    }
}

struct LanguageListView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLanguage: AppLanguage
    @State private var searchText = ""
    
    var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return AppLanguage.allLanguages
        }
        return AppLanguage.allLanguages.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredLanguages) { language in
                    Button(action: {
                        selectedLanguage = language
                        dismiss()
                    }) {
                        HStack {
                            Text(language.name)
                                .font(.body)
                            Spacer()
                            if language.code == selectedLanguage.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .searchable(text: $searchText, prompt: Text("Search languages"))
            .navigationTitle("Select Language")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}
