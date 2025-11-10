//
//  AppState.swift
//  Contacts Organizer
//
//  Manages the overall application state and navigation
//

import SwiftUI
import Contacts
import Combine

class AppState: ObservableObject {
    @Published var currentView: AppView
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasSeenBackupReminder: Bool = false
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined

    enum AppView {
        case onboarding
        case permissionRequest
        case dashboard
    }

    init() {
        // Read values from UserDefaults and system
        let hasCompletedOnboardingValue = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasSeenBackupReminderValue = UserDefaults.standard.bool(forKey: "hasSeenBackupReminder")
        let authStatusValue = CNContactStore.authorizationStatus(for: .contacts)

        // Initialize all stored properties
        self.hasCompletedOnboarding = hasCompletedOnboardingValue
        self.hasSeenBackupReminder = hasSeenBackupReminderValue
        self.authorizationStatus = authStatusValue

        // Determine initial view
        if !hasCompletedOnboardingValue {
            self.currentView = .onboarding
        } else if authStatusValue != .authorized {
            self.currentView = .permissionRequest
        } else {
            self.currentView = .dashboard
        }

        print("🔄 Initial view: \(currentView), Onboarding: \(hasCompletedOnboarding), Auth: \(authorizationStatus.rawValue)")
    }

    func updateCurrentView() {
        print("🔄 Updating view - Onboarding: \(hasCompletedOnboarding), Auth: \(authorizationStatus.rawValue)")

        if !hasCompletedOnboarding {
            currentView = .onboarding
            print("→ Showing: Onboarding")
        } else if authorizationStatus != .authorized {
            currentView = .permissionRequest
            print("→ Showing: Permission Request")
        } else {
            currentView = .dashboard
            print("→ Showing: Dashboard")
        }
    }

    func completeOnboarding() {
        print("✅ Onboarding completed")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        updateCurrentView()
    }

    func markBackupReminderSeen() {
        guard !hasSeenBackupReminder else { return }
        hasSeenBackupReminder = true
        UserDefaults.standard.set(true, forKey: "hasSeenBackupReminder")
    }

    func updateAuthorizationStatus(_ status: CNAuthorizationStatus) {
        print("🔐 Authorization status updated to: \(status.rawValue)")
        authorizationStatus = status
        updateCurrentView()
    }
}
