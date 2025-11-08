//
//  AppState.swift
//  Contacts Organizer
//
//  Manages the overall application state and navigation
//

import SwiftUI
import Contacts

class AppState: ObservableObject {
    @Published var currentView: AppView = .loading
    @Published var hasCompletedOnboarding: Bool = false
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined

    enum AppView {
        case loading
        case onboarding
        case permissionRequest
        case dashboard
    }

    init() {
        // Check if user has completed onboarding
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Check current authorization status
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

        // Determine initial view
        updateCurrentView()
    }

    func updateCurrentView() {
        if !hasCompletedOnboarding {
            currentView = .onboarding
        } else if authorizationStatus != .authorized {
            currentView = .permissionRequest
        } else {
            currentView = .dashboard
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        updateCurrentView()
    }

    func updateAuthorizationStatus(_ status: CNAuthorizationStatus) {
        authorizationStatus = status
        updateCurrentView()
    }
}
