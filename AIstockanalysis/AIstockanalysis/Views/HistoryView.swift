// Views/HistoryView.swift
import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\AnalysisHistoryEntity.symbol, order: .forward),
            SortDescriptor(\AnalysisHistoryEntity.timestamp, order: .reverse)
        ],
        animation: .default
    ) private var historyItems: FetchedResults<AnalysisHistoryEntity>
    
    @State private var expandedFolders: Set<String> = []
    @State private var expandedItems: Set<UUID> = []
    
    private func groupedHistory() -> [String: [AnalysisHistoryEntity]] {
        Dictionary(grouping: Array(historyItems)) { $0.symbol ?? "" }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    folderScrollView
                    analysisListView
                }
            }
            .navigationTitle("Analysis History")
        }
    }
    
    private var folderScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(groupedHistory().keys.sorted(), id: \.self) { symbol in
                    folderButton(for: symbol)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private func folderButton(for symbol: String) -> some View {
        let itemCount = groupedHistory()[symbol]?.count ?? 0
        return FolderButton(
            symbol: symbol,
            isExpanded: expandedFolders.contains(symbol),
            itemCount: itemCount
        ) {
            toggleFolder(symbol)
        }
    }
    
    private var analysisListView: some View {
        ForEach(groupedHistory().keys.sorted(), id: \.self) { symbol in
            if expandedFolders.contains(symbol) {
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
    
    private func toggleFolder(_ symbol: String) {
        if expandedFolders.contains(symbol) {
            expandedFolders.remove(symbol)
        } else {
            expandedFolders.insert(symbol)
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                Text(symbol)
                Text("(\(itemCount))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isExpanded ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            )
        }
        .foregroundColor(isExpanded ? .blue : .primary)
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
