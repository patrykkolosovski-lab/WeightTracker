import Foundation
import Supabase

enum SupabaseConfiguration {
    static var projectURL: URL {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: rawValue) else {
            fatalError("Missing SUPABASE_URL in Info.plist")
        }
        return url
    }

    static var publishableKey: String {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !rawValue.isEmpty else {
            fatalError("Missing SUPABASE_PUBLISHABLE_KEY in Info.plist")
        }
        return rawValue
    }
}

let beFitSupabase = SupabaseClient(
    supabaseURL: SupabaseConfiguration.projectURL,
    supabaseKey: SupabaseConfiguration.publishableKey
)

enum AuthRegistrationResult {
    case signedIn(Session)
    case pendingVerification(email: String)
}

enum SupabaseServiceError: LocalizedError {
    case missingSessionAfterVerification

    var errorDescription: String? {
        switch self {
        case .missingSessionAfterVerification:
            return "Verification succeeded, but no session was returned."
        }
    }
}

struct RemoteProfileRow: Codable, Identifiable {
    let id: UUID
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

    enum CodingKeys: String, CodingKey {
        case id
        case age
        case heightCentimeters = "height_centimeters"
        case targetWeightKilograms = "target_weight_kilograms"
        case activityLevel = "activity_level"
        case goalType = "goal_type"
        case goalMode = "goal_mode"
        case weeklyPaceKilograms = "weekly_pace_kilograms"
        case targetDate = "target_date"
        case formulaSex = "formula_sex"
        case preferredUnitSystem = "preferred_unit_system"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var metricsInput: MetricsInput {
        MetricsInput(
            age: age,
            heightCentimeters: heightCentimeters,
            currentWeightKilograms: targetWeightKilograms,
            targetWeightKilograms: targetWeightKilograms,
            activityLevel: ActivityLevel(rawValue: activityLevel) ?? .moderate,
            goalMode: GoalMode(rawValue: goalMode) ?? .generic,
            genericGoalType: GoalType(rawValue: goalType) ?? .maintenance,
            weeklyPaceKilograms: weeklyPaceKilograms,
            targetDate: targetDate,
            formulaSex: FormulaSex(rawValue: formulaSex) ?? .female,
            unitSystem: UnitSystem(rawValue: preferredUnitSystem) ?? .metric
        )
    }
}

struct RemoteProfileWrite: Codable {
    let id: UUID
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
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case age
        case heightCentimeters = "height_centimeters"
        case targetWeightKilograms = "target_weight_kilograms"
        case activityLevel = "activity_level"
        case goalType = "goal_type"
        case goalMode = "goal_mode"
        case weeklyPaceKilograms = "weekly_pace_kilograms"
        case targetDate = "target_date"
        case formulaSex = "formula_sex"
        case preferredUnitSystem = "preferred_unit_system"
        case updatedAt = "updated_at"
    }

    init(record: ProfileRecord, userID: UUID) {
        id = userID
        age = record.age
        heightCentimeters = record.heightCentimeters
        targetWeightKilograms = record.targetWeightKilograms
        activityLevel = record.activityLevel.rawValue
        goalType = record.goalType.rawValue
        goalMode = record.goalMode.rawValue
        weeklyPaceKilograms = record.weeklyPaceKilograms
        targetDate = record.targetDate
        formulaSex = record.formulaSex.rawValue
        preferredUnitSystem = record.preferredUnitSystem.rawValue
        updatedAt = record.updatedAt
    }
}

struct RemoteWeightEntryRow: Codable, Identifiable {
    let id: UUID
    let userID: UUID
    let date: Date
    let weightKilograms: Double
    let notes: String
    let source: WeightEntrySource
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case date
        case weightKilograms = "weight_kilograms"
        case notes
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteWeightEntryWrite: Codable {
    let id: UUID
    let userID: UUID
    let date: Date
    let weightKilograms: Double
    let notes: String
    let source: WeightEntrySource
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case date
        case weightKilograms = "weight_kilograms"
        case notes
        case source
        case updatedAt = "updated_at"
    }

    init(record: WeightEntryRecord, userID: UUID) {
        id = record.id
        self.userID = userID
        date = record.date
        weightKilograms = record.weightKilograms
        notes = record.notes
        source = record.source
        updatedAt = record.updatedAt
    }
}

actor SupabaseService {
    static let shared = SupabaseService()

    nonisolated var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        beFitSupabase.auth.authStateChanges
    }

    func currentStoredSession() -> Session? {
        beFitSupabase.auth.currentSession
    }

    func currentSession() async -> Session? {
        try? await beFitSupabase.auth.session
    }

    func signUp(email: String, password: String) async throws -> AuthRegistrationResult {
        let response = try await beFitSupabase.auth.signUp(email: email, password: password)

        switch response {
        case .session(let session):
            return .signedIn(session)
        case .user(let user):
            return .pendingVerification(email: user.email ?? email)
        }
    }

    func verifySignupOTP(email: String, code: String) async throws -> Session {
        let response = try await beFitSupabase.auth.verifyOTP(
            email: email,
            token: code,
            type: .signup
        )
        guard let session = response.session else {
            throw SupabaseServiceError.missingSessionAfterVerification
        }
        return session
    }

    func resendSignupOTP(email: String) async throws {
        try await beFitSupabase.auth.resend(email: email, type: .signup)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await beFitSupabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await beFitSupabase.auth.signOut()
    }

    static func isEmailNotConfirmedError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("email not confirmed") || message.contains("email_not_confirmed")
    }

    func fetchProfile(userID: UUID) async throws -> RemoteProfileRow? {
        let rows: [RemoteProfileRow] = try await beFitSupabase
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchWeightEntries(userID: UUID) async throws -> [RemoteWeightEntryRow] {
        try await beFitSupabase
            .from("weight_entries")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("date", ascending: true)
            .execute()
            .value
    }

    func saveProfile(_ profile: RemoteProfileWrite) async throws -> RemoteProfileRow {
        if try await fetchProfile(userID: profile.id) == nil {
            return try await beFitSupabase
                .from("profiles")
                .insert(profile)
                .select()
                .single()
                .execute()
                .value
        }

        return try await beFitSupabase
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func saveWeightEntry(_ entry: RemoteWeightEntryWrite) async throws -> RemoteWeightEntryRow {
        let existingRows: [RemoteWeightEntryRow] = try await beFitSupabase
            .from("weight_entries")
            .select()
            .eq("id", value: entry.id.uuidString)
            .limit(1)
            .execute()
            .value

        if existingRows.isEmpty {
            return try await beFitSupabase
                .from("weight_entries")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value
        }

        return try await beFitSupabase
            .from("weight_entries")
            .update(entry)
            .eq("id", value: entry.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}
