import Foundation

struct MetricsFormState {
    var ageText: String
    var heightText: String
    var currentWeightText: String
    var targetWeightText: String
    var activityLevel: ActivityLevel
    var goalType: GoalType
    var formulaSex: FormulaSex
    var unitSystem: UnitSystem

    static func empty(unitSystem: UnitSystem = .metric) -> MetricsFormState {
        MetricsFormState(
            ageText: "",
            heightText: "",
            currentWeightText: "",
            targetWeightText: "",
            activityLevel: .moderate,
            goalType: .loss,
            formulaSex: .female,
            unitSystem: unitSystem
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
            activityLevel: profile?.activityLevel ?? .moderate,
            goalType: profile?.goalType ?? .loss,
            formulaSex: profile?.formulaSex ?? .female,
            unitSystem: unitSystem
        )
    }

    func makeInput() -> MetricsInput? {
        guard let age = Int(ageText),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let currentWeight = Double(currentWeightText.replacingOccurrences(of: ",", with: ".")),
              let targetWeight = Double(targetWeightText.replacingOccurrences(of: ",", with: ".")),
              age > 0, height > 0, currentWeight > 0, targetWeight > 0 else {
            return nil
        }

        return MetricsInput(
            age: age,
            heightCentimeters: UnitConverter.heightToCentimeters(height, unitSystem: unitSystem),
            currentWeightKilograms: UnitConverter.weightToKilograms(currentWeight, unitSystem: unitSystem),
            targetWeightKilograms: UnitConverter.weightToKilograms(targetWeight, unitSystem: unitSystem),
            activityLevel: activityLevel,
            goalType: goalType,
            formulaSex: formulaSex,
            unitSystem: unitSystem
        )
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

    func makeDraft(source: WeightEntrySource) -> WeightEntryDraft? {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")), weight > 0 else {
            return nil
        }

        return WeightEntryDraft(
            date: date,
            weightKilograms: UnitConverter.weightToKilograms(weight, unitSystem: unitSystem),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source
        )
    }
}
