import Foundation

struct ReminderPreferencesSnapshot {
    let isReminderEnabled: Bool
    let reminderTimeSelection: Date
}

struct ReminderCoordinator {
    private let preferencesStore: ReminderPreferencesStore

    init(preferencesStore: ReminderPreferencesStore = ReminderPreferencesStore()) {
        self.preferencesStore = preferencesStore
    }

    func preferenceSnapshot() -> ReminderPreferencesSnapshot {
        ReminderPreferencesSnapshot(
            isReminderEnabled: preferencesStore.isReminderEnabled(),
            reminderTimeSelection: preferencesStore.reminderTimeDate()
        )
    }

    func reminderTimeDisplay() -> String {
        Formatters.time.string(from: preferencesStore.reminderTimeDate())
    }

    func reminderTimeDate() -> Date {
        preferencesStore.reminderTimeDate()
    }

    func hasHandledInitialPrompt() -> Bool {
        preferencesStore.hasHandledInitialPrompt()
    }

    func setHasHandledInitialPrompt(_ hasHandled: Bool) {
        preferencesStore.setHasHandledInitialPrompt(hasHandled)
    }

    func setReminderEnabled(_ isEnabled: Bool) {
        preferencesStore.setReminderEnabled(isEnabled)
    }

    func setReminderTime(_ date: Date) {
        preferencesStore.setReminderTime(date)
    }

    func reminderTimeComponents() -> DateComponents {
        preferencesStore.reminderTimeComponents()
    }

    func refreshAuthorizationStatus(
        using reminderService: ReminderNotificationService?
    ) async -> ReminderAuthorizationStatus {
        guard let reminderService else { return .denied }
        return await reminderService.authorizationStatus()
    }

    func requestAuthorizationIfNeeded(
        currentStatus: ReminderAuthorizationStatus,
        using reminderService: ReminderNotificationService?
    ) async -> ReminderAuthorizationStatus {
        guard let reminderService else { return .denied }

        switch currentStatus {
        case .authorized, .denied:
            return currentStatus
        case .notDetermined:
            return await reminderService.requestAuthorization()
        }
    }

    func rebuildSchedule(
        using reminderService: ReminderNotificationService?,
        isInMainDestination: Bool,
        hasAccount: Bool,
        profile: ProfileRecord?,
        entries: [WeightEntryRecord],
        reminderAuthorizationStatus: ReminderAuthorizationStatus
    ) async {
        guard let reminderService else { return }

        let snapshot = preferenceSnapshot()

        guard isInMainDestination,
              hasAccount,
              profile != nil,
              snapshot.isReminderEnabled,
              reminderAuthorizationStatus == .authorized else {
            await reminderService.removeAllReminders()
            return
        }

        let reminderDates = ReminderPlanner.scheduleDates(
            now: .now,
            preferredTime: reminderTimeComponents(),
            entries: entries,
            horizonDays: 60
        )

        await reminderService.replaceReminders(dates: reminderDates)
    }
}
