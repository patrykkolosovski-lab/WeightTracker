import Foundation
import SwiftData

enum AuthRepositoryError: LocalizedError {
    case accountExists
    case accountMissing
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .accountExists:
            return "An account already exists on this device."
        case .accountMissing:
            return "No account was found."
        case .invalidCredentials:
            return "The email or password is incorrect."
        }
    }
}

protocol AuthRepository {
    func fetchAccount() throws -> AccountRecord?
    func register(email: String, password: String) throws
    func login(email: String, password: String) throws
}

protocol ProfileRepository {
    func fetchProfile() throws -> ProfileRecord?
    func saveProfile(input: MetricsInput) throws -> ProfileRecord
}

protocol WeightEntryRepository {
    func fetchEntries() throws -> [WeightEntryRecord]
    func entry(with id: UUID) throws -> WeightEntryRecord?
    func latestEntry() throws -> WeightEntryRecord?
    func addEntry(_ draft: WeightEntryDraft) throws
    func updateEntry(id: UUID, with draft: WeightEntryDraft) throws
    func upsertLatestWeight(_ draft: WeightEntryDraft) throws
}

struct LocalAuthRepository: AuthRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAccount() throws -> AccountRecord? {
        var descriptor = FetchDescriptor<AccountRecord>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func register(email: String, password: String) throws {
        guard try fetchAccount() == nil else {
            throw AuthRepositoryError.accountExists
        }

        modelContext.insert(AccountRecord(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password))
        try modelContext.save()
    }

    func login(email: String, password: String) throws {
        guard let account = try fetchAccount() else {
            throw AuthRepositoryError.accountMissing
        }

        guard account.email.caseInsensitiveCompare(email.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame,
              account.password == password else {
            throw AuthRepositoryError.invalidCredentials
        }
    }
}

struct LocalProfileRepository: ProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchProfile() throws -> ProfileRecord? {
        var descriptor = FetchDescriptor<ProfileRecord>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func saveProfile(input: MetricsInput) throws -> ProfileRecord {
        let profile = try fetchProfile() ?? ProfileRecord(
            age: input.age,
            heightCentimeters: input.heightCentimeters,
            targetWeightKilograms: input.targetWeightKilograms,
            activityLevel: input.activityLevel,
            goalType: input.genericGoalType,
            goalMode: input.goalMode,
            weeklyPaceKilograms: input.weeklyPaceKilograms,
            targetDate: input.targetDate,
            formulaSex: input.formulaSex,
            preferredUnitSystem: input.unitSystem
        )

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

        if profile.modelContext == nil {
            modelContext.insert(profile)
        }

        try modelContext.save()
        return profile
    }
}

struct LocalWeightEntryRepository: WeightEntryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchEntries() throws -> [WeightEntryRecord] {
        let descriptor = FetchDescriptor<WeightEntryRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func entry(with id: UUID) throws -> WeightEntryRecord? {
        let predicate = #Predicate<WeightEntryRecord> { entry in
            entry.id == id
        }
        var descriptor = FetchDescriptor<WeightEntryRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func latestEntry() throws -> WeightEntryRecord? {
        let descriptor = FetchDescriptor<WeightEntryRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func addEntry(_ draft: WeightEntryDraft) throws {
        modelContext.insert(
            WeightEntryRecord(
                date: draft.date,
                weightKilograms: draft.weightKilograms,
                notes: draft.notes,
                source: draft.source
            )
        )
        try modelContext.save()
    }

    func updateEntry(id: UUID, with draft: WeightEntryDraft) throws {
        guard let entry = try entry(with: id) else { return }
        entry.date = draft.date
        entry.weightKilograms = draft.weightKilograms
        entry.notes = draft.notes
        entry.source = draft.source
        try modelContext.save()
    }

    func upsertLatestWeight(_ draft: WeightEntryDraft) throws {
        if let latestEntry = try latestEntry() {
            latestEntry.date = draft.date
            latestEntry.weightKilograms = draft.weightKilograms
            latestEntry.notes = draft.notes
            latestEntry.source = draft.source
        } else {
            modelContext.insert(
                WeightEntryRecord(
                    date: draft.date,
                    weightKilograms: draft.weightKilograms,
                    notes: draft.notes,
                    source: draft.source
                )
            )
        }
        try modelContext.save()
    }
}
