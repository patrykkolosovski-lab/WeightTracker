import Foundation

struct MetricsSaveResult {
    let profile: ProfileRecord
    let weightEntry: WeightEntryRecord
}

/// Encapsulates metrics/profile mutations so `AppStore` does not need to know
/// about persistence details.
struct MetricsCoordinator {
    /// Persists the profile locally and upserts today's weight entry from the
    /// same form submission.
    func saveMetrics(
        form: MetricsFormState,
        userIDString: String,
        existingEntries: [WeightEntryRecord],
        localDataStore: LocalDataStore
    ) throws -> MetricsSaveResult {
        let input = try form.makeInput()

        let savedProfile = try localDataStore.saveProfile(
            input: input,
            userIDString: userIDString,
            needsSync: true
        )
        let weightEntrySource: WeightEntrySource = existingEntries.isEmpty ? .onboarding : .metricsAdjustment
        let savedWeightEntry = try localDataStore.upsertEntryForDay(
            WeightEntryDraft(
                date: .now,
                weightKilograms: input.currentWeightKilograms,
                notes: "",
                source: weightEntrySource
            ),
            userIDString: userIDString,
            needsSync: true
        )

        try? localDataStore.markProfileCompleted(userIDString: userIDString)

        return MetricsSaveResult(
            profile: savedProfile,
            weightEntry: savedWeightEntry
        )
    }

    /// Saves a preferred unit change without changing the canonical kg/cm
    /// values already stored in the profile.
    func updatePreferredUnitSystem(
        _ unitSystem: UnitSystem,
        userIDString: String,
        currentProfile: ProfileRecord,
        latestWeightKilograms: Double,
        localDataStore: LocalDataStore
    ) throws {
        let input = MetricsInput(
            age: currentProfile.age,
            heightCentimeters: currentProfile.heightCentimeters,
            currentWeightKilograms: latestWeightKilograms,
            targetWeightKilograms: currentProfile.targetWeightKilograms,
            activityLevel: currentProfile.activityLevel,
            goalMode: currentProfile.goalMode,
            genericGoalType: currentProfile.goalType,
            weeklyPaceKilograms: currentProfile.resolvedWeeklyPaceKilograms,
            targetDate: currentProfile.targetDate,
            formulaSex: currentProfile.formulaSex,
            unitSystem: unitSystem
        )

        _ = try localDataStore.saveProfile(
            input: input,
            userIDString: userIDString,
            needsSync: true
        )
    }
}
