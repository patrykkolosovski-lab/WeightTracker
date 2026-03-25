import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()

    var body: some View {
        ZStack {
            BeFitBackground()

            switch store.destination {
            case .loading:
                ProgressView()
                    .tint(BeFitTheme.textPrimary)
            case .auth(let mode):
                AuthenticationView(store: store, mode: mode)
            case .emailVerification(let email):
                EmailVerificationView(store: store, email: email)
            case .metricsOnboarding:
                MetricsOnboardingView(store: store)
            case .main:
                MainShellView(store: store)
            }
        }
        .task {
            await store.configureIfNeeded(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newValue in
            store.handleScenePhaseChange(newValue)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [AccountRecord.self, ProfileRecord.self, WeightEntryRecord.self], inMemory: true)
}
