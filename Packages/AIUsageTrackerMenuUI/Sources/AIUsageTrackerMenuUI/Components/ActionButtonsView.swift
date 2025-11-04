import SwiftUI
import AIUsageTrackerLoginUI

@MainActor
struct ActionButtonsView: View {
    let isLoading: Bool
    let isLoggedIn: Bool
    let onRefresh: () -> Void
    let onLogin: () -> Void
    let onLogout: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if self.isLoading {
                ProgressView()
            } else {
                Button("Refresh") { self.onRefresh() }
            }

            if !self.isLoggedIn {
                Button("Log In") { self.onLogin() }
            } else {
                Button("Log Out") { self.onLogout() }
            }
            Button("Settings") { self.onSettings() }
        }
    }
}
