// ContentView.swift
import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var stockViewModel = StockViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            AnalysisView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            MarketView()
                .tabItem {
                    Label("Market", systemImage: "building.columns.fill")
                }
                .tag(2)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(3)
            
            WatchListView()
                .tabItem {
                    Label("Watch List", systemImage: "star.fill")
                }
                .tag(4)
        }
        .environmentObject(stockViewModel)
        .accentColor(.blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
