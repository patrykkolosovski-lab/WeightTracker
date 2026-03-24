import SwiftUI

struct MainShellView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            BeFitHeader()

            Group {
                switch store.selectedTab {
                case .home:
                    HomeView(store: store)
                case .graph:
                    GraphView(store: store)
                case .metrics:
                    BodyMetricsView(store: store)
                case .settings:
                    SettingsView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BeFitTabBar(selectedTab: $store.selectedTab) {
                store.presentWeightEntrySheet()
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $store.isWeightEntrySheetPresented, onDismiss: {
            store.dismissWeightEntrySheet()
        }) {
            WeightEntrySheetView(store: store)
        }
    }
}
