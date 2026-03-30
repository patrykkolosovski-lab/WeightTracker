import CloudKit
import Foundation

enum ICloudSyncServiceError: LocalizedError {
    case invalidProfileRecord
    case invalidWeightEntryRecord
    case failedRecordSave
    case failedRecordDelete

    var errorDescription: String? {
        switch self {
        case .invalidProfileRecord:
            return "The iCloud profile payload is incomplete."
        case .invalidWeightEntryRecord:
            return "One of the iCloud weight entries is incomplete."
        case .failedRecordSave:
            return "BeFit could not save your changes to iCloud."
        case .failedRecordDelete:
            return "BeFit could not clean up old iCloud weight entries."
        }
    }
}

actor ICloudSyncService {
    static let shared = ICloudSyncService()

    private let container = CKContainer(identifier: "iCloud.PatrykKolosovski.WeightTracker")
    private let profileRecordType = "Profile"
    private let weightEntryRecordType = "WeightEntry"
    private let profileRecordName = "profile"
    private let lastSuccessfulSyncKey = "befit.icloud.last-successful-sync"

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    func cachedLastSuccessfulSyncDate() -> Date? {
        UserDefaults.standard.object(forKey: lastSuccessfulSyncKey) as? Date
    }

    func recordSuccessfulSync(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastSuccessfulSyncKey)
    }

    /// Returns the current iCloud account status so the app can decide whether
    /// to stay local-only or attempt a cloud sync.
    func accountAvailability() async -> ICloudAccountAvailability {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(returning: .couldNotDetermine(error.localizedDescription))
                    return
                }

                switch status {
                case .available:
                    continuation.resume(returning: .available)
                case .noAccount:
                    continuation.resume(returning: .noAccount)
                case .restricted:
                    continuation.resume(returning: .restricted)
                case .temporarilyUnavailable:
                    continuation.resume(returning: .temporarilyUnavailable)
                case .couldNotDetermine:
                    continuation.resume(returning: .couldNotDetermine(nil))
                @unknown default:
                    continuation.resume(returning: .couldNotDetermine(nil))
                }
            }
        }
    }

    /// Fetches the complete private-database snapshot used to hydrate a new or
    /// returning device.
    func fetchSnapshot() async throws -> CloudDataSnapshot {
        async let profile = fetchProfile()
        async let entries = fetchWeightEntries()
        return try await CloudDataSnapshot(
            profile: profile,
            entries: entries
        )
    }

    /// Saves the canonical profile record to the user's private iCloud store.
    func saveProfile(_ profile: SyncedProfileSnapshot) async throws -> SyncedProfileSnapshot {
        let recordID = CKRecord.ID(recordName: profileRecordName)
        let existingRecord = try await existingRecord(for: recordID)
        let record = existingRecord ?? CKRecord(
            recordType: profileRecordType,
            recordID: recordID
        )
        apply(profile: profile, to: record)
        return try await saveRecord(record).flatMap(makeProfileSnapshot(from:))
    }

    /// Saves a single canonical weight entry to the user's private iCloud store.
    func saveEntry(_ entry: SyncedWeightEntrySnapshot) async throws -> SyncedWeightEntrySnapshot {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let existingRecord = try await existingRecord(for: recordID)
        let record = existingRecord ?? CKRecord(
            recordType: weightEntryRecordType,
            recordID: recordID
        )
        apply(entry: entry, to: record)
        return try await saveRecord(record).flatMap(makeWeightEntrySnapshot(from:))
    }

    /// Removes stale duplicate remote entries after local or remote timeline
    /// normalization has chosen the daily survivor.
    func deleteEntries(with ids: [UUID]) async throws {
        let recordIDs = ids.map { CKRecord.ID(recordName: $0.uuidString) }
        guard !recordIDs.isEmpty else { return }

        let result = try await database.modifyRecords(
            saving: [],
            deleting: recordIDs,
            savePolicy: .changedKeys,
            atomically: false
        )

        for recordID in recordIDs {
            guard let deleteResult = result.deleteResults[recordID] else {
                throw ICloudSyncServiceError.failedRecordDelete
            }

            switch deleteResult {
            case .success:
                break
            case .failure(let error):
                if isIgnorableDeleteError(error) {
                    continue
                }
                throw error
            }
        }
    }

    private func fetchProfile() async throws -> SyncedProfileSnapshot? {
        let recordID = CKRecord.ID(recordName: profileRecordName)
        guard let record = try await existingRecord(for: recordID) else {
            return nil
        }
        return try makeProfileSnapshot(from: record)
    }

    private func fetchWeightEntries() async throws -> [SyncedWeightEntrySnapshot] {
        let query = CKQuery(recordType: weightEntryRecordType, predicate: NSPredicate(value: true))
        let records = try await fetchRecords(matching: query)
        return try records
            .map(makeWeightEntrySnapshot(from:))
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.date < rhs.date
            }
    }

    private func existingRecord(for recordID: CKRecord.ID) async throws -> CKRecord? {
        let results = try await database.records(for: [recordID])
        switch results[recordID] {
        case .success(let record):
            return record
        case .failure:
            return nil
        case .none:
            return nil
        }
    }

    private func fetchRecords(matching query: CKQuery) async throws -> [CKRecord] {
        var results: [CKRecord] = []
        var response = try await database.records(matching: query)
        results.append(contentsOf: response.matchResults.compactMap { _, result in
            try? result.get()
        })

        while let cursor = response.queryCursor {
            response = try await database.records(continuingMatchFrom: cursor)
            results.append(contentsOf: response.matchResults.compactMap { _, result in
                try? result.get()
            })
        }

        return results
    }

    private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        let result = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: false
        )

        guard let savedRecordResult = result.saveResults[record.recordID] else {
            throw ICloudSyncServiceError.failedRecordSave
        }

        switch savedRecordResult {
        case .success(let savedRecord):
            return savedRecord
        case .failure(let error):
            throw error
        }
    }

    private func apply(profile: SyncedProfileSnapshot, to record: CKRecord) {
        record["age"] = profile.age as CKRecordValue
        record["heightCentimeters"] = profile.heightCentimeters as CKRecordValue
        record["targetWeightKilograms"] = profile.targetWeightKilograms as CKRecordValue
        record["activityLevel"] = profile.activityLevel as CKRecordValue
        record["goalType"] = profile.goalType as CKRecordValue
        record["goalMode"] = profile.goalMode as CKRecordValue
        record["weeklyPaceKilograms"] = profile.weeklyPaceKilograms as CKRecordValue?
        record["targetDate"] = profile.targetDate as CKRecordValue?
        record["formulaSex"] = profile.formulaSex as CKRecordValue
        record["preferredUnitSystem"] = profile.preferredUnitSystem as CKRecordValue
        record["createdAt"] = profile.createdAt as CKRecordValue
        record["updatedAt"] = profile.updatedAt as CKRecordValue
    }

    private func apply(entry: SyncedWeightEntrySnapshot, to record: CKRecord) {
        record["date"] = entry.date as CKRecordValue
        record["weightKilograms"] = entry.weightKilograms as CKRecordValue
        record["notes"] = entry.notes as CKRecordValue
        record["source"] = entry.source.rawValue as CKRecordValue
        record["createdAt"] = entry.createdAt as CKRecordValue
        record["updatedAt"] = entry.updatedAt as CKRecordValue
    }

    private func makeProfileSnapshot(from record: CKRecord) throws -> SyncedProfileSnapshot {
        guard let age = record["age"] as? Int,
              let heightCentimeters = record["heightCentimeters"] as? Double,
              let targetWeightKilograms = record["targetWeightKilograms"] as? Double,
              let activityLevel = record["activityLevel"] as? String,
              let goalType = record["goalType"] as? String,
              let goalMode = record["goalMode"] as? String,
              let formulaSex = record["formulaSex"] as? String,
              let preferredUnitSystem = record["preferredUnitSystem"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            throw ICloudSyncServiceError.invalidProfileRecord
        }

        return SyncedProfileSnapshot(
            age: age,
            heightCentimeters: heightCentimeters,
            targetWeightKilograms: targetWeightKilograms,
            activityLevel: activityLevel,
            goalType: goalType,
            goalMode: goalMode,
            weeklyPaceKilograms: record["weeklyPaceKilograms"] as? Double,
            targetDate: record["targetDate"] as? Date,
            formulaSex: formulaSex,
            preferredUnitSystem: preferredUnitSystem,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makeWeightEntrySnapshot(from record: CKRecord) throws -> SyncedWeightEntrySnapshot {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let date = record["date"] as? Date,
              let weightKilograms = record["weightKilograms"] as? Double,
              let notes = record["notes"] as? String,
              let sourceRaw = record["source"] as? String,
              let source = WeightEntrySource(rawValue: sourceRaw),
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            throw ICloudSyncServiceError.invalidWeightEntryRecord
        }

        return SyncedWeightEntrySnapshot(
            id: id,
            date: date,
            weightKilograms: weightKilograms,
            notes: notes,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func isIgnorableDeleteError(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else {
            return false
        }

        switch cloudError.code {
        case .unknownItem:
            return true
        default:
            return false
        }
    }
}

private extension CKRecord {
    func flatMap<T>(_ transform: (CKRecord) throws -> T) throws -> T {
        try transform(self)
    }
}
