import Foundation

enum ICloudAccountAvailability: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine(String?)
}

enum ICloudSyncState: Equatable {
    case checkingAccount
    case localOnly
    case waitingForICloud
    case syncing
    case synced
    case error
}

struct SyncedProfileSnapshot {
    let age: Int
    let heightCentimeters: Double
    let targetWeightKilograms: Double
    let activityLevel: String
    let goalType: String
    let goalMode: String
    let weeklyPaceKilograms: Double?
    let targetDate: Date?
    let formulaSex: String
    let preferredUnitSystem: String
    let createdAt: Date
    let updatedAt: Date
}

struct SyncedWeightEntrySnapshot: Identifiable {
    let id: UUID
    let date: Date
    let weightKilograms: Double
    let notes: String
    let source: WeightEntrySource
    let createdAt: Date
    let updatedAt: Date
}

struct CloudDataSnapshot {
    let profile: SyncedProfileSnapshot?
    let entries: [SyncedWeightEntrySnapshot]

    var hasData: Bool {
        profile != nil || !entries.isEmpty
    }
}

extension SyncedProfileSnapshot {
    init(record: ProfileRecord) {
        self.init(
            age: record.age,
            heightCentimeters: record.heightCentimeters,
            targetWeightKilograms: record.targetWeightKilograms,
            activityLevel: record.activityLevel.rawValue,
            goalType: record.goalType.rawValue,
            goalMode: record.goalMode.rawValue,
            weeklyPaceKilograms: record.weeklyPaceKilograms,
            targetDate: record.targetDate,
            formulaSex: record.formulaSex.rawValue,
            preferredUnitSystem: record.preferredUnitSystem.rawValue,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

extension SyncedWeightEntrySnapshot {
    init(record: WeightEntryRecord) {
        self.init(
            id: record.id,
            date: record.date,
            weightKilograms: record.weightKilograms,
            notes: record.notes,
            source: record.source,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}
