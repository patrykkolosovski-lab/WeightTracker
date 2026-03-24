import Combine
import Foundation
import SwiftData

@MainActor
final class AppStore: ObservableObject {
    @Published var destination: RootDestination = .loading
    @Published var selectedTab: AppTab = .home
    @Published var activeWeightEntryID: UUID?
    @Published var isWeightEntrySheetPresented = false

    @Published private(set) var account: AccountRecord?
    @Published private(set) var profile: ProfileRecord?
    @Published private(set) var entries: [WeightEntryRecord] = []

    private let sessionKey = "befit.active-session"
    private var isConfigured = false

    private var authRepository: AuthRepository?
    private var profileRepository: ProfileRepository?
    private var weightRepository: WeightEntryRepository?

    func configureIfNeeded(modelContext: ModelContext) {
        guard !isConfigured else { return }

        authRepository = LocalAuthRepository(modelContext: modelContext)
        profileRepository = LocalProfileRepository(modelContext: modelContext)
        weightRepository = LocalWeightEntryRepository(modelContext: modelContext)
        isConfigured = true

        refreshAll()
    }

    func refreshAll() {
        guard isConfigured else { return }

        do {
            account = try authRepository?.fetchAccount()
            profile = try profileRepository?.fetchProfile()
            entries = try weightRepository?.fetchEntries() ?? []
            updateDestination()
        } catch {
            destination = .auth(.register)
        }
    }

    func register(email: String, password: String) throws {
        guard let authRepository else { return }
        try authRepository.register(email: email, password: password)
        setSessionActive(true)
        refreshAll()
    }

    func login(email: String, password: String) throws {
        guard let authRepository else { return }
        try authRepository.login(email: email, password: password)
        setSessionActive(true)
        refreshAll()
    }

    func logout() {
        setSessionActive(false)
        refreshAll()
    }

    func saveMetrics(form: MetricsFormState) throws {
        guard let input = form.makeInput(),
              let profileRepository,
              let weightRepository else {
            throw ValidationError.invalidMetrics
        }

        _ = try profileRepository.saveProfile(input: input)
        try weightRepository.upsertLatestWeight(
            WeightEntryDraft(
                date: .now,
                weightKilograms: input.currentWeightKilograms,
                notes: "",
                source: .metricsAdjustment
            )
        )

        setSessionActive(true)
        refreshAll()
    }

    func updatePreferredUnitSystem(_ unitSystem: UnitSystem) {
        guard let profileRepository,
              let currentProfile = profile,
              let latestWeightKilograms = currentWeightKilograms else { return }

        let input = MetricsInput(
            age: currentProfile.age,
            heightCentimeters: currentProfile.heightCentimeters,
            currentWeightKilograms: latestWeightKilograms,
            targetWeightKilograms: currentProfile.targetWeightKilograms,
            activityLevel: currentProfile.activityLevel,
            goalType: currentProfile.goalType,
            formulaSex: currentProfile.formulaSex,
            unitSystem: unitSystem
        )

        do {
            _ = try profileRepository.saveProfile(input: input)
            refreshAll()
        } catch {
            refreshAll()
        }
    }

    func presentWeightEntrySheet(for entryID: UUID? = nil) {
        activeWeightEntryID = entryID
        isWeightEntrySheetPresented = true
    }

    func dismissWeightEntrySheet() {
        activeWeightEntryID = nil
        isWeightEntrySheetPresented = false
    }

    func saveWeightEntry(form: WeightEntryFormState) throws {
        guard let draft = form.makeDraft(source: activeWeightEntryID == nil ? .manual : .metricsAdjustment),
              let weightRepository else {
            throw ValidationError.invalidWeightEntry
        }

        if let activeWeightEntryID {
            try weightRepository.updateEntry(id: activeWeightEntryID, with: draft)
        } else {
            try weightRepository.addEntry(draft)
        }

        dismissWeightEntrySheet()
        refreshAll()
    }

    func entryForEditing() -> WeightEntryRecord? {
        guard let activeWeightEntryID else { return nil }
        return entries.first(where: { $0.id == activeWeightEntryID })
    }

    var hasAccount: Bool {
        account != nil
    }

    var unitSystem: UnitSystem {
        profile?.preferredUnitSystem ?? .metric
    }

    var currentWeightKilograms: Double? {
        entries.last?.weightKilograms
    }

    var startingWeightKilograms: Double? {
        entries.first?.weightKilograms
    }

    var currentWeightDisplay: String {
        guard let currentWeightKilograms else { return "--" }
        let value = UnitConverter.weightToDisplay(currentWeightKilograms, unitSystem: unitSystem)
        let number = Formatters.weightDisplay.string(from: NSNumber(value: value)) ?? "--"
        return "\(number) \(unitSystem.weightUnit)"
    }

    var targetWeightDisplay: String {
        guard let targetWeight = profile?.targetWeightKilograms else { return "--" }
        let value = UnitConverter.weightToDisplay(targetWeight, unitSystem: unitSystem)
        let number = Formatters.weightDisplay.string(from: NSNumber(value: value)) ?? "--"
        return "\(number) \(unitSystem.weightUnit)"
    }

    var bmiValue: Double? {
        guard let currentWeightKilograms, let heightCentimeters = profile?.heightCentimeters else { return nil }
        return BMICalculator.value(weightKilograms: currentWeightKilograms, heightCentimeters: heightCentimeters)
    }

    var bmiDisplay: String {
        guard let bmiValue else { return "--" }
        return Formatters.compactDecimal.string(from: NSNumber(value: bmiValue)) ?? "--"
    }

    var weeklyAverageDisplay: String {
        guard !entries.isEmpty else { return "--" }

        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let filtered = entries.filter { $0.date >= startDate }
        let source = filtered.isEmpty ? entries : filtered
        let average = source.map(\.weightKilograms).reduce(0, +) / Double(source.count)
        let displayValue = UnitConverter.weightToDisplay(average, unitSystem: unitSystem)
        return "\(Formatters.weightDisplay.string(from: NSNumber(value: displayValue)) ?? "--") \(unitSystem.weightUnit)"
    }

    var dailyCaloriesDisplay: String {
        guard let profile, let currentWeightKilograms else { return "--" }

        guard let calories = CalorieCalculator.dailyTarget(
            age: profile.age,
            heightCentimeters: profile.heightCentimeters,
            weightKilograms: currentWeightKilograms,
            activityLevel: profile.activityLevel,
            formulaSex: profile.formulaSex,
            goalType: profile.goalType
        ) else {
            return "--"
        }

        return "\(calories) kcal"
    }

    var progressValue: Double {
        guard let profile else { return 0 }

        return GoalProgressCalculator.progress(
            startWeightKilograms: startingWeightKilograms,
            currentWeightKilograms: currentWeightKilograms,
            targetWeightKilograms: profile.targetWeightKilograms,
            goalType: profile.goalType
        )
    }

    var progressSubtitle: String {
        guard let profile, let currentWeightKilograms else { return "Target unavailable" }

        let delta = abs(currentWeightKilograms - profile.targetWeightKilograms)
        let displayDelta = UnitConverter.weightToDisplay(delta, unitSystem: unitSystem)
        let formattedDelta = Formatters.compactDecimal.string(from: NSNumber(value: displayDelta)) ?? "0"

        switch profile.goalType {
        case .maintenance:
            return "\(formattedDelta) \(unitSystem.weightUnit) from target"
        case .loss, .gain:
            return "\(formattedDelta) \(unitSystem.weightUnit) remaining"
        }
    }

    func entries(for timeframe: GraphTimeframe) -> [WeightEntryRecord] {
        guard let startDate = timeframe.startDate() else { return entries }
        return entries.filter { $0.date >= startDate }
    }

    func metricsFormState() -> MetricsFormState {
        MetricsFormState.from(profile: profile, currentWeightKilograms: currentWeightKilograms)
    }

    func weightEntryFormState() -> WeightEntryFormState {
        if let entry = entryForEditing() {
            return .from(entry: entry, unitSystem: unitSystem)
        }

        return .new(latestWeightKilograms: currentWeightKilograms, unitSystem: unitSystem)
    }

    private func updateDestination() {
        guard hasAccount else {
            destination = .auth(.register)
            return
        }

        guard isSessionActive else {
            destination = .auth(.login)
            return
        }

        guard profile != nil else {
            destination = .metricsOnboarding
            return
        }

        destination = .main
    }

    private var isSessionActive: Bool {
        UserDefaults.standard.bool(forKey: sessionKey)
    }

    private func setSessionActive(_ isActive: Bool) {
        UserDefaults.standard.set(isActive, forKey: sessionKey)
    }
}

enum ValidationError: LocalizedError {
    case invalidMetrics
    case invalidWeightEntry

    var errorDescription: String? {
        switch self {
        case .invalidMetrics:
            return "Please complete all body metrics with valid values."
        case .invalidWeightEntry:
            return "Please enter a valid weight before saving."
        }
    }
}
