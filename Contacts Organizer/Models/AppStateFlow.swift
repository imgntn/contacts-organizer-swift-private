import Contacts

struct AppStateFlow {
    var hasCompletedOnboarding: Bool
    var authorizationStatus: CNAuthorizationStatus

    var currentView: AppState.AppView {
        if !hasCompletedOnboarding {
            return .onboarding
        }
        if authorizationStatus != .authorized {
            return .permissionRequest
        }
        return .dashboard
    }

    mutating func markOnboardingComplete() -> AppState.AppView {
        hasCompletedOnboarding = true
        return currentView
    }

    mutating func updateAuthorizationStatus(_ status: CNAuthorizationStatus) -> AppState.AppView {
        authorizationStatus = status
        return currentView
    }
}
