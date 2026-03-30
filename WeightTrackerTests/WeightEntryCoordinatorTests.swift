import SwiftData
import XCTest
@testable import WeightTracker

@MainActor
final class WeightEntryCoordinatorTests: XCTestCase {
    func testMetricsCoordinatorUpsertsSingleTodayEntry() throws {
        let store = try makeLocalDataStore()
        let coordinator = MetricsCoordinator()
        let userIDString = LocalDataStore.primaryUserIDString

        var firstForm = MetricsFormState.empty(unitSystem: .metric)
        firstForm.ageText = "34"
        firstForm.setHeightText("180")
        firstForm.setCurrentWeightText("85")
        firstForm.setTargetWeightText("80")

        _ = try coordinator.saveMetrics(
            form: firstForm,
            userIDString: userIDString,
            existingEntries: [],
            localDataStore: store
        )

        var secondForm = firstForm
        secondForm.setCurrentWeightText("84")

        _ = try coordinator.saveMetrics(
            form: secondForm,
            userIDString: userIDString,
            existingEntries: try store.fetchEntries(userIDString: userIDString),
            localDataStore: store
        )

        let entries = try store.fetchEntries(userIDString: userIDString)
        XCTAssertEqual(entries.count, 1)
        guard let entry = entries.first else {
            return XCTFail("Expected a single saved entry")
        }
        XCTAssertEqual(entry.weightKilograms, 84, accuracy: 0.001)
        XCTAssertEqual(entry.source, .metricsAdjustment)
    }

    func testWeightEntryCoordinatorRejectsSecondEntryForSameDay() throws {
        let store = try makeLocalDataStore()
        let coordinator = WeightEntryCoordinator()
        let userIDString = LocalDataStore.primaryUserIDString
        let existingDay = makeDate(year: 2026, month: 3, day: 29, hour: 8)

        _ = try store.addEntry(
            WeightEntryDraft(
                date: existingDay,
                weightKilograms: 80,
                notes: "",
                source: .manual
            ),
            userIDString: userIDString,
            needsSync: false
        )

        let duplicateForm = WeightEntryFormState(
            date: makeDate(year: 2026, month: 3, day: 29, hour: 19),
            weightText: "79",
            notes: "",
            unitSystem: .metric
        )

        XCTAssertThrowsError(
            try coordinator.saveWeightEntry(
                form: duplicateForm,
                activeWeightEntryID: nil,
                userIDString: userIDString,
                localDataStore: store
            )
        ) { error in
            guard case ValidationError.duplicateWeightEntryDate = error else {
                return XCTFail("Expected duplicateWeightEntryDate, got \(error)")
            }
        }
    }

    private func makeLocalDataStore() throws -> LocalDataStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AccountRecord.self,
            LocalAccountStateRecord.self,
            ProfileRecord.self,
            WeightEntryRecord.self,
            configurations: configuration
        )
        return LocalDataStore(modelContext: ModelContext(container))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
