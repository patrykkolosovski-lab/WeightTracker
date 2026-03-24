import Combine
import Foundation
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    @Published var destination: RootDestination = .loading
    @Published var selectedTab: AppTab = .home
    @Published var activeWeightEntryID: UUID?
    @Published var isWeightEntrySheetPresented = false
    @Published var isReminderSetupPresented = false
    @Published var reminderSetupMode: ReminderSetupMode = .firstPrompt
    @Published var reminderTimeSelection = ReminderPreferencesStore.defaultTimeDate()
    @Published var isNotificationSettingsAlertPresented = false

    @Published private(set) var account: AccountRecord?
    @Published private(set) var profile: ProfileRecord?
    @Published private(set) var entries: [WeightEntryRecord] = []
    @Published private(set) var reminderAuthorizationStatus: ReminderAuthorizationStatus = .notDetermined
    @Published private(set) var isDailyReminderEnabled = false

    private let sessionKey = "befit.active-session"
    private var isConfigured = false

    private var authRepository: AuthRepository?
    private var profileRepository: ProfileRepository?
    private var weightRepository: WeightEntryRepository?
    private let reminderPreferences = ReminderPreferencesStore()
    private var reminderService: ReminderNotificationService?

    func configureIfNeeded(modelContext: ModelContext) {
        guard !isConfigured else { return }

        authRepository = LocalAuthRepository(modelContext: modelContext)
        profileRepository = LocalProfileRepository(modelContext: modelContext)
        weightRepository = LocalWeightEntryRepository(modelContext: modelContext)
        reminderService = LocalReminderNotificationService()
        isConfigured = true

        syncReminderPreferences()
        refreshAll()
        refreshReminderState()
    }

    func refreshAll() {
        guard isConfigured else { return }

        do {
            account = try authRepository?.fetchAccount()
            profile = try profileRepository?.fetchProfile()
            entries = try weightRepository?.fetchEntries() ?? []
            syncReminderPreferences()
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
        refreshReminderState()
    }

    func login(email: String, password: String) throws {
        guard let authRepository else { return }
        try authRepository.login(email: email, password: password)
        setSessionActive(true)
        refreshAll()
        refreshReminderState()
    }

    func logout() {
        setSessionActive(false)
        refreshAll()
        Task {
            await reminderService?.removeAllReminders()
        }
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
        refreshReminderState()
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
            goalMode: currentProfile.goalMode,
            genericGoalType: currentProfile.goalType,
            weeklyPaceKilograms: currentProfile.resolvedWeeklyPaceKilograms,
            targetDate: currentProfile.targetDate,
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
        let today = Calendar.current.startOfDay(for: .now)
        let selectedDay = Calendar.current.startOfDay(for: form.date)
        guard selectedDay <= today else {
            throw ValidationError.futureWeightEntryDate
        }

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
        refreshReminderState()
    }

    func handleHomeAppeared() {
        guard isInMainDestination else { return }
        syncReminderPreferences()

        if reminderAuthorizationStatus == .notDetermined,
           !reminderPreferences.hasHandledInitialPrompt() {
            reminderSetupMode = .firstPrompt
            reminderTimeSelection = reminderPreferences.reminderTimeDate()
            isReminderSetupPresented = true
            return
        }

        refreshReminderState()
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase == .active else { return }
        refreshReminderState()
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) {
        syncReminderPreferences()

        if !isEnabled {
            reminderPreferences.setReminderEnabled(false)
            syncReminderPreferences()
            Task {
                await reminderService?.removeAllReminders()
            }
            return
        }

        switch reminderAuthorizationStatus {
        case .authorized:
            reminderPreferences.setReminderEnabled(true)
            syncReminderPreferences()
            refreshReminderState()
        case .notDetermined:
            reminderSetupMode = .firstPrompt
            reminderTimeSelection = reminderPreferences.reminderTimeDate()
            isReminderSetupPresented = true
        case .denied:
            isNotificationSettingsAlertPresented = true
        }
    }

    func presentReminderTimeEditor() {
        reminderSetupMode = .editTime
        reminderTimeSelection = reminderPreferences.reminderTimeDate()
        isReminderSetupPresented = true
    }

    func dismissReminderSetup() {
        if reminderSetupMode == .firstPrompt {
            reminderPreferences.setReminderTime(reminderTimeSelection)
            reminderPreferences.setHasHandledInitialPrompt(true)
            syncReminderPreferences()
        }

        isReminderSetupPresented = false
    }

    func confirmReminderSetup() async {
        reminderPreferences.setReminderTime(reminderTimeSelection)

        switch reminderSetupMode {
        case .firstPrompt:
            reminderPreferences.setHasHandledInitialPrompt(true)
            let status = await requestReminderAuthorizationIfNeeded()
            if status == .authorized {
                reminderPreferences.setReminderEnabled(true)
            } else {
                reminderPreferences.setReminderEnabled(false)
            }
        case .editTime:
            break
        }

        syncReminderPreferences()
        isReminderSetupPresented = false
        await rebuildReminderSchedule()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

    var reminderTimeDisplay: String {
        Formatters.time.string(from: reminderPreferences.reminderTimeDate())
    }

    var reminderPermissionDisplay: String {
        switch reminderAuthorizationStatus {
        case .authorized:
            return "Allowed"
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Blocked"
        }
    }

    var shouldShowNotificationRecovery: Bool {
        reminderAuthorizationStatus == .denied
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

    var weeklyAverageRows: [WeeklyAverageRow] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let entriesByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let latestEntry = entriesByDay[day]?.max(by: { $0.date < $1.date })
            let value = latestEntry.map {
                UnitConverter.weightToDisplay($0.weightKilograms, unitSystem: unitSystem)
            }.map {
                "\(Formatters.weightDisplay.string(from: NSNumber(value: $0)) ?? "--") \(unitSystem.weightUnit)"
            } ?? "--"

            return WeeklyAverageRow(date: day, value: value)
        }
    }

    var dailyCaloriesDisplay: String {
        guard let profile, let currentWeightKilograms, let effectiveGoal else { return "--" }

        guard let calories = CalorieCalculator.dailyTarget(
            age: profile.age,
            heightCentimeters: profile.heightCentimeters,
            weightKilograms: currentWeightKilograms,
            activityLevel: profile.activityLevel,
            formulaSex: profile.formulaSex,
            effectiveGoal: effectiveGoal
        ) else {
            return "--"
        }

        return "\(calories) kcal"
    }

    var progressValue: Double {
        guard profile?.goalMode == .target else { return 0 }

        return GoalProgressCalculator.progress(
            startWeightKilograms: startingWeightKilograms,
            currentWeightKilograms: currentWeightKilograms,
            effectiveGoal: effectiveGoal
        )
    }

    var targetProgressDisplay: String {
        guard isTargetMode else { return "--" }
        let percentage = progressValue * 100
        let text = Formatters.compactDecimal.string(from: NSNumber(value: percentage)) ?? "0"
        return "\(text)%"
    }

    var effectiveGoal: EffectiveGoal? {
        guard let profile, let currentWeightKilograms else { return nil }
        return GoalLogic.effectiveGoal(
            currentWeightKilograms: currentWeightKilograms,
            configuration: profile.goalConfiguration,
            referenceDate: .now
        )
    }

    var isTargetMode: Bool {
        profile?.goalMode == .target
    }

    var goalCardTitle: String {
        isTargetMode ? "Target" : "Goal"
    }

    var goalSummaryDisplay: String {
        guard let profile else { return "--" }

        if profile.goalMode == .target {
            if let targetDate = profile.targetDate {
                return "\(targetWeightDisplay) by \(Formatters.date.string(from: targetDate))"
            }
            return targetWeightDisplay
        }

        switch profile.goalType {
        case .maintenance:
            return GoalType.maintenance.title
        case .loss, .gain:
            let pace = profile.resolvedWeeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek
            let paceText = Formatters.compactDecimal.string(from: NSNumber(value: pace)) ?? "0.5"
            return "\(profile.goalType.title) · \(paceText) \(UnitSystem.metric.weightUnit)/week"
        }
    }

    var goalButtonDisplay: String {
        guard let profile else { return "--" }

        if profile.goalMode == .target {
            return targetWeightDisplay
        }

        switch profile.goalType {
        case .loss:
            return "Lose"
        case .gain:
            return "Gain"
        case .maintenance:
            return "Maintain"
        }
    }

    var goalSheetPaceDisplay: String {
        guard let profile else { return "--" }

        switch profile.goalMode {
        case .target:
            guard let pace = effectiveGoal?.weeklyPaceKilograms else { return "--" }
            let paceText = Formatters.compactDecimal.string(from: NSNumber(value: pace)) ?? "--"
            return "\(paceText) \(UnitSystem.metric.weightUnit)/week"
        case .generic:
            guard profile.goalType != .maintenance else { return "Not set for maintenance" }
            let pace = profile.resolvedWeeklyPaceKilograms ?? WeeklyPaceOption.half.kilogramsPerWeek
            let paceText = Formatters.compactDecimal.string(from: NSNumber(value: pace)) ?? "0.5"
            return "\(paceText) \(UnitSystem.metric.weightUnit)/week"
        }
    }

    var heroSupportingText: String {
        guard isTargetMode else { return "" }

        if let targetDate = profile?.targetDate {
            return "by \(Formatters.date.string(from: targetDate))"
        }
        return ""
    }

    var targetDateDisplay: String {
        guard let targetDate = profile?.targetDate else { return "--" }
        return Formatters.date.string(from: targetDate)
    }

    var targetModeWarning: String? {
        guard effectiveGoal?.isAggressiveWarning == true else { return nil }
        return "This target date implies more than 1.0 kg per week."
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

    private var isInMainDestination: Bool {
        if case .main = destination {
            return true
        }
        return false
    }

    private func syncReminderPreferences() {
        isDailyReminderEnabled = reminderPreferences.isReminderEnabled()
        reminderTimeSelection = reminderPreferences.reminderTimeDate()
    }

    private func refreshReminderState() {
        Task {
            await refreshReminderAuthorizationStatus()
            await rebuildReminderSchedule()
        }
    }

    private func refreshReminderAuthorizationStatus() async {
        guard let reminderService else { return }
        reminderAuthorizationStatus = await reminderService.authorizationStatus()
    }

    private func requestReminderAuthorizationIfNeeded() async -> ReminderAuthorizationStatus {
        guard let reminderService else { return .denied }

        let currentStatus = await reminderService.authorizationStatus()
        switch currentStatus {
        case .authorized, .denied:
            reminderAuthorizationStatus = currentStatus
            return currentStatus
        case .notDetermined:
            let requestedStatus = await reminderService.requestAuthorization()
            reminderAuthorizationStatus = requestedStatus
            return requestedStatus
        }
    }

    private func rebuildReminderSchedule() async {
        guard let reminderService else { return }

        syncReminderPreferences()

        guard isInMainDestination,
              hasAccount,
              profile != nil,
              isDailyReminderEnabled,
              reminderAuthorizationStatus == .authorized else {
            await reminderService.removeAllReminders()
            return
        }

        let reminderDates = ReminderPlanner.scheduleDates(
            now: .now,
            preferredTime: reminderPreferences.reminderTimeComponents(),
            entries: entries,
            horizonDays: 60
        )

        await reminderService.replaceReminders(dates: reminderDates)
    }
}

enum ValidationError: LocalizedError {
    case invalidMetrics
    case invalidWeightEntry
    case futureWeightEntryDate

    var errorDescription: String? {
        switch self {
        case .invalidMetrics:
            return "Please complete all body metrics with valid values."
        case .invalidWeightEntry:
            return "Please enter a valid weight before saving."
        case .futureWeightEntryDate:
            return "Future dates are not allowed. Please select today or an earlier date."
        }
    }
}

struct WeeklyAverageRow: Identifiable {
    let date: Date
    let value: String

    var id: Date { date }
}

enum ReminderSetupMode {
    case firstPrompt
    case editTime

    var title: String {
        switch self {
        case .firstPrompt:
            return "Daily Reminders"
        case .editTime:
            return "Reminder Time"
        }
    }

    var subtitle: String {
        switch self {
        case .firstPrompt:
            return "Choose when BeFit should remind you to log your weight."
        case .editTime:
            return "Update the time BeFit should remind you each day."
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .firstPrompt:
            return "Allow Notifications"
        case .editTime:
            return "Save Time"
        }
    }

    var secondaryActionTitle: String {
        switch self {
        case .firstPrompt:
            return "Not Now"
        case .editTime:
            return "Cancel"
        }
    }
}

enum ReminderAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

struct ReminderPreferencesStore {
    private let enabledKey = "befit.reminders.enabled"
    private let hourKey = "befit.reminders.hour"
    private let minuteKey = "befit.reminders.minute"
    private let promptHandledKey = "befit.reminders.prompt-handled"

    func isReminderEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    func setReminderEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
    }

    func hasHandledInitialPrompt() -> Bool {
        UserDefaults.standard.bool(forKey: promptHandledKey)
    }

    func setHasHandledInitialPrompt(_ hasHandled: Bool) {
        UserDefaults.standard.set(hasHandled, forKey: promptHandledKey)
    }

    func reminderTimeComponents() -> DateComponents {
        let storedHour = UserDefaults.standard.object(forKey: hourKey) as? Int
        let storedMinute = UserDefaults.standard.object(forKey: minuteKey) as? Int

        return DateComponents(
            hour: storedHour ?? 8,
            minute: storedMinute ?? 0
        )
    }

    func reminderTimeDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = reminderTimeComponents()
        return calendar.date(
            bySettingHour: components.hour ?? 8,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    func setReminderTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(components.hour ?? 8, forKey: hourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: minuteKey)
    }

    static func defaultTimeDate() -> Date {
        ReminderPreferencesStore().reminderTimeDate()
    }
}

enum ReminderPlanner {
    static func scheduleDates(
        now: Date,
        preferredTime: DateComponents,
        entries: [WeightEntryRecord],
        horizonDays: Int
    ) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        return (0..<horizonDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  !loggedDays.contains(day),
                  let scheduledDate = calendar.date(
                    bySettingHour: preferredTime.hour ?? 8,
                    minute: preferredTime.minute ?? 0,
                    second: 0,
                    of: day
                  ),
                  scheduledDate > now else {
                return nil
            }

            return scheduledDate
        }
    }
}

protocol ReminderNotificationService {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async -> ReminderAuthorizationStatus
    func replaceReminders(dates: [Date]) async
    func removeAllReminders() async
}

struct LocalReminderNotificationService: ReminderNotificationService {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "befit.weight-reminder."

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> ReminderAuthorizationStatus {
        let granted = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }

        if granted {
            return .authorized
        }

        return await authorizationStatus()
    }

    func replaceReminders(dates: [Date]) async {
        await removeAllReminders()

        let calendar = Calendar.current

        for date in dates {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let content = UNMutableNotificationContent()
            content.title = "Log your weight"
            content.body = "Open BeFit and add today's check-in."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(identifierPrefix)\(Int(date.timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func removeAllReminders() async {
        let pendingRequests = await pendingRequests()
        let identifiers = pendingRequests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
