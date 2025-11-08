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
    @AppStorage("textScalePreference") private var textScalePreference = "large"

    private var mappedDynamicTypeSize: DynamicTypeSize {
        switch textScalePreference {
        case "normal": return .large
        case "xlarge": return .accessibility2
        default: return .accessibility1
        }
    }

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
        .dynamicTypeSize(mappedDynamicTypeSize)
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
