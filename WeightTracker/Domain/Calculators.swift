import Foundation

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
        goalType: GoalType
    ) -> Int? {
        guard age > 0, heightCentimeters > 0, weightKilograms > 0 else { return nil }

        let baseConstant = formulaSex == .male ? 5.0 : -161.0
        let bmr = (10 * weightKilograms) + (6.25 * heightCentimeters) - (5 * Double(age)) + baseConstant
        let maintenanceCalories = bmr * activityLevel.multiplier

        let adjustedCalories: Double
        switch goalType {
        case .loss:
            adjustedCalories = maintenanceCalories - 500
        case .gain:
            adjustedCalories = maintenanceCalories + 300
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
        targetWeightKilograms: Double,
        goalType: GoalType
    ) -> Double {
        guard let currentWeightKilograms else { return 0 }

        switch goalType {
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

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
