import Foundation

struct EffectiveGoal {
    let goalType: GoalType
    let weeklyPaceKilograms: Double?
    let targetWeightKilograms: Double?
    let targetDate: Date?
    let isAggressiveWarning: Bool
}

enum BMICalculator {
    static func value(weightKilograms: Double, heightCentimeters: Double) -> Double? {
        guard weightKilograms > 0, heightCentimeters > 0 else { return nil }
        let heightMeters = heightCentimeters / 100
        return weightKilograms / (heightMeters * heightMeters)
    }
}

enum CalorieCalculator {
    static func dailyTarget(
        age: Int,
        heightCentimeters: Double,
        weightKilograms: Double,
        activityLevel: ActivityLevel,
        formulaSex: FormulaSex,
        effectiveGoal: EffectiveGoal
    ) -> Int? {
        guard age > 0, heightCentimeters > 0, weightKilograms > 0 else { return nil }

        let baseConstant = formulaSex == .male ? 5.0 : -161.0
        let bmr = (10 * weightKilograms) + (6.25 * heightCentimeters) - (5 * Double(age)) + baseConstant
        let maintenanceCalories = bmr * activityLevel.multiplier

        let adjustedCalories: Double
        switch effectiveGoal.goalType {
        case .loss:
            let pace = effectiveGoal.weeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek
            adjustedCalories = maintenanceCalories - ((pace * 7_700) / 7)
        case .gain:
            let pace = effectiveGoal.weeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek
            adjustedCalories = maintenanceCalories + ((pace * 7_700) / 7)
        case .maintenance:
            adjustedCalories = maintenanceCalories
        }

        return Int(max(1_200, adjustedCalories).rounded())
    }
}

enum GoalProgressCalculator {
    static func progress(
        startWeightKilograms: Double?,
        currentWeightKilograms: Double?,
        effectiveGoal: EffectiveGoal?
    ) -> Double {
        guard let currentWeightKilograms,
              let effectiveGoal,
              let targetWeightKilograms = effectiveGoal.targetWeightKilograms else { return 0 }

        switch effectiveGoal.goalType {
        case .loss:
            guard let startWeightKilograms, startWeightKilograms > targetWeightKilograms else { return 0 }
            let value = (startWeightKilograms - currentWeightKilograms) / (startWeightKilograms - targetWeightKilograms)
            return value.clamped(to: 0...1)
        case .gain:
            guard let startWeightKilograms, startWeightKilograms < targetWeightKilograms else { return 0 }
            let value = (currentWeightKilograms - startWeightKilograms) / (targetWeightKilograms - startWeightKilograms)
            return value.clamped(to: 0...1)
        case .maintenance:
            let delta = abs(currentWeightKilograms - targetWeightKilograms)
            if delta <= 0.5 { return 1 }
            return (1 - ((delta - 0.5) / 4.5)).clamped(to: 0...1)
        }
    }
}

enum GoalLogic {
    static func effectiveGoal(
        currentWeightKilograms: Double,
        configuration: GoalConfiguration,
        referenceDate: Date = .now
    ) -> EffectiveGoal? {
        switch configuration.mode {
        case .generic:
            let goalType = configuration.genericGoalType
            let pace = goalType == .maintenance ? nil : (configuration.weeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek)
            return EffectiveGoal(
                goalType: goalType,
                weeklyPaceKilograms: pace,
                targetWeightKilograms: nil,
                targetDate: nil,
                isAggressiveWarning: false
            )

        case .target:
            guard let targetDate = configuration.targetDate else { return nil }

            let delta = configuration.targetWeightKilograms - currentWeightKilograms
            if abs(delta) < 0.01 {
                return nil
            }

            let weeks = max(targetDate.timeIntervalSince(referenceDate) / (86_400 * 7), 0.01)
            let pace = abs(delta) / weeks
            let goalType: GoalType = delta < 0 ? .loss : .gain

            return EffectiveGoal(
                goalType: goalType,
                weeklyPaceKilograms: pace,
                targetWeightKilograms: configuration.targetWeightKilograms,
                targetDate: targetDate,
                isAggressiveWarning: pace > WeeklyPaceOption.one.kilogramsPerWeek
            )
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
