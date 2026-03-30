//
//  WeightTrackerApp.swift
//  WeightTracker
//
//  Created by Patryk Kolosovski on 24/03/2026.
//

import SwiftData
import SwiftUI

@main
/// Application entry point that boots the shared SwiftData container used by the
/// local-first BeFit data layer.
struct WeightTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [AccountRecord.self, LocalAccountStateRecord.self, ProfileRecord.self, WeightEntryRecord.self])
    }
}
