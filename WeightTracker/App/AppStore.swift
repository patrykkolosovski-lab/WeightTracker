import Combine
import Foundation
import OSLog
import StoreKit
import SwiftData
import SwiftUI
import UIKit

@MainActor
/// Root application state for BeFit.
///
/// `AppStore` coordinates startup, local persistence, background iCloud sync,
/// reminders, and Premium state while exposing a single observable surface to
/// SwiftUI views.
final class AppStore: ObservableObject {
    @Published var destination: RootDestination = .loading
    @Published var selectedTab: AppTab = .home
    @Published var activeWeightEntryID: UUID?
    @Published var isWeightEntrySheetPresented = false
    @Published var isReminderSetupPresented = false
    @Published var reminderSetupMode: ReminderSetupMode = .firstPrompt
    @Published var reminderTimeSelection = ReminderPreferencesStore.defaultTimeDate()
    @Published var isNotificationSettingsAlertPresented = false
    @Published var isICloudInfoPresented = false

    @Published private(set) var profile: ProfileRecord?
    @Published private(set) var entries: [WeightEntryRecord] = []
    @Published private(set) var reminderAuthorizationStatus: ReminderAuthorizationStatus = .notDetermined
    @Published private(set) var isDailyReminderEnabled = false
    @Published private(set) var lastSyncErrorMessage: String?
    @Published private(set) var iCloudAvailability: ICloudAccountAvailability = .couldNotDetermine(nil)
    @Published private(set) var iCloudSyncState: ICloudSyncState = .checkingAccount
    @Published private(set) var lastSuccessfulSyncDate: Date?
    @Published private(set) var isPremiumUnlocked = false
    @Published private(set) var premiumDisplayPrice: String?
    @Published private(set) var isPremiumPurchaseInFlight = false
    @Published private(set) var premiumErrorMessage: String?
    @Published var isPremiumManagementConfirmationPresented = false

    private var isConfigured = false
    private var premiumUpdatesTask: Task<Void, Never>?
    private var activeLocalUserIDString: String?
    private var isSyncInFlight = false
    private var hasResolvedInitialDestination = false

    private var localDataStore: LocalDataStore?
    private let bootstrapCoordinator = BootstrapCoordinator()
    private let iCloudSyncService = ICloudSyncService.shared
    private let iCloudInfoPreferences = ICloudInfoPromptStore()
    private let metricsCoordinator = MetricsCoordinator()
    private let weightEntryCoordinator = WeightEntryCoordinator()
    private let reminderCoordinator = ReminderCoordinator()
    private let premiumCoordinator = PremiumCoordinator()
    private var reminderService: ReminderNotificationService?
    private let logger = Logger(subsystem: "WeightTracker", category: "AppStore")

    deinit {
        premiumUpdatesTask?.cancel()
    }

    /// Performs one-time store setup for the current process and restores the
    /// latest local dataset before any UI route is finalized.
    func configureIfNeeded(modelContext: ModelContext) async {
        guard !isConfigured else { return }

        localDataStore = LocalDataStore(modelContext: modelContext)
        reminderService = LocalReminderNotificationService()
        isConfigured = true

        applyReminderPreferenceSnapshot()
        restoreCachedPremiumState()
        startPremiumObservationIfNeeded()
        lastSuccessfulSyncDate = await iCloudSyncService.cachedLastSuccessfulSyncDate()
        await restoreSessionIfPossible()
        await refreshPremiumSubscriptionState()
        refreshReminderState()
        presentICloudInfoIfNeeded()
    }

    func refreshSessionState() async {
        await restoreSessionIfPossible()
    }

    /// Resolves the app launch route from local data first, then refreshes
    /// iCloud availability and sync state in the background.
    func restoreSessionIfPossible() async {
        guard isConfigured, let localDataStore else { return }

        if !hasResolvedInitialDestination {
            destination = .loading
        }

        do {
            try prepareLocalDataForICloud(using: localDataStore)
        } catch {
            lastSyncErrorMessage = error.localizedDescription
            logger.error("Failed to prepare local iCloud dataset: \(error.localizedDescription, privacy: .public)")
        }

        if hasRestorableMainContentForActiveAccount {
            destination = .main
        }

        await refreshICloudStateAndSynchronize(
            presentLoadingState: !hasResolvedInitialDestination && !hasRestorableMainContentForActiveAccount
        )

        if destination == .loading {
            updateDestinationForAvailableLocalState()
        }

        hasResolvedInitialDestination = true
    }

    func retryICloudSync() {
        Task {
            await refreshICloudStateAndSynchronize(presentLoadingState: false, forceSync: true)
        }
    }

    func dismissICloudInfo() {
        iCloudInfoPreferences.setHasShownPrompt(true)
        isICloudInfoPresented = false
    }

    /// Saves profile metrics locally, upserts today's weight entry, and then
    /// triggers a background cloud sync.
    func saveMetrics(form: MetricsFormState) throws {
        guard let userIDString = activeLocalUserIDString,
              let localDataStore else {
            throw AppStateError.missingLocalAccountState
        }

        let saveResult = try metricsCoordinator.saveMetrics(
            form: form,
            userIDString: userIDString,
            existingEntries: entries,
            localDataStore: localDataStore
        )

        profile = saveResult.profile
        upsertInMemoryEntry(saveResult.weightEntry, userIDString: userIDString)
        selectedTab = .home
        destination = .main
        lastSyncErrorMessage = nil
        logger.debug("Saved metrics locally for user \(userIDString, privacy: .public)")
        refreshReminderState()
        Task { await self.syncAfterLocalMutation() }
    }

    func updatePreferredUnitSystem(_ unitSystem: UnitSystem) {
        guard let activeLocalUserIDString,
              let localDataStore,
              let currentProfile = profile,
              let latestWeightKilograms = currentWeightKilograms else { return }

        do {
            try metricsCoordinator.updatePreferredUnitSystem(
                unitSystem,
                userIDString: activeLocalUserIDString,
                currentProfile: currentProfile,
                latestWeightKilograms: latestWeightKilograms,
                localDataStore: localDataStore
            )
            loadLocalCache(for: activeLocalUserIDString)
            Task { await self.syncAfterLocalMutation() }
        } catch {
            loadLocalCache(for: activeLocalUserIDString)
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

    /// Saves a manual weight entry while enforcing the one-entry-per-day rule.
    func saveWeightEntry(form: WeightEntryFormState) throws {
        guard let activeLocalUserIDString,
              let localDataStore else {
            throw AppStateError.missingLocalAccountState
        }

        let savedEntry = try weightEntryCoordinator.saveWeightEntry(
            form: form,
            activeWeightEntryID: activeWeightEntryID,
            userIDString: activeLocalUserIDString,
            localDataStore: localDataStore
        )

        dismissWeightEntrySheet()
        if let savedEntry {
            upsertInMemoryEntry(savedEntry, userIDString: activeLocalUserIDString)
        } else {
            loadLocalCache(for: activeLocalUserIDString)
        }
        refreshReminderState()
        Task { await self.syncAfterLocalMutation() }
    }

    func handleHomeAppeared() {
        guard isInMainDestination else { return }
        applyReminderPreferenceSnapshot()

        if reminderAuthorizationStatus == .notDetermined,
           !reminderCoordinator.hasHandledInitialPrompt() {
            reminderSetupMode = .firstPrompt
            reminderTimeSelection = reminderCoordinator.reminderTimeDate()
            isReminderSetupPresented = true
            return
        }

        refreshReminderState()
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase == .active else { return }
        Task {
            await refreshSessionState()
            await refreshPremiumSubscriptionState()
        }
        refreshReminderState()
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) {
        applyReminderPreferenceSnapshot()

        if !isEnabled {
            reminderCoordinator.setReminderEnabled(false)
            applyReminderPreferenceSnapshot()
            Task {
                await reminderService?.removeAllReminders()
            }
            return
        }

        switch reminderAuthorizationStatus {
        case .authorized:
            reminderCoordinator.setReminderEnabled(true)
            applyReminderPreferenceSnapshot()
            refreshReminderState()
        case .notDetermined:
            reminderSetupMode = .firstPrompt
            reminderTimeSelection = reminderCoordinator.reminderTimeDate()
            isReminderSetupPresented = true
        case .denied:
            isNotificationSettingsAlertPresented = true
        }
    }

    func presentReminderTimeEditor() {
        reminderSetupMode = .editTime
        reminderTimeSelection = reminderCoordinator.reminderTimeDate()
        isReminderSetupPresented = true
    }

    func dismissReminderSetup() {
        if reminderSetupMode == .firstPrompt {
            reminderCoordinator.setReminderTime(reminderTimeSelection)
            reminderCoordinator.setHasHandledInitialPrompt(true)
            applyReminderPreferenceSnapshot()
        }

        isReminderSetupPresented = false
    }

    func confirmReminderSetup() async {
        reminderCoordinator.setReminderTime(reminderTimeSelection)

        switch reminderSetupMode {
        case .firstPrompt:
            reminderCoordinator.setHasHandledInitialPrompt(true)
            let status = await requestReminderAuthorizationIfNeeded()
            if status == .authorized {
                reminderCoordinator.setReminderEnabled(true)
            } else {
                reminderCoordinator.setReminderEnabled(false)
            }
        case .editTime:
            break
        }

        applyReminderPreferenceSnapshot()
        isReminderSetupPresented = false
        await rebuildReminderSchedule()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func handlePremiumButtonTap() {
        premiumErrorMessage = nil

        if isPremiumUnlocked {
            isPremiumManagementConfirmationPresented = true
            return
        }

        Task { await purchasePremiumSubscription() }
    }

    func cancelPremiumManagementConfirmation() {
        isPremiumManagementConfirmationPresented = false
    }

    func confirmPremiumManagement() {
        isPremiumManagementConfirmationPresented = false
        Task { await openPremiumManagement() }
    }

    func entryForEditing() -> WeightEntryRecord? {
        guard let activeWeightEntryID else { return nil }
        return entries.first(where: { $0.id == activeWeightEntryID })
    }

    var hasAccount: Bool {
        activeLocalUserIDString != nil
    }

    var iCloudStatusTitle: String {
        switch iCloudSyncState {
        case .checkingAccount:
            return "Checking iCloud"
        case .localOnly:
            return "Local Only"
        case .waitingForICloud:
            return "Waiting for iCloud"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .error:
            return "Sync Error"
        }
    }

    var iCloudStatusAccent: Color {
        switch iCloudSyncState {
        case .synced:
            return BeFitTheme.success
        case .syncing, .checkingAccount:
            return BeFitTheme.warning
        case .localOnly, .waitingForICloud, .error:
            return BeFitTheme.heart
        }
    }

    var lastSuccessfulSyncDisplay: String {
        guard let lastSuccessfulSyncDate else { return "--" }
        return Formatters.dateTime.string(from: lastSuccessfulSyncDate)
    }

    var premiumButtonTitle: String {
        isPremiumUnlocked ? "Premium Unlocked" : "Unlock Premium"
    }

    var premiumButtonSubtitle: String {
        if isPremiumPurchaseInFlight {
            return "Connecting to the App Store..."
        }

        if isPremiumUnlocked {
            if let premiumDisplayPrice {
                return "\(premiumDisplayPrice) monthly is active. Tap to manage or cancel in Apple subscriptions."
            }

            return "Premium is active. Tap to manage or cancel in Apple subscriptions."
        }

        if let premiumDisplayPrice {
            return "\(premiumDisplayPrice) per month. Adds a premium crown to the BeFit title."
        }

        return "Monthly subscription. Adds a premium crown to the BeFit title."
    }

    var unitSystem: UnitSystem {
        profile?.preferredUnitSystem ?? .metric
    }

    var reminderTimeDisplay: String {
        reminderCoordinator.reminderTimeDisplay()
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

    private func updateDestinationForAvailableLocalState() {
        guard activeLocalUserIDString != nil else {
            destination = .metricsOnboarding
            return
        }

        destination = bootstrapCoordinator.destination(hasSavedProfile: hasRestorableMainContentForActiveAccount)
    }

    private var isInMainDestination: Bool {
        if case .main = destination {
            return true
        }
        return false
    }

    /// Reloads the active local profile and canonical weight timeline into
    /// memory without discarding the last known good state on transient errors.
    private func loadLocalCache(for userIDString: String) {
        guard let localDataStore else { return }

        activeLocalUserIDString = userIDString
        let previousProfile = profile?.userIDString == userIDString ? profile : nil
        let previousEntries = entries.filter { $0.userIDString == userIDString }

        do {
            if let fetchedProfile = try localDataStore.fetchProfile(userIDString: userIDString) {
                profile = fetchedProfile
                try? localDataStore.markProfileCompleted(userIDString: userIDString)
            } else {
                profile = previousProfile
            }
        } catch {
            profile = previousProfile
            logger.error("Failed to load profile cache for user \(userIDString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        do {
            let fetchedEntries = try localDataStore.fetchCanonicalEntries(userIDString: userIDString)
            if fetchedEntries.isEmpty, !previousEntries.isEmpty {
                entries = previousEntries
            } else {
                entries = fetchedEntries
            }
        } catch {
            entries = previousEntries
            logger.error("Failed to load entry cache for user \(userIDString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func upsertInMemoryEntry(_ entry: WeightEntryRecord, userIDString: String) {
        guard entry.userIDString == userIDString else { return }

        var currentEntries = entries.filter { $0.userIDString == userIDString && $0.id != entry.id }
        currentEntries.append(entry)
        entries = WeightTimelineNormalizer.normalize(records: currentEntries).canonicalEntries
    }

    private func prepareLocalDataForICloud(using localDataStore: LocalDataStore) throws {
        let userIDString = try bootstrapCoordinator.prepareLocalData(localDataStore: localDataStore)
        activeLocalUserIDString = userIDString
        loadLocalCache(for: userIDString)
    }

    private var hasActiveProfileForActiveAccount: Bool {
        guard let activeLocalUserIDString else { return false }
        return profile?.userIDString == activeLocalUserIDString
    }

    private var hasRestorableMainContentForActiveAccount: Bool {
        hasActiveProfileForActiveAccount
    }

    private func refreshICloudStateAndSynchronize(
        presentLoadingState: Bool,
        forceSync: Bool = false
    ) async {
        if presentLoadingState {
            destination = .loading
        }

        let availability = await iCloudSyncService.accountAvailability()
        iCloudAvailability = availability

        switch availability {
        case .available:
            do {
                try await synchronizeCurrentUser(forceSync: forceSync)
            } catch {
                lastSyncErrorMessage = error.localizedDescription
                iCloudSyncState = .error
                logger.error("iCloud sync failed: \(error.localizedDescription, privacy: .public)")
                updateDestinationForAvailableLocalState()
            }
        case .noAccount:
            lastSyncErrorMessage = nil
            iCloudSyncState = hasRestorableMainContentForActiveAccount ? .localOnly : .waitingForICloud
            updateDestinationForAvailableLocalState()
        case .temporarilyUnavailable:
            lastSyncErrorMessage = nil
            iCloudSyncState = .waitingForICloud
            updateDestinationForAvailableLocalState()
        case .restricted:
            lastSyncErrorMessage = "iCloud access is restricted on this device."
            iCloudSyncState = .localOnly
            updateDestinationForAvailableLocalState()
        case .couldNotDetermine(let message):
            lastSyncErrorMessage = message
            iCloudSyncState = .localOnly
            updateDestinationForAvailableLocalState()
        }

        refreshReminderState()
    }

    /// Reconciles the active local dataset with the user's private iCloud
    /// records. Local writes remain authoritative until they are uploaded.
    private func synchronizeCurrentUser(forceSync: Bool = false) async throws {
        guard let localDataStore,
              let userIDString = activeLocalUserIDString else { return }

        _ = forceSync

        guard !isSyncInFlight else { return }
        isSyncInFlight = true
        defer { isSyncInFlight = false }

        iCloudSyncState = .syncing
        logger.debug("Starting iCloud sync for local dataset \(userIDString, privacy: .public)")

        let remoteSnapshot = try await iCloudSyncService.fetchSnapshot()
        let normalizedRemoteEntries = bootstrapCoordinator.normalizeRemoteEntries(remoteSnapshot.entries)
        if let remoteProfile = remoteSnapshot.profile {
            _ = try localDataStore.saveSyncedProfile(remoteProfile, userIDString: userIDString)
            try? localDataStore.markProfileCompleted(userIDString: userIDString)
        }
        if !normalizedRemoteEntries.canonicalEntries.isEmpty {
            try localDataStore.saveSyncedEntries(normalizedRemoteEntries.canonicalEntries, userIDString: userIDString)
        }
        if normalizedRemoteEntries.hasDuplicates {
            try await iCloudSyncService.deleteEntries(with: normalizedRemoteEntries.duplicateEntryIDs)
        }

        let localNormalization = try localDataStore.normalizeEntryTimeline(userIDString: userIDString)
        if localNormalization.hasDuplicates {
            try await iCloudSyncService.deleteEntries(with: localNormalization.duplicateEntryIDs)
        }

        loadLocalCache(for: userIDString)

        let pendingProfile = if let profile,
            profile.userIDString == userIDString,
            profile.needsSync {
            SyncedProfileSnapshot(record: profile)
        } else {
            try localDataStore.pendingProfile(userIDString: userIDString).map(SyncedProfileSnapshot.init(record:))
        }

        if let pendingProfile {
            logger.debug("Uploading pending profile to iCloud")
            let savedProfile = try await iCloudSyncService.saveProfile(pendingProfile)
            _ = try localDataStore.saveSyncedProfile(
                savedProfile,
                userIDString: userIDString
            )
        }

        let inMemoryPendingEntries = entries
            .filter { $0.userIDString == userIDString && $0.needsSync }
            .sorted { $0.updatedAt < $1.updatedAt }
        let pendingEntries = inMemoryPendingEntries.isEmpty
            ? try localDataStore.pendingEntries(userIDString: userIDString)
            : inMemoryPendingEntries

        for pendingEntry in pendingEntries {
            logger.debug("Uploading pending weight entry \(pendingEntry.id.uuidString, privacy: .public) to iCloud")
            let savedEntry = try await iCloudSyncService.saveEntry(
                SyncedWeightEntrySnapshot(record: pendingEntry)
            )
            try localDataStore.saveSyncedEntry(savedEntry, userIDString: userIDString)
        }

        lastSyncErrorMessage = nil
        iCloudSyncState = .synced
        lastSuccessfulSyncDate = .now
        await iCloudSyncService.recordSuccessfulSync(at: lastSuccessfulSyncDate ?? .now)
        loadLocalCache(for: userIDString)
        updateDestinationForAvailableLocalState()
        refreshReminderState()
    }

    private func syncAfterLocalMutation() async {
        await refreshICloudStateAndSynchronize(presentLoadingState: false)
    }

    private func restoreCachedPremiumState() {
        isPremiumUnlocked = premiumCoordinator.restoreCachedState()
    }

    private func presentICloudInfoIfNeeded() {
        guard !iCloudInfoPreferences.hasShownPrompt() else { return }
        isICloudInfoPresented = true
    }

    private func startPremiumObservationIfNeeded() {
        guard premiumUpdatesTask == nil else { return }

        premiumUpdatesTask = Task { [weak self] in
            guard let self else { return }

            for await update in premiumCoordinator.transactionUpdates {
                await premiumCoordinator.finishIfNeeded(update)
                await self.refreshPremiumSubscriptionState()
            }
        }
    }

    private func refreshPremiumSubscriptionState(shouldSurfaceErrors: Bool = false) async {
        let storefrontState = await premiumCoordinator.refreshState()
        isPremiumUnlocked = storefrontState.isUnlocked
        premiumDisplayPrice = storefrontState.displayPrice

        if !storefrontState.isUnlocked {
            isPremiumManagementConfirmationPresented = false
        }

        if shouldSurfaceErrors {
            premiumErrorMessage = nil
        }
    }

    private func purchasePremiumSubscription() async {
        guard !isPremiumPurchaseInFlight else { return }

        isPremiumPurchaseInFlight = true
        premiumErrorMessage = nil
        defer { isPremiumPurchaseInFlight = false }

        do {
            let result = try await premiumCoordinator.purchasePremium()
            switch result {
            case .purchased:
                await refreshPremiumSubscriptionState(shouldSurfaceErrors: true)
            case .cancelled:
                break
            case .pending:
                premiumErrorMessage = "Premium purchase is pending approval."
            }
        } catch {
            logger.error("Premium purchase failed: \(error.localizedDescription, privacy: .public)")
            premiumErrorMessage = error.localizedDescription
        }
    }

    private func openPremiumManagement() async {
        premiumErrorMessage = nil

        do {
            try await premiumCoordinator.openManageSubscriptions()
        } catch {
            logger.error("Opening Premium management failed: \(error.localizedDescription, privacy: .public)")
            premiumErrorMessage = error.localizedDescription
        }
    }

    private func applyReminderPreferenceSnapshot() {
        let snapshot = reminderCoordinator.preferenceSnapshot()
        isDailyReminderEnabled = snapshot.isReminderEnabled
        reminderTimeSelection = snapshot.reminderTimeSelection
    }

    private func refreshReminderState() {
        Task {
            await refreshReminderAuthorizationStatus()
            await rebuildReminderSchedule()
        }
    }

    private func refreshReminderAuthorizationStatus() async {
        reminderAuthorizationStatus = await reminderCoordinator.refreshAuthorizationStatus(
            using: reminderService
        )
    }

    private func requestReminderAuthorizationIfNeeded() async -> ReminderAuthorizationStatus {
        let requestedStatus = await reminderCoordinator.requestAuthorizationIfNeeded(
            currentStatus: reminderAuthorizationStatus,
            using: reminderService
        )
        reminderAuthorizationStatus = requestedStatus
        return requestedStatus
    }

    private func rebuildReminderSchedule() async {
        applyReminderPreferenceSnapshot()
        await reminderCoordinator.rebuildSchedule(
            using: reminderService,
            isInMainDestination: isInMainDestination,
            hasAccount: hasAccount,
            profile: profile,
            entries: entries,
            reminderAuthorizationStatus: reminderAuthorizationStatus
        )
    }
}

struct WeeklyAverageRow: Identifiable {
    let date: Date
    let value: String

    var id: Date { date }
}

struct ICloudInfoPromptStore {
    private let shownKey = "befit.icloud-info.shown"

    func hasShownPrompt() -> Bool {
        UserDefaults.standard.bool(forKey: shownKey)
    }

    func setHasShownPrompt(_ hasShown: Bool) {
        UserDefaults.standard.set(hasShown, forKey: shownKey)
    }
}
