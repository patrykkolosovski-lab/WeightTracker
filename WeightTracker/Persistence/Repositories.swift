import Foundation
import SwiftData

/// Thin SwiftData repository used by the app's coordinators.
///
/// UI reads and writes stay local-first through this type, while iCloud sync
/// mirrors the same records in the background.
struct LocalDataStore {
    static let primaryUserIDString = "icloud-primary-user"

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func activeLocalAccountState() throws -> LocalAccountStateRecord? {
        let predicate = #Predicate<LocalAccountStateRecord> { state in
            state.allowsLocalAccessWithoutSession == true
        }
        let descriptor = FetchDescriptor<LocalAccountStateRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastActivatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func allProfiles() throws -> [ProfileRecord] {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>())
    }

    func allEntries() throws -> [WeightEntryRecord] {
        try modelContext.fetch(FetchDescriptor<WeightEntryRecord>())
    }

    func allLocalAccountStates() throws -> [LocalAccountStateRecord] {
        try modelContext.fetch(FetchDescriptor<LocalAccountStateRecord>())
    }

    func localAccountState(userIDString: String) throws -> LocalAccountStateRecord? {
        let predicate = #Predicate<LocalAccountStateRecord> { state in
            state.userIDString == userIDString
        }
        var descriptor = FetchDescriptor<LocalAccountStateRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Marks the provided account as active for local restore without exposing
    /// account logic to the SwiftUI layer.
    @discardableResult
    func setActiveLocalAccount(
        userIDString: String,
        email: String,
        hasCompletedProfile: Bool? = nil
    ) throws -> LocalAccountStateRecord {
        for state in try modelContext.fetch(FetchDescriptor<LocalAccountStateRecord>()) {
            state.allowsLocalAccessWithoutSession = state.userIDString == userIDString
            if state.userIDString == userIDString {
                state.email = email
                if let hasCompletedProfile {
                    state.hasCompletedProfile = hasCompletedProfile
                }
                state.lastActivatedAt = .now
            }
        }

        let state = try localAccountState(userIDString: userIDString) ?? LocalAccountStateRecord(
            userIDString: userIDString,
            email: email,
            allowsLocalAccessWithoutSession: true,
            hasCompletedProfile: hasCompletedProfile ?? false,
            lastActivatedAt: .now
        )

        state.email = email
        state.allowsLocalAccessWithoutSession = true
        if let hasCompletedProfile {
            state.hasCompletedProfile = hasCompletedProfile
        }
        state.lastActivatedAt = .now

        if state.modelContext == nil {
            modelContext.insert(state)
        }

        try modelContext.save()
        return state
    }

    func markProfileCompleted(userIDString: String, isCompleted: Bool = true) throws {
        guard let state = try localAccountState(userIDString: userIDString) else { return }
        state.hasCompletedProfile = isCompleted
        state.lastActivatedAt = .now
        try modelContext.save()
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
            entry.id == id && entry.userIDString != nil && entry.userIDString == userIDString
        }
        var descriptor = FetchDescriptor<WeightEntryRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func entry(on day: Date, userIDString: String) throws -> WeightEntryRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString != nil
                && entry.userIDString == userIDString
                && entry.date >= startOfDay
                && entry.date < nextDay
        }
        var descriptor = FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Upserts the locally authoritative profile record.
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
    func saveSyncedProfile(
        _ syncedProfile: SyncedProfileSnapshot,
        userIDString: String
    ) throws -> ProfileRecord {
        if let localProfile = try fetchProfile(userIDString: userIDString),
           localProfile.needsSync,
           localProfile.updatedAt > syncedProfile.updatedAt {
            return localProfile
        }

        let profile = try fetchProfile(userIDString: userIDString) ?? ProfileRecord(
            userIDString: userIDString,
            age: syncedProfile.age,
            heightCentimeters: syncedProfile.heightCentimeters,
            targetWeightKilograms: syncedProfile.targetWeightKilograms,
            activityLevel: ActivityLevel(rawValue: syncedProfile.activityLevel) ?? .moderate,
            goalType: GoalType(rawValue: syncedProfile.goalType) ?? .maintenance,
            goalMode: GoalMode(rawValue: syncedProfile.goalMode) ?? .generic,
            weeklyPaceKilograms: syncedProfile.weeklyPaceKilograms,
            targetDate: syncedProfile.targetDate,
            formulaSex: FormulaSex(rawValue: syncedProfile.formulaSex) ?? .female,
            preferredUnitSystem: UnitSystem(rawValue: syncedProfile.preferredUnitSystem) ?? .metric,
            createdAt: syncedProfile.createdAt,
            updatedAt: syncedProfile.updatedAt,
            needsSync: false
        )

        profile.userIDString = userIDString
        profile.age = syncedProfile.age
        profile.heightCentimeters = syncedProfile.heightCentimeters
        profile.targetWeightKilograms = syncedProfile.targetWeightKilograms
        profile.activityLevel = ActivityLevel(rawValue: syncedProfile.activityLevel) ?? .moderate
        profile.goalType = GoalType(rawValue: syncedProfile.goalType) ?? .maintenance
        profile.goalMode = GoalMode(rawValue: syncedProfile.goalMode) ?? .generic
        profile.weeklyPaceKilograms = syncedProfile.weeklyPaceKilograms
        profile.targetDate = syncedProfile.targetDate
        profile.formulaSex = FormulaSex(rawValue: syncedProfile.formulaSex) ?? .female
        profile.preferredUnitSystem = UnitSystem(rawValue: syncedProfile.preferredUnitSystem) ?? .metric
        profile.createdAt = syncedProfile.createdAt
        profile.updatedAt = syncedProfile.updatedAt
        profile.needsSync = false

        if profile.modelContext == nil {
            modelContext.insert(profile)
        }

        try modelContext.save()
        return profile
    }

    /// Creates a new local weight entry record.
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

    /// Updates an existing local weight entry record.
    @discardableResult
    func updateEntry(
        id: UUID,
        userIDString: String,
        with draft: WeightEntryDraft,
        needsSync: Bool,
        updatedAt: Date = .now
    ) throws -> WeightEntryRecord? {
        guard let entry = try entry(with: id, userIDString: userIDString) else { return nil }
        entry.date = draft.date
        entry.weightKilograms = draft.weightKilograms
        entry.notes = draft.notes
        entry.source = draft.source
        entry.updatedAt = updatedAt
        entry.needsSync = needsSync
        try modelContext.save()
        return entry
    }

    /// Ensures there is at most one entry for the given day by updating an
    /// existing record instead of creating a duplicate.
    @discardableResult
    func upsertEntryForDay(
        _ draft: WeightEntryDraft,
        userIDString: String,
        needsSync: Bool
    ) throws -> WeightEntryRecord {
        if let existingEntry = try entry(on: draft.date, userIDString: userIDString) {
            existingEntry.date = draft.date
            existingEntry.weightKilograms = draft.weightKilograms
            existingEntry.notes = draft.notes
            existingEntry.source = draft.source
            existingEntry.updatedAt = .now
            existingEntry.needsSync = needsSync
            try modelContext.save()
            return existingEntry
        }

        return try addEntry(draft, userIDString: userIDString, needsSync: needsSync)
    }

    /// Normalizes any historical duplicate same-day entries and marks the
    /// surviving records dirty so they are re-synced to iCloud.
    @discardableResult
    func normalizeEntryTimeline(
        userIDString: String
    ) throws -> WeightTimelineNormalizationResult<WeightEntryRecord> {
        let fetchedEntries = try fetchEntries(userIDString: userIDString)
        let normalization = WeightTimelineNormalizer.normalize(records: fetchedEntries)

        guard normalization.hasDuplicates else {
            return normalization
        }

        let duplicateIDs = Set(normalization.duplicateEntryIDs)
        let survivorIDs = Set(normalization.survivorEntryIDs)

        for entry in fetchedEntries {
            if duplicateIDs.contains(entry.id) {
                modelContext.delete(entry)
                continue
            }

            if survivorIDs.contains(entry.id) {
                entry.needsSync = true
                entry.updatedAt = .now
            }
        }

        try modelContext.save()
        return WeightTimelineNormalizer.normalize(records: try fetchEntries(userIDString: userIDString))
    }

    func fetchCanonicalEntries(userIDString: String) throws -> [WeightEntryRecord] {
        try normalizeEntryTimeline(userIDString: userIDString).canonicalEntries
    }

    func saveSyncedEntries(_ syncedEntries: [SyncedWeightEntrySnapshot], userIDString: String) throws {
        for syncedEntry in syncedEntries {
            try saveSyncedEntry(syncedEntry, userIDString: userIDString)
        }
    }

    func saveSyncedEntry(_ syncedEntry: SyncedWeightEntrySnapshot, userIDString: String) throws {
        if let localEntry = try entry(with: syncedEntry.id, userIDString: userIDString) {
            if localEntry.needsSync && localEntry.updatedAt > syncedEntry.updatedAt {
                return
            }

            localEntry.userIDString = userIDString
            localEntry.date = syncedEntry.date
            localEntry.weightKilograms = syncedEntry.weightKilograms
            localEntry.notes = syncedEntry.notes
            localEntry.source = syncedEntry.source
            localEntry.createdAt = syncedEntry.createdAt
            localEntry.updatedAt = syncedEntry.updatedAt
            localEntry.needsSync = false
        } else {
            modelContext.insert(
                WeightEntryRecord(
                    id: syncedEntry.id,
                    userIDString: userIDString,
                    date: syncedEntry.date,
                    weightKilograms: syncedEntry.weightKilograms,
                    notes: syncedEntry.notes,
                    source: syncedEntry.source,
                    createdAt: syncedEntry.createdAt,
                    updatedAt: syncedEntry.updatedAt,
                    needsSync: false
                )
            )
        }

        try modelContext.save()
    }

    func pendingProfile(userIDString: String) throws -> ProfileRecord? {
        let predicate = #Predicate<ProfileRecord> { profile in
            profile.userIDString != nil && profile.userIDString == userIDString && profile.needsSync == true
        }
        var descriptor = FetchDescriptor<ProfileRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func pendingEntries(userIDString: String) throws -> [WeightEntryRecord] {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString != nil && entry.userIDString == userIDString && entry.needsSync == true
        }
        let descriptor = FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func migrateLegacyCache(to userIDString: String, needsSync: Bool) throws {
        if let legacyProfile = try fetchProfile(userIDString: nil) {
            legacyProfile.userIDString = userIDString
            legacyProfile.needsSync = needsSync
            legacyProfile.updatedAt = max(legacyProfile.updatedAt, .now)
        }

        for entry in try fetchEntries(userIDString: nil) {
            entry.userIDString = userIDString
            entry.needsSync = needsSync
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

    /// Collapses legacy multi-user/auth-era local state into the single primary
    /// iCloud-backed namespace used by the current app architecture.
    func migrateAllDataToPrimaryUser(userIDString: String = Self.primaryUserIDString) throws {
        let profiles = try allProfiles()
        let entries = try allEntries()
        let states = try allLocalAccountStates()
        let needsMigration = profiles.count > 1
            || states.count > 1
            || profiles.contains(where: { $0.userIDString != userIDString })
            || entries.contains(where: { $0.userIDString != userIDString })
            || states.contains(where: { $0.userIDString != userIDString })

        let chosenProfile = profiles.max { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.updatedAt < rhs.updatedAt
        }

        if needsMigration {
            for profile in profiles {
                if let chosenProfile, profile === chosenProfile {
                    profile.userIDString = userIDString
                    profile.needsSync = true
                    continue
                }

                modelContext.delete(profile)
            }

            for entry in entries {
                entry.userIDString = userIDString
                entry.needsSync = true
            }

            for state in states {
                modelContext.delete(state)
            }
        }

        let hasCompletedProfile = chosenProfile != nil
            || states.contains(where: { $0.hasCompletedProfile })

        let activeState = try localAccountState(userIDString: userIDString) ?? LocalAccountStateRecord(
            userIDString: userIDString,
            email: "",
            allowsLocalAccessWithoutSession: true,
            hasCompletedProfile: hasCompletedProfile,
            lastActivatedAt: .now
        )

        activeState.userIDString = userIDString
        activeState.email = ""
        activeState.allowsLocalAccessWithoutSession = true
        activeState.hasCompletedProfile = hasCompletedProfile
        activeState.lastActivatedAt = .now

        if activeState.modelContext == nil {
            modelContext.insert(activeState)
        }

        try clearLegacyAccount()
        try modelContext.save()
    }

    private func profileDescriptor(for userIDString: String?) -> FetchDescriptor<ProfileRecord> {
        if let userIDString {
            let predicate = #Predicate<ProfileRecord> { profile in
                profile.userIDString != nil && profile.userIDString == userIDString
            }
            return FetchDescriptor<ProfileRecord>(predicate: predicate)
        }

        let predicate = #Predicate<ProfileRecord> { profile in
            profile.userIDString == nil
        }
        return FetchDescriptor<ProfileRecord>(predicate: predicate)
    }

    private func entriesDescriptor(for userIDString: String?) -> FetchDescriptor<WeightEntryRecord> {
        if let userIDString {
            let predicate = #Predicate<WeightEntryRecord> { entry in
                entry.userIDString != nil && entry.userIDString == userIDString
            }
            return FetchDescriptor<WeightEntryRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
        }

        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.userIDString == nil
        }
        return FetchDescriptor<WeightEntryRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
    }
}
