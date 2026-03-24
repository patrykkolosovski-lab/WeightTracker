//
//  WeightTrackerApp.swift
//  WeightTracker
//
//  Created by Patryk Kolosovski on 24/03/2026.
//

import SwiftData
import SwiftUI

@main
struct WeightTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [AccountRecord.self, ProfileRecord.self, WeightEntryRecord.self])
    }
}
