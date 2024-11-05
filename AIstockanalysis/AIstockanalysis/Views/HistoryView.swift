// Views/HistoryView.swift
import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \AnalysisHistoryEntity.symbol, ascending: true),
            NSSortDescriptor(keyPath: \AnalysisHistoryEntity.timestamp, ascending: false)
        ],
        animation: .default
    ) private var historyItems: FetchedResults<AnalysisHistoryEntity>
    
    // CoreData 변경 감지를 위한 프로퍼티
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \AnalysisHistoryEntity.timestamp, ascending: false)
        ],
        animation: .default
    ) private var recentItems: FetchedResults<AnalysisHistoryEntity>
    
    @State private var pinnedSymbols: [String] = {
        if let data = UserDefaults.standard.data(forKey: "pinnedSymbols"),
           let symbols = try? JSONDecoder().decode([String].self, from: data) {
            return symbols
        }
        return []
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(pinnedSymbols) {
                UserDefaults.standard.set(encoded, forKey: "pinnedSymbols")
            }
        }
    }
    
    @State private var lastAccessedSymbols: [String] = {
        if let data = UserDefaults.standard.data(forKey: "lastAccessedSymbols"),
           let symbols = try? JSONDecoder().decode([String].self, from: data) {
            return symbols
        }
        return []
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(lastAccessedSymbols) {
                UserDefaults.standard.set(encoded, forKey: "lastAccessedSymbols")
            }
        }
    }
    
    @State private var expandedFolder: String? = nil
    @State private var expandedItems: Set<UUID> = []
    @State private var sortOption: SortOption = .alphabetical
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    enum SortOption {
        case alphabetical
        case recent
        
        var title: String {
            switch self {
            case .alphabetical: return "Alphabetical"
            case .recent: return "Recent First"
            }
        }
        
        var icon: String {
            switch self {
            case .alphabetical: return "textformat"
            case .recent: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    folderGridView
                    analysisListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Analysis History")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Menu {
                            Button(action: {
                                withAnimation {
                                    sortOption = .alphabetical
                                }
                            }) {
                                HStack {
                                    Image(systemName: "textformat")
                                    Text("Alphabetical")
                                    if sortOption == .alphabetical {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation {
                                    sortOption = .recent
                                }
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                    Text("Recent First")
                                    if sortOption == .recent {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sortOption == .alphabetical ? "textformat" : "clock")
                                    .foregroundColor(.blue)
                                    .frame(width: 20, height: 20)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func groupedHistory() -> [String: [AnalysisHistoryEntity]] {
        Dictionary(grouping: Array(historyItems)) { $0.symbol ?? "" }
    }
    
    private var sortedSymbols: [String] {
        let allSymbols = Array(Set(historyItems.map { $0.symbol ?? "" }))
        
        return allSymbols.sorted { symbol1, symbol2 in
            // 1. 고정된 심볼 우선
            if pinnedSymbols.contains(symbol1) != pinnedSymbols.contains(symbol2) {
                return pinnedSymbols.contains(symbol1)
            }
            
            // 2. 선택된 정렬 옵션에 따라 정렬
            switch sortOption {
            case .alphabetical:
                return symbol1 < symbol2
            case .recent:
                if let index1 = lastAccessedSymbols.firstIndex(of: symbol1),
                   let index2 = lastAccessedSymbols.firstIndex(of: symbol2) {
                    return index1 < index2
                }
                if lastAccessedSymbols.contains(symbol1) != lastAccessedSymbols.contains(symbol2) {
                    return lastAccessedSymbols.contains(symbol1)
                }
                return symbol1 < symbol2
            }
        }
    }
    
    private var folderGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(sortedSymbols, id: \.self) { symbol in
                folderButton(for: symbol)
            }
        }
        .padding()
    }
    
    private var analysisListView: some View {
        ForEach(sortedSymbols, id: \.self) { symbol in
            if expandedFolder == symbol {
                analysisGroup(for: symbol)
            }
        }
    }
    
    private func analysisGroup(for symbol: String) -> some View {
        Group {
            if let analyses = groupedHistory()[symbol] {
                VStack(spacing: 1) {
                    ForEach(analyses) { history in
                        HistoryItemExpandableView(
                            history: history,
                            isExpanded: expandedItems.contains(history.id ?? UUID())
                        ) {
                            toggleItem(history.id ?? UUID())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func folderButton(for symbol: String) -> some View {
        let itemCount = groupedHistory()[symbol]?.count ?? 0
        return FolderButton(
            symbol: symbol,
            isExpanded: expandedFolder == symbol,
            itemCount: itemCount,
            isPinned: pinnedSymbols.contains(symbol)
        ) {
            toggleFolder(symbol)
        }
        .contextMenu {
            if pinnedSymbols.contains(symbol) {
                Button(action: {
                    unpinSymbol(symbol)
                }) {
                    Label("Unpin", systemImage: "pin.slash")
                }
            } else {
                Button(action: {
                    pinSymbol(symbol)
                }) {
                    Label("Pin to Top", systemImage: "pin")
                }
            }
            
            Button(role: .destructive, action: {
                deleteSymbolHistory(symbol)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func pinSymbol(_ symbol: String) {
        if !pinnedSymbols.contains(symbol) {
            pinnedSymbols.append(symbol)
        }
    }
    
    private func unpinSymbol(_ symbol: String) {
        pinnedSymbols.removeAll { $0 == symbol }
    }
    
    private func deleteSymbolHistory(_ symbol: String) {
        let itemsToDelete = historyItems.filter { $0.symbol == symbol }
        itemsToDelete.forEach { viewContext.delete($0) }
        
        pinnedSymbols.removeAll { $0 == symbol }
        lastAccessedSymbols.removeAll { $0 == symbol }
        
        if expandedFolder == symbol {
            expandedFolder = nil
        }
        
        try? viewContext.save()
    }
    
    private func toggleFolder(_ symbol: String) {
        if expandedFolder == symbol {
            expandedFolder = nil
        } else {
            expandedFolder = symbol
        }
    }
    
    private func toggleItem(_ id: UUID) {
        if expandedItems.contains(id) {
            expandedItems.remove(id)
        } else {
            expandedItems.insert(id)
        }
    }
}

struct FolderButton: View {
    let symbol: String
    let isExpanded: Bool
    let itemCount: Int
    let isPinned: Bool
    let action: () -> Void
    
    private var logoUrl: URL? {
        URL(string: "https://logo.clearbit.com/\(getCompanyDomain(symbol)).com")
    }
    
    private func getCompanyDomain(_ symbol: String) -> String {
        let domainMap = [
            // 기술 기업
            "AAPL": "apple",
            "MSFT": "microsoft",
            "GOOGL": "google",
            "GOOG": "google",
            "AMZN": "amazon",
            "META": "meta",
            "TSLA": "tesla",
            "IBM": "ibm",
            "NVDA": "nvidia",
            "AMD": "amd",
            "INTC": "intel",
            "ORCL": "oracle",
            "CRM": "salesforce",
            "ADBE": "adobe",
            "CSCO": "cisco",
            "PYPL": "paypal",
            "UBER": "uber",
            "LYFT": "lyft",
            "SNAP": "snapchat",
            "SPOT": "spotify",
            "ZM": "zoom",
            "TWTR": "twitter",
            
            // 금융
            "V": "visa",
            "MA": "mastercard",
            "JPM": "jpmorgan",
            "BAC": "bankofamerica",
            "WFC": "wellsfargo",
            "GS": "goldmansachs",
            "MS": "morganstanley",
            "AXP": "americanexpress",
            "C": "citigroup",
            
            // 소매/소비재
            "WMT": "walmart",
            "TGT": "target",
            "COST": "costco",
            "HD": "homedepot",
            "SBUX": "starbucks",
            "MCD": "mcdonalds",
            "NKE": "nike",
            "LULU": "lululemon",
            "ETSY": "etsy",
            
            // 자동차
            "F": "ford",
            "GM": "gm",
            "TM": "toyota",
            "HMC": "honda",
            "RACE": "ferrari",
            
            // 통신
            "T": "att",
            "VZ": "verizon",
            "TMUS": "tmobile",
            
            // 미디어/엔터테인먼트
            "DIS": "disney",
            "CMCSA": "comcast",
            "NFLX": "netflix",
            "SONY": "sony",
            
            // 제약/의료
            "JNJ": "jnj",
            "PFE": "pfizer",
            "MRK": "merck",
            "ABBV": "abbvie",
            "BMY": "bms",
            
            // 소비재
            "PG": "pg",
            "KO": "coca-cola",
            "PEP": "pepsi",
            "UL": "unilever",
            "NVS": "novartis",
            
            // 아시아 기업
            "BABA": "alibaba",
            "TSM": "tsmc",
            "BIDU": "baidu",
            "9988.HK": "alibaba",
            "005930.KS": "samsung",
            "000660.KS": "skhynix",
            "035420.KS": "naver",
            "035720.KS": "kakao",
            
            // 항공/여행
            "DAL": "delta",
            "UAL": "united",
            "AAL": "americanairlines",
            "MAR": "marriott",
            "HLT": "hilton",
            
            // 에너지
            "XOM": "exxonmobil",
            "CVX": "chevron",
            "BP": "bp",
            "SHELL": "shell"
        ]
        return domainMap[symbol.uppercased()] ?? symbol.lowercased()
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 로고 이미지
                AsyncImage(url: logoUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(isExpanded ? .blue : .gray)
                }
                .frame(width: 24, height: 24)
                
                // 심볼과 아이템 카운트
                HStack(spacing: 4) {
                    Text(symbol)
                        .font(.system(.body, design: .monospaced))
                    Text("(\(itemCount))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 핀 아이콘
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // 확장 상태 표시
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(), value: isExpanded)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isExpanded ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HistoryItemExpandableView: View {
    let history: AnalysisHistoryEntity
    let isExpanded: Bool
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            historyHeader
            if isExpanded {
                reasonView
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var historyHeader: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(dateFormatter.string(from: history.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    DecisionBadge(decision: history.decisionType)
                }
                
                HStack {
                    Text("Confidence: \(history.confidence)%")
                    Spacer()
                    Text("$\(String(format: "%.2f", history.currentPrice))")
                    Image(systemName: "arrow.right")
                        .foregroundColor(.gray)
                    Text("$\(String(format: "%.2f", history.expectedPrice))")
                }
                .font(.subheadline)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var reasonView: some View {
        Text(history.reason ?? "")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}
