import Foundation

private enum ValidationBounds {
    static let ageRange = 13...120
    static let heightCentimetersRange = 100.0...250.0
    static let weightKilogramsRange = 25.0...400.0
}

struct MetricsFormState {
    var ageText: String
    var heightText: String
    var currentWeightText: String
    var targetWeightText: String
    var targetDate: Date
    var activityLevel: ActivityLevel
    var goalMode: GoalMode
    var genericGoalType: GoalType
    var weeklyPaceOption: WeeklyPaceOption
    var formulaSex: FormulaSex
    var unitSystem: UnitSystem
    private var heightCentimetersValue: Double?
    private var currentWeightKilogramsValue: Double?
    private var targetWeightKilogramsValue: Double?

    static func empty(unitSystem: UnitSystem = .metric) -> MetricsFormState {
        MetricsFormState(
            ageText: "",
            heightText: "",
            currentWeightText: "",
            targetWeightText: "",
            targetDate: Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now,
            activityLevel: .moderate,
            goalMode: .generic,
            genericGoalType: .loss,
            weeklyPaceOption: .half,
            formulaSex: .female,
            unitSystem: unitSystem,
            heightCentimetersValue: nil,
            currentWeightKilogramsValue: nil,
            targetWeightKilogramsValue: nil
        )
    }

    static func from(profile: ProfileRecord?, currentWeightKilograms: Double?) -> MetricsFormState {
        let unitSystem = profile?.preferredUnitSystem ?? .metric

        return MetricsFormState(
            ageText: profile.map { String($0.age) } ?? "",
            heightText: profile.map {
                Formatters.decimalInput(UnitConverter.heightToDisplay($0.heightCentimeters, unitSystem: unitSystem))
            } ?? "",
            currentWeightText: currentWeightKilograms.map {
                Formatters.decimalInput(UnitConverter.weightToDisplay($0, unitSystem: unitSystem))
            } ?? "",
            targetWeightText: profile.map {
                Formatters.decimalInput(UnitConverter.weightToDisplay($0.targetWeightKilograms, unitSystem: unitSystem))
            } ?? "",
            targetDate: profile?.targetDate ?? (Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now),
            activityLevel: profile?.activityLevel ?? .moderate,
            goalMode: profile?.goalMode ?? .generic,
            genericGoalType: profile?.goalType ?? .loss,
            weeklyPaceOption: WeeklyPaceOption.from(kilogramsPerWeek: profile?.resolvedWeeklyPaceKilograms),
            formulaSex: profile?.formulaSex ?? .female,
            unitSystem: unitSystem,
            heightCentimetersValue: profile?.heightCentimeters,
            currentWeightKilogramsValue: currentWeightKilograms,
            targetWeightKilogramsValue: profile?.targetWeightKilograms
        )
    }

    func makeInput() throws -> MetricsInput {
        guard let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)),
              ValidationBounds.ageRange.contains(age) else {
            throw ValidationError.invalidAge
        }

        let heightCentimeters = try validatedMeasurement(
            text: heightText,
            storedBaseValue: heightCentimetersValue,
            range: ValidationBounds.heightCentimetersRange,
            emptyError: .invalidHeight,
            rangeError: .invalidHeight
        )
        let currentWeightKilograms = try validatedMeasurement(
            text: currentWeightText,
            storedBaseValue: currentWeightKilogramsValue,
            range: ValidationBounds.weightKilogramsRange,
            emptyError: .invalidCurrentWeight,
            rangeError: .invalidCurrentWeight
        )
        let parsedTargetWeight = try optionalValidatedMeasurement(
            text: targetWeightText,
            storedBaseValue: targetWeightKilogramsValue,
            range: ValidationBounds.weightKilogramsRange,
            rangeError: .invalidTargetWeight
        )

        switch goalMode {
        case .target:
            guard let targetWeightKilograms = parsedTargetWeight else {
                throw ValidationError.invalidTargetWeight
            }
            let targetDay = Calendar.current.startOfDay(for: targetDate)
            let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
            guard targetDay >= tomorrow else {
                throw ValidationError.invalidTargetDate
            }
            guard abs(targetWeightKilograms - currentWeightKilograms) > 0.01 else {
                throw ValidationError.targetWeightMatchesCurrentWeight
            }

            return MetricsInput(
                age: age,
                heightCentimeters: heightCentimeters,
                currentWeightKilograms: currentWeightKilograms,
                targetWeightKilograms: targetWeightKilograms,
                activityLevel: activityLevel,
                goalMode: .target,
                genericGoalType: targetWeightKilograms < currentWeightKilograms ? .loss : .gain,
                weeklyPaceKilograms: nil,
                targetDate: targetDay,
                formulaSex: formulaSex,
                unitSystem: unitSystem
            )
        case .generic:
            let targetWeightKilograms = parsedTargetWeight ?? currentWeightKilograms

            return MetricsInput(
                age: age,
                heightCentimeters: heightCentimeters,
                currentWeightKilograms: currentWeightKilograms,
                targetWeightKilograms: targetWeightKilograms,
                activityLevel: activityLevel,
                goalMode: .generic,
                genericGoalType: genericGoalType,
                weeklyPaceKilograms: genericGoalType == .maintenance ? nil : weeklyPaceOption.kilogramsPerWeek,
                targetDate: nil,
                formulaSex: formulaSex,
                unitSystem: unitSystem
            )
        }
    }

    mutating func setUnitSystem(_ newUnitSystem: UnitSystem) {
        guard unitSystem != newUnitSystem else { return }
        unitSystem = newUnitSystem
        refreshDisplayedMeasurements()
    }

    mutating func setHeightText(_ text: String) {
        heightText = text
        heightCentimetersValue = Self.parsedHeight(text, unitSystem: unitSystem)
    }

    mutating func setCurrentWeightText(_ text: String) {
        currentWeightText = text
        currentWeightKilogramsValue = Self.parsedWeight(text, unitSystem: unitSystem)
    }

    mutating func setTargetWeightText(_ text: String) {
        targetWeightText = text
        targetWeightKilogramsValue = Self.parsedWeight(text, unitSystem: unitSystem)
    }

    private func validatedMeasurement(
        text: String,
        storedBaseValue: Double?,
        range: ClosedRange<Double>,
        emptyError: ValidationError,
        rangeError: ValidationError
    ) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let storedBaseValue else {
            throw emptyError
        }

        guard range.contains(storedBaseValue) else {
            throw rangeError
        }

        return storedBaseValue
    }

    private func optionalValidatedMeasurement(
        text: String,
        storedBaseValue: Double?,
        range: ClosedRange<Double>,
        rangeError: ValidationError
    ) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let storedBaseValue else {
            throw rangeError
        }
        guard range.contains(storedBaseValue) else {
            throw rangeError
        }
        return storedBaseValue
    }

    private mutating func refreshDisplayedMeasurements() {
        if let heightCentimetersValue {
            heightText = Formatters.decimalInput(UnitConverter.heightToDisplay(heightCentimetersValue, unitSystem: unitSystem))
        }

        if let currentWeightKilogramsValue {
            currentWeightText = Formatters.decimalInput(UnitConverter.weightToDisplay(currentWeightKilogramsValue, unitSystem: unitSystem))
        }

        if let targetWeightKilogramsValue {
            targetWeightText = Formatters.decimalInput(UnitConverter.weightToDisplay(targetWeightKilogramsValue, unitSystem: unitSystem))
        }
    }

    private static func parsedWeight(_ text: String, unitSystem: UnitSystem) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            return nil
        }

        switch unitSystem {
        case .metric:
            return value
        case .imperial:
            return value / 2.2046226218
        }
    }

    private static func parsedHeight(_ text: String, unitSystem: UnitSystem) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            return nil
        }

        switch unitSystem {
        case .metric:
            return value
        case .imperial:
            return value * 2.54
        }
    }
}

struct WeightEntryFormState {
    var date: Date
    var weightText: String
    var notes: String
    var unitSystem: UnitSystem

    static func new(latestWeightKilograms: Double?, unitSystem: UnitSystem) -> WeightEntryFormState {
        WeightEntryFormState(
            date: .now,
            weightText: latestWeightKilograms.map {
                Formatters.decimalInput(UnitConverter.weightToDisplay($0, unitSystem: unitSystem))
            } ?? "",
            notes: "",
            unitSystem: unitSystem
        )
    }

    static func from(entry: WeightEntryRecord, unitSystem: UnitSystem) -> WeightEntryFormState {
        WeightEntryFormState(
            date: entry.date,
            weightText: Formatters.decimalInput(UnitConverter.weightToDisplay(entry.weightKilograms, unitSystem: unitSystem)),
            notes: entry.notes,
            unitSystem: unitSystem
        )
    }

    func makeDraft(source: WeightEntrySource) throws -> WeightEntryDraft {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")), weight > 0 else {
            throw ValidationError.invalidWeightEntry
        }

        let weightKilograms = UnitConverter.weightToKilograms(weight, unitSystem: unitSystem)
        guard ValidationBounds.weightKilogramsRange.contains(weightKilograms) else {
            throw ValidationError.invalidWeightEntry
        }

        return WeightEntryDraft(
            date: date,
            weightKilograms: weightKilograms,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source
        )
    }
}
