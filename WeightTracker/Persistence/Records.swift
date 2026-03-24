import Foundation
import SwiftData

@Model
final class AccountRecord {
    var email: String
    var password: String
    var createdAt: Date

    init(email: String, password: String, createdAt: Date = .now) {
        self.email = email
        self.password = password
        self.createdAt = createdAt
    }
}

@Model
final class ProfileRecord {
    var age: Int
    var heightCentimeters: Double
    var targetWeightKilograms: Double
    var activityLevelRaw: String
    var goalTypeRaw: String
    var goalModeRaw: String?
    var weeklyPaceKilograms: Double?
    var targetDate: Date?
    var formulaSexRaw: String
    var preferredUnitSystemRaw: String

    init(
        age: Int,
        heightCentimeters: Double,
        targetWeightKilograms: Double,
        activityLevel: ActivityLevel,
        goalType: GoalType,
        goalMode: GoalMode,
        weeklyPaceKilograms: Double?,
        targetDate: Date?,
        formulaSex: FormulaSex,
        preferredUnitSystem: UnitSystem
    ) {
        self.age = age
        self.heightCentimeters = heightCentimeters
        self.targetWeightKilograms = targetWeightKilograms
        self.activityLevelRaw = activityLevel.rawValue
        self.goalTypeRaw = goalType.rawValue
        self.goalModeRaw = goalMode.rawValue
        self.weeklyPaceKilograms = weeklyPaceKilograms
        self.targetDate = targetDate
        self.formulaSexRaw = formulaSex.rawValue
        self.preferredUnitSystemRaw = preferredUnitSystem.rawValue
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .maintenance }
        set { goalTypeRaw = newValue.rawValue }
    }

    var goalMode: GoalMode {
        get { GoalMode(rawValue: goalModeRaw ?? "") ?? .generic }
        set { goalModeRaw = newValue.rawValue }
    }

    var formulaSex: FormulaSex {
        get { FormulaSex(rawValue: formulaSexRaw) ?? .female }
        set { formulaSexRaw = newValue.rawValue }
    }

    var preferredUnitSystem: UnitSystem {
        get { UnitSystem(rawValue: preferredUnitSystemRaw) ?? .metric }
        set { preferredUnitSystemRaw = newValue.rawValue }
    }

    var resolvedWeeklyPaceKilograms: Double? {
        if goalType == .maintenance {
            return nil
        }

        return weeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek
    }

    var goalConfiguration: GoalConfiguration {
        GoalConfiguration(
            mode: goalMode,
            genericGoalType: goalType,
            weeklyPaceKilograms: resolvedWeeklyPaceKilograms,
            targetWeightKilograms: targetWeightKilograms,
            targetDate: targetDate
        )
    }
}

@Model
final class WeightEntryRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKilograms: Double
    var notes: String
    var sourceRaw: String

    init(
        id: UUID = UUID(),
        date: Date,
        weightKilograms: Double,
        notes: String = "",
        source: WeightEntrySource
    ) {
        self.id = id
        self.date = date
        self.weightKilograms = weightKilograms
        self.notes = notes
        self.sourceRaw = source.rawValue
    }

    var source: WeightEntrySource {
        get { WeightEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
