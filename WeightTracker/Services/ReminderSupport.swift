import Foundation
import UserNotifications

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
