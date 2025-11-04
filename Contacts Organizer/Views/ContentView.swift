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

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ContactsManager.shared)
}
