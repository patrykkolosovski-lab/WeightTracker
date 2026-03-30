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
final class LocalAccountStateRecord {
    @Attribute(.unique) var userIDString: String
    var email: String
    var allowsLocalAccessWithoutSession: Bool
    var hasCompletedProfile: Bool
    var lastActivatedAt: Date

    init(
        userIDString: String,
        email: String,
        allowsLocalAccessWithoutSession: Bool = true,
        hasCompletedProfile: Bool = false,
        lastActivatedAt: Date = .now
    ) {
        self.userIDString = userIDString
        self.email = email
        self.allowsLocalAccessWithoutSession = allowsLocalAccessWithoutSession
        self.hasCompletedProfile = hasCompletedProfile
        self.lastActivatedAt = lastActivatedAt
    }
}

@Model
final class ProfileRecord {
    var userIDString: String?
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
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        userIDString: String? = nil,
        age: Int,
        heightCentimeters: Double,
        targetWeightKilograms: Double,
        activityLevel: ActivityLevel,
        goalType: GoalType,
        goalMode: GoalMode,
        weeklyPaceKilograms: Double?,
        targetDate: Date?,
        formulaSex: FormulaSex,
        preferredUnitSystem: UnitSystem,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.userIDString = userIDString
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
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
    var userIDString: String?
    var date: Date
    var weightKilograms: Double
    var notes: String
    var sourceRaw: String
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userIDString: String? = nil,
        date: Date,
        weightKilograms: Double,
        notes: String = "",
        source: WeightEntrySource,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.id = id
        self.userIDString = userIDString
        self.date = date
        self.weightKilograms = weightKilograms
        self.notes = notes
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
    }

    var source: WeightEntrySource {
        get { WeightEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
