import XCTest
@testable import WeightTracker

@MainActor
final class FormValidationTests: XCTestCase {
    func testMetricsUnitSwitchPreservesCanonicalMeasurements() throws {
        var form = MetricsFormState.empty(unitSystem: .metric)
        form.ageText = "31"
        form.setHeightText("180")
        form.setCurrentWeightText("82.4")
        form.setTargetWeightText("76.2")

        let original = try form.makeInput()

        form.setUnitSystem(.imperial)
        form.setUnitSystem(.metric)

        let roundTripped = try form.makeInput()

        XCTAssertEqual(roundTripped.heightCentimeters, original.heightCentimeters, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.currentWeightKilograms, original.currentWeightKilograms, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.targetWeightKilograms, original.targetWeightKilograms, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.unitSystem, .metric)
    }

    func testMetricsRejectTargetDateEarlierThanTomorrow() {
        var form = MetricsFormState.empty(unitSystem: .metric)
        form.ageText = "29"
        form.setHeightText("172")
        form.setCurrentWeightText("80")
        form.setTargetWeightText("74")
        form.goalMode = .target
        form.targetDate = Calendar.current.startOfDay(for: .now)

        XCTAssertThrowsError(try form.makeInput()) { error in
            guard case ValidationError.invalidTargetDate = error else {
                return XCTFail("Expected invalidTargetDate, got \(error)")
            }
        }
    }

    func testMetricsRejectImpossibleImperialWeight() {
        var form = MetricsFormState.empty(unitSystem: .imperial)
        form.ageText = "37"
        form.setHeightText("72")
        form.setCurrentWeightText("1000")

        XCTAssertThrowsError(try form.makeInput()) { error in
            guard case ValidationError.invalidCurrentWeight = error else {
                return XCTFail("Expected invalidCurrentWeight, got \(error)")
            }
        }
    }

    func testWeightEntryDraftConvertsImperialInputToKilograms() throws {
        let form = WeightEntryFormState(
            date: Date(timeIntervalSince1970: 1000),
            weightText: "220.46",
            notes: "steady",
            unitSystem: .imperial
        )

        let draft = try form.makeDraft(source: .manual)

        XCTAssertEqual(draft.weightKilograms, 100, accuracy: 0.05)
        XCTAssertEqual(draft.notes, "steady")
        XCTAssertEqual(draft.source, .manual)
    }
}
