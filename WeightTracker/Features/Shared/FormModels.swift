import Foundation

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
            targetDate: profile?.targetDate ?? (Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now),
            activityLevel: profile?.activityLevel ?? .moderate,
            goalMode: profile?.goalMode ?? .generic,
            genericGoalType: profile?.goalType ?? .loss,
            weeklyPaceOption: WeeklyPaceOption.from(kilogramsPerWeek: profile?.resolvedWeeklyPaceKilograms),
            formulaSex: profile?.formulaSex ?? .female,
            unitSystem: unitSystem
        )
    }

    func makeInput() -> MetricsInput? {
        guard let age = Int(ageText),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let currentWeight = Double(currentWeightText.replacingOccurrences(of: ",", with: ".")),
              age > 0, height > 0, currentWeight > 0 else {
            return nil
        }

        let currentWeightKilograms = UnitConverter.weightToKilograms(currentWeight, unitSystem: unitSystem)
        let heightCentimeters = UnitConverter.heightToCentimeters(height, unitSystem: unitSystem)
        let parsedTargetWeight = Double(targetWeightText.replacingOccurrences(of: ",", with: "."))

        switch goalMode {
        case .target:
            guard let targetWeight = parsedTargetWeight, targetWeight > 0 else { return nil }
            let targetWeightKilograms = UnitConverter.weightToKilograms(targetWeight, unitSystem: unitSystem)
            let targetDay = Calendar.current.startOfDay(for: targetDate)
            let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
            guard targetDay >= tomorrow, abs(targetWeightKilograms - currentWeightKilograms) > 0.01 else { return nil }

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
            let targetWeightKilograms = parsedTargetWeight.map {
                UnitConverter.weightToKilograms($0, unitSystem: unitSystem)
            } ?? currentWeightKilograms

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
