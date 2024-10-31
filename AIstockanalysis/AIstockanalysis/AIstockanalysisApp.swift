//
//  AIstockanalysisApp.swift
//  AIstockanalysis
//
//  Created by sunghwan ki on 10/31/24.
//

import SwiftUI

@main
struct AIstockanalysisApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
