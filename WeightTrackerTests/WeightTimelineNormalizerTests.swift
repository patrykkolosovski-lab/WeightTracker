import XCTest
@testable import WeightTracker

@MainActor
final class WeightTimelineNormalizerTests: XCTestCase {
    func testNormalizeRecordsKeepsNewestEntryPerDay() {
        let keptEntry = WeightEntryRecord(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            userIDString: LocalDataStore.primaryUserIDString,
            date: makeDate(year: 2026, month: 3, day: 29, hour: 18),
            weightKilograms: 82,
            notes: "",
            source: .manual,
            createdAt: makeDate(year: 2026, month: 3, day: 29, hour: 18),
            updatedAt: makeDate(year: 2026, month: 3, day: 29, hour: 19)
        )
        let duplicateEntry = WeightEntryRecord(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            userIDString: LocalDataStore.primaryUserIDString,
            date: makeDate(year: 2026, month: 3, day: 29, hour: 8),
            weightKilograms: 83,
            notes: "",
            source: .manual,
            createdAt: makeDate(year: 2026, month: 3, day: 29, hour: 8),
            updatedAt: makeDate(year: 2026, month: 3, day: 29, hour: 9)
        )
        let earlierDayEntry = WeightEntryRecord(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            userIDString: LocalDataStore.primaryUserIDString,
            date: makeDate(year: 2026, month: 3, day: 28, hour: 7),
            weightKilograms: 84,
            notes: "",
            source: .manual,
            createdAt: makeDate(year: 2026, month: 3, day: 28, hour: 7),
            updatedAt: makeDate(year: 2026, month: 3, day: 28, hour: 8)
        )

        let result = WeightTimelineNormalizer.normalize(records: [keptEntry, earlierDayEntry, duplicateEntry])

        XCTAssertEqual(result.canonicalEntries.map(\.id), [earlierDayEntry.id, keptEntry.id])
        XCTAssertEqual(result.duplicateEntryIDs, [duplicateEntry.id])
        XCTAssertEqual(result.survivorEntryIDs, [keptEntry.id])
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
