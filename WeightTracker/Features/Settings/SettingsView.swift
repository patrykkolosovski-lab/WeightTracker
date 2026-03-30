import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var activeInfoSheet: SettingsInfoSheet?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                premiumButton

                if let premiumErrorMessage = store.premiumErrorMessage {
                    Text(premiumErrorMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("iCloud Sync")
                        SettingsRow(
                            iconName: "icloud.fill",
                            title: "Status",
                            value: store.iCloudStatusTitle,
                            accent: store.iCloudStatusAccent
                        )
                        SettingsRow(
                            iconName: "clock.arrow.circlepath",
                            title: "Last Sync",
                            value: store.lastSuccessfulSyncDisplay,
                            accent: store.iCloudStatusAccent
                        )
                    }
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Notifications", subtitle: "Weight reminders on your schedule.")
                        SettingsToggleRow(
                            iconName: "bell.badge.fill",
                            title: "Daily Weight Reminder",
                            subtitle: store.reminderPermissionDisplay,
                            isOn: Binding(
                                get: { store.isDailyReminderEnabled },
                                set: { store.setDailyReminderEnabled($0) }
                            )
                        )
                        SettingsActionRow(
                            iconName: "clock.fill",
                            title: "Reminder Time",
                            value: store.reminderTimeDisplay,
                            accent: BeFitTheme.warning
                        ) {
                            store.presentReminderTimeEditor()
                        }

                        if store.shouldShowNotificationRecovery {
                            Button {
                                store.openSystemSettings()
                            } label: {
                                Text("Open iPhone Settings")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(BeFitTheme.warning)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(BeFitTheme.backgroundMiddle.opacity(0.95))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(BeFitTheme.warning.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("About & Privacy")
                        SettingsActionRow(
                            iconName: "questionmark.circle",
                            title: "Help",
                            value: ""
                        ) {
                            activeInfoSheet = .help
                        }
                        SettingsActionRow(
                            iconName: "info.circle",
                            title: "About BeFit",
                            value: ""
                        ) {
                            activeInfoSheet = .about
                        }
                        SettingsActionRow(
                            iconName: "lock.shield",
                            title: "Privacy",
                            value: ""
                        ) {
                            activeInfoSheet = .privacy
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .sheet(item: $activeInfoSheet) { sheet in
            SettingsInfoSheetView(sheet: sheet)
        }
        .alert("Manage Premium", isPresented: $store.isPremiumManagementConfirmationPresented) {
            Button("Keep Premium", role: .cancel) {
                store.cancelPremiumManagementConfirmation()
            }
            Button("Open Apple Subscriptions") {
                store.confirmPremiumManagement()
            }
        } message: {
            Text("BeFit will open Apple’s subscription management screen where you can cancel or manage Premium.")
        }
    }

    private var premiumButton: some View {
        Button {
            store.handlePremiumButtonTap()
        } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(BeFitTheme.premiumInk.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(BeFitTheme.premiumInk)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.premiumButtonTitle)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeFitTheme.premiumInk)

                    Text(store.premiumButtonSubtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.premiumInk.opacity(0.78))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                if store.isPremiumPurchaseInFlight {
                    ProgressView()
                        .tint(BeFitTheme.premiumInk)
                } else {
                    Image(systemName: store.isPremiumUnlocked ? "slider.horizontal.3" : "arrow.up.forward.app.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(BeFitTheme.premiumInk.opacity(0.8))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BeFitTheme.premiumTop, BeFitTheme.premiumMiddle, BeFitTheme.premiumBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: BeFitTheme.premiumGlow, radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(store.isPremiumPurchaseInFlight)
    }
}

enum SettingsInfoSheet: Identifiable {
    case help
    case about
    case privacy

    var id: String {
        switch self {
        case .help:
            return "help"
        case .about:
            return "about"
        case .privacy:
            return "privacy"
        }
    }
}
