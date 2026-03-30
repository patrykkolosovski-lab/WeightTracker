import Foundation

/// Handles manual weight-entry mutations and date-level integrity rules.
struct WeightEntryCoordinator {
    /// Saves or edits a weight entry after validating that the selected date is
    /// not in the future and does not already contain another entry.
    func saveWeightEntry(
        form: WeightEntryFormState,
        activeWeightEntryID: UUID?,
        userIDString: String,
        localDataStore: LocalDataStore
    ) throws -> WeightEntryRecord? {
        let today = Calendar.current.startOfDay(for: .now)
        let selectedDay = Calendar.current.startOfDay(for: form.date)
        guard selectedDay <= today else {
            throw ValidationError.futureWeightEntryDate
        }

        let draft = try form.makeDraft(source: activeWeightEntryID == nil ? .manual : .metricsAdjustment)

        if let existingEntry = try localDataStore.entry(on: form.date, userIDString: userIDString),
           existingEntry.id != activeWeightEntryID {
            throw ValidationError.duplicateWeightEntryDate
        }

        if let activeWeightEntryID {
            return try localDataStore.updateEntry(
                id: activeWeightEntryID,
                userIDString: userIDString,
                with: draft,
                needsSync: true
            )
        }

        return try localDataStore.addEntry(
            draft,
            userIDString: userIDString,
            needsSync: true
        )
    }
}
