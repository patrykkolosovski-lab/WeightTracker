import Foundation
import SwiftData

struct LegacyCredentials {
    let email: String
    let password: String
}

struct LegacyDataSnapshot {
    let credentials: LegacyCredentials?
    let profile: ProfileRecord?
    let entries: [WeightEntryRecord]

    var hasData: Bool {
        credentials != nil || profile != nil || !entries.isEmpty
    }
}

struct LocalDataStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func legacyCredentials() throws -> LegacyCredentials? {
        var descriptor = FetchDescriptor<AccountRecord>()
        descriptor.fetchLimit = 1

        guard let account = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return LegacyCredentials(
            email: account.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: account.password
        )
    }

    func legacyDataSnapshot() throws -> LegacyDataSnapshot {
        let legacyProfile = try fetchProfile(userIDString: nil)
        let legacyEntries = try fetchEntries(userIDString: nil)
        return LegacyDataSnapshot(
            credentials: try legacyCredentials(),
            profile: legacyProfile,
            entries: legacyEntries
        )
    }

    func fetchProfile(userIDString: String?) throws -> ProfileRecord? {
        let descriptor = profileDescriptor(for: userIDString)
        return try modelContext.fetch(descriptor).first
    }

    func fetchEntries(userIDString: String?) throws -> [WeightEntryRecord] {
        let descriptor = entriesDescriptor(for: userIDString)
        return try modelContext.fetch(descriptor)
    }

    func entry(with id: UUID, userIDString: String) throws -> WeightEntryRecord? {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.id == id && entry.userIDString == userIDString
        }
        var descriptor = FetchDescriptor<WeightEntryRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func latestEntry(userIDString: String) throws -> WeightEntryRecord? {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString == userIDString
        }
        let descriptor = FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func saveProfile(
        input: MetricsInput,
        userIDString: String,
        needsSync: Bool,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) throws -> ProfileRecord {
        let profile = try fetchProfile(userIDString: userIDString) ?? ProfileRecord(
            userIDString: userIDString,
            age: input.age,
            heightCentimeters: input.heightCentimeters,
            targetWeightKilograms: input.targetWeightKilograms,
            activityLevel: input.activityLevel,
            goalType: input.genericGoalType,
            goalMode: input.goalMode,
            weeklyPaceKilograms: input.weeklyPaceKilograms,
            targetDate: input.targetDate,
            formulaSex: input.formulaSex,
            preferredUnitSystem: input.unitSystem,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now,
            needsSync: needsSync
        )

        profile.userIDString = userIDString
        profile.age = input.age
        profile.heightCentimeters = input.heightCentimeters
        profile.targetWeightKilograms = input.targetWeightKilograms
        profile.activityLevel = input.activityLevel
        profile.goalType = input.genericGoalType
        profile.goalMode = input.goalMode
        profile.weeklyPaceKilograms = input.weeklyPaceKilograms
        profile.targetDate = input.targetDate
        profile.formulaSex = input.formulaSex
        profile.preferredUnitSystem = input.unitSystem
        profile.createdAt = createdAt ?? profile.createdAt
        profile.updatedAt = updatedAt ?? .now
        profile.needsSync = needsSync

        if profile.modelContext == nil {
            modelContext.insert(profile)
        }

        try modelContext.save()
        return profile
    }

    @discardableResult
    func saveRemoteProfile(_ remoteProfile: RemoteProfileRow) throws -> ProfileRecord {
        try saveProfile(
            input: remoteProfile.metricsInput,
            userIDString: remoteProfile.id.uuidString,
            needsSync: false,
            createdAt: remoteProfile.createdAt,
            updatedAt: remoteProfile.updatedAt
        )
    }

    @discardableResult
    func addEntry(
        _ draft: WeightEntryDraft,
        userIDString: String,
        needsSync: Bool,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) throws -> WeightEntryRecord {
        let record = WeightEntryRecord(
            id: id,
            userIDString: userIDString,
            date: draft.date,
            weightKilograms: draft.weightKilograms,
            notes: draft.notes,
            source: draft.source,
            createdAt: createdAt,
            updatedAt: updatedAt,
            needsSync: needsSync
        )
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    func updateEntry(
        id: UUID,
        userIDString: String,
        with draft: WeightEntryDraft,
        needsSync: Bool,
        updatedAt: Date = .now
    ) throws {
        guard let entry = try entry(with: id, userIDString: userIDString) else { return }
        entry.date = draft.date
        entry.weightKilograms = draft.weightKilograms
        entry.notes = draft.notes
        entry.source = draft.source
        entry.updatedAt = updatedAt
        entry.needsSync = needsSync
        try modelContext.save()
    }

    func upsertLatestWeight(
        _ draft: WeightEntryDraft,
        userIDString: String,
        needsSync: Bool
    ) throws {
        if let latestEntry = try latestEntry(userIDString: userIDString) {
            latestEntry.date = draft.date
            latestEntry.weightKilograms = draft.weightKilograms
            latestEntry.notes = draft.notes
            latestEntry.source = draft.source
            latestEntry.updatedAt = .now
            latestEntry.needsSync = needsSync
        } else {
            _ = try addEntry(draft, userIDString: userIDString, needsSync: needsSync)
        }

        try modelContext.save()
    }

    func saveRemoteEntries(_ remoteEntries: [RemoteWeightEntryRow], userIDString: String) throws {
        for remoteEntry in remoteEntries {
            try saveRemoteEntry(remoteEntry, userIDString: userIDString)
        }
    }

    func saveRemoteEntry(_ remoteEntry: RemoteWeightEntryRow, userIDString: String) throws {
        if let localEntry = try entry(with: remoteEntry.id, userIDString: userIDString) {
            if localEntry.needsSync && localEntry.updatedAt > remoteEntry.updatedAt {
                return
            }

            localEntry.userIDString = userIDString
            localEntry.date = remoteEntry.date
            localEntry.weightKilograms = remoteEntry.weightKilograms
            localEntry.notes = remoteEntry.notes
            localEntry.source = remoteEntry.source
            localEntry.createdAt = remoteEntry.createdAt
            localEntry.updatedAt = remoteEntry.updatedAt
            localEntry.needsSync = false
        } else {
            modelContext.insert(
                WeightEntryRecord(
                    id: remoteEntry.id,
                    userIDString: userIDString,
                    date: remoteEntry.date,
                    weightKilograms: remoteEntry.weightKilograms,
                    notes: remoteEntry.notes,
                    source: remoteEntry.source,
                    createdAt: remoteEntry.createdAt,
                    updatedAt: remoteEntry.updatedAt,
                    needsSync: false
                )
            )
        }

        try modelContext.save()
    }

    func pendingProfile(userIDString: String) throws -> ProfileRecord? {
        let predicate = #Predicate<ProfileRecord> { profile in
            profile.userIDString == userIDString && profile.needsSync == true
        }
        var descriptor = FetchDescriptor<ProfileRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func pendingEntries(userIDString: String) throws -> [WeightEntryRecord] {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString == userIDString && entry.needsSync == true
        }
        let descriptor = FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func markProfileSynced(userIDString: String, updatedAt: Date) throws {
        guard let profile = try fetchProfile(userIDString: userIDString) else { return }
        profile.updatedAt = updatedAt
        profile.needsSync = false
        try modelContext.save()
    }

    func markEntrySynced(id: UUID, userIDString: String, updatedAt: Date) throws {
        guard let entry = try entry(with: id, userIDString: userIDString) else { return }
        entry.updatedAt = updatedAt
        entry.needsSync = false
        try modelContext.save()
    }

    func migrateLegacyCache(to userIDString: String) throws {
        if let legacyProfile = try fetchProfile(userIDString: nil) {
            legacyProfile.userIDString = userIDString
            legacyProfile.needsSync = false
            legacyProfile.updatedAt = max(legacyProfile.updatedAt, .now)
        }

        for entry in try fetchEntries(userIDString: nil) {
            entry.userIDString = userIDString
            entry.needsSync = false
            entry.updatedAt = max(entry.updatedAt, .now)
        }

        try modelContext.save()
    }

    func clearLegacyAccount() throws {
        var descriptor = FetchDescriptor<AccountRecord>()
        descriptor.fetchLimit = 1
        if let account = try modelContext.fetch(descriptor).first {
            modelContext.delete(account)
            try modelContext.save()
        }
    }

    private func profileDescriptor(for userIDString: String?) -> FetchDescriptor<ProfileRecord> {
        let predicate = #Predicate<ProfileRecord> { profile in
            profile.userIDString == userIDString
        }
        return FetchDescriptor<ProfileRecord>(predicate: predicate)
    }

    private func entriesDescriptor(for userIDString: String?) -> FetchDescriptor<WeightEntryRecord> {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString == userIDString
        }
        return FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
    }
}
