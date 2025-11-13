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
    private let defaults: UserDefaults
    private var flow: AppStateFlow

    enum AppView {
        case onboarding
        case permissionRequest
        case dashboard
    }

    init(
        userDefaults: UserDefaults = .standard,
        initialAuthorizationStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    ) {
        self.defaults = userDefaults
        // Read values from UserDefaults and system
        let hasCompletedOnboardingValue = defaults.bool(forKey: "hasCompletedOnboarding")
        let hasSeenBackupReminderValue = defaults.bool(forKey: "hasSeenBackupReminder")

        // Initialize all stored properties
        self.hasCompletedOnboarding = hasCompletedOnboardingValue
        self.hasSeenBackupReminder = hasSeenBackupReminderValue
        self.authorizationStatus = initialAuthorizationStatus
        self.flow = AppStateFlow(
            hasCompletedOnboarding: hasCompletedOnboardingValue,
            authorizationStatus: initialAuthorizationStatus
        )
        self.currentView = flow.currentView

        print("🔄 Initial view: \(currentView), Onboarding: \(hasCompletedOnboarding), Auth: \(authorizationStatus.rawValue)")
    }

    func updateCurrentView() {
        print("🔄 Updating view - Onboarding: \(hasCompletedOnboarding), Auth: \(authorizationStatus.rawValue)")

        flow.hasCompletedOnboarding = hasCompletedOnboarding
        flow.authorizationStatus = authorizationStatus
        currentView = flow.currentView
        print("→ Showing: \(currentView)")
    }

    func completeOnboarding() {
        print("✅ Onboarding completed")
        hasCompletedOnboarding = true
        defaults.set(true, forKey: "hasCompletedOnboarding")
        currentView = flow.markOnboardingComplete()
        print("→ Showing: \(currentView)")
    }

    func markBackupReminderSeen() {
        guard !hasSeenBackupReminder else { return }
        hasSeenBackupReminder = true
        defaults.set(true, forKey: "hasSeenBackupReminder")
    }

    func resetBackupReminder() {
        hasSeenBackupReminder = false
        defaults.set(false, forKey: "hasSeenBackupReminder")
    }

    func updateAuthorizationStatus(_ status: CNAuthorizationStatus) {
        print("🔐 Authorization status updated to: \(status.rawValue)")
        authorizationStatus = status
        currentView = flow.updateAuthorizationStatus(status)
        print("→ Showing: \(currentView)")
    }
}

extension AppState: OverviewAppStateProviding {
    var hasSeenBackupReminderPublisher: AnyPublisher<Bool, Never> {
        $hasSeenBackupReminder.eraseToAnyPublisher()
    }
}
