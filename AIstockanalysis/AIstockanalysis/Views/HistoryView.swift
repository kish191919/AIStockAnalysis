// Views/HistoryView.swift
import SwiftUI
import CoreData
import Combine
import Foundation

struct HistoryView: View {
   @Environment(\.managedObjectContext) private var viewContext
   @FetchRequest(
       sortDescriptors: [
           SortDescriptor(\AnalysisHistoryEntity.symbol, order: .forward),
           SortDescriptor(\AnalysisHistoryEntity.timestamp, order: .reverse)
       ],
       animation: .default
   ) private var historyItems: FetchedResults<AnalysisHistoryEntity>
   
   @AppStorage("pinnedSymbols") private var pinnedSymbols: [String] = []
   @AppStorage("lastAccessedSymbols") private var lastAccessedSymbols: [String] = []
   @State private var expandedFolders: Set<String> = []
   @State private var expandedItems: Set<UUID> = []
    
   
   private let gridColumns = [
       GridItem(.flexible(), spacing: 10),
       GridItem(.flexible(), spacing: 10)
   ]
   
   private func groupedHistory() -> [String: [AnalysisHistoryEntity]] {
       Dictionary(grouping: Array(historyItems)) { $0.symbol ?? "" }
   }
   
   var sortedSymbols: [String] {
       let allSymbols = Array(Set(historyItems.map { $0.symbol ?? "" }))
       
       // 고정된 심볼, 최근 접근 순서, 알파벳 순으로 정렬
       return allSymbols.sorted { symbol1, symbol2 in
           if pinnedSymbols.contains(symbol1) != pinnedSymbols.contains(symbol2) {
               return pinnedSymbols.contains(symbol1)
           }
           
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
   
   var body: some View {
       NavigationView {
           ScrollView(.vertical, showsIndicators: true) {
               VStack(alignment: .leading, spacing: 10) {
                   folderGridView
                   analysisListView
               }
           }
           .navigationTitle("Analysis History")
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
   
   private func folderButton(for symbol: String) -> some View {
       let itemCount = groupedHistory()[symbol]?.count ?? 0
       return FolderButton(
           symbol: symbol,
           isExpanded: expandedFolders.contains(symbol),
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
       // 해당 심볼의 모든 히스토리 삭제
       let itemsToDelete = historyItems.filter { $0.symbol == symbol }
       itemsToDelete.forEach { viewContext.delete($0) }
       
       // 고정 목록에서도 제거
       pinnedSymbols.removeAll { $0 == symbol }
       
       // 최근 접근 목록에서도 제거
       lastAccessedSymbols.removeAll { $0 == symbol }
       
       // 확장된 폴더 목록에서도 제거
       expandedFolders.remove(symbol)
       
       try? viewContext.save()
   }
   
   private func toggleFolder(_ symbol: String) {
       if expandedFolders.contains(symbol) {
           expandedFolders.remove(symbol)
       } else {
           expandedFolders.insert(symbol)
           // 폴더를 열 때 최근 접근 목록 업데이트
           updateLastAccessed(symbol)
       }
   }
   
   private func toggleItem(_ id: UUID) {
       if expandedItems.contains(id) {
           expandedItems.remove(id)
       } else {
           expandedItems.insert(id)
       }
   }
   
   private func updateLastAccessed(_ symbol: String) {
       lastAccessedSymbols.removeAll { $0 == symbol }
       lastAccessedSymbols.insert(symbol, at: 0)
       if lastAccessedSymbols.count > 20 {  // 최대 20개만 유지
           lastAccessedSymbols.removeLast()
       }
   }
}

struct FolderButton: View {
   let symbol: String
   let isExpanded: Bool
   let itemCount: Int
   let isPinned: Bool
   let action: () -> Void
   
   var body: some View {
       Button(action: action) {
           HStack {
               Image(systemName: isExpanded ? "folder.fill" : "folder")
               Text(symbol)
               Text("(\(itemCount))")
                   .font(.caption)
                   .foregroundColor(.gray)
               if isPinned {
                   Image(systemName: "pin.fill")
                       .font(.caption)
               }
               Spacer()
           }
           .padding(.horizontal, 12)
           .padding(.vertical, 8)
           .frame(maxWidth: .infinity)
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

