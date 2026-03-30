import Foundation

/// Startup-only logic for preparing the local dataset before the rest of the
/// app state is restored.
struct BootstrapCoordinator {
    /// Migrates legacy records into the single primary local namespace and
    /// normalizes the weight timeline before the UI reads from it.
    func prepareLocalData(localDataStore: LocalDataStore) throws -> String {
        try localDataStore.migrateAllDataToPrimaryUser()
        _ = try localDataStore.setActiveLocalAccount(
            userIDString: LocalDataStore.primaryUserIDString,
            email: ""
        )
        _ = try localDataStore.normalizeEntryTimeline(userIDString: LocalDataStore.primaryUserIDString)
        return LocalDataStore.primaryUserIDString
    }

    /// Maps persisted profile availability to the app's first destination.
    func destination(hasSavedProfile: Bool) -> RootDestination {
        hasSavedProfile ? .main : .metricsOnboarding
    }

    /// Collapses remote same-day duplicates so cloud hydration works from a
    /// canonical one-entry-per-day timeline.
    func normalizeRemoteEntries(
        _ entries: [SyncedWeightEntrySnapshot]
    ) -> WeightTimelineNormalizationResult<SyncedWeightEntrySnapshot> {
        WeightTimelineNormalizer.normalize(snapshots: entries)
    }
}
