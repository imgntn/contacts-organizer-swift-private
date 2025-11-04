//
//  ContentView.swift
//  Contacts Organizer
//
//  Main view that routes to appropriate screens based on app state
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager

    var body: some View {
        Group {
            switch appState.currentView {
            case .loading:
                LoadingView()

            case .onboarding:
                OnboardingView()

            case .permissionRequest:
                PermissionRequestView()

            case .dashboard:
                DashboardView()
            }
        }
        .onChange(of: contactsManager.authorizationStatus) { _, newStatus in
            appState.updateAuthorizationStatus(newStatus)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading...")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ContactsManager.shared)
}
