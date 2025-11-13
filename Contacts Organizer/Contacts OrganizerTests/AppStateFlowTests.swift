import XCTest
import Contacts
@testable import Contacts_Organizer

final class AppStateFlowTests: XCTestCase {

    func testFlowTransitionsThroughOnboardingPermissionAndDashboard() {
        var flow = AppStateFlow(hasCompletedOnboarding: false, authorizationStatus: .denied)
        XCTAssertEqual(flow.currentView, .onboarding)

        let afterOnboarding = flow.markOnboardingComplete()
        XCTAssertEqual(afterOnboarding, .permissionRequest)

        let afterAuthorization = flow.updateAuthorizationStatus(.authorized)
        XCTAssertEqual(afterAuthorization, .dashboard)
    }

    func testFlowReflectsAuthorizationChangesImmediately() {
        var flow = AppStateFlow(hasCompletedOnboarding: true, authorizationStatus: .denied)
        XCTAssertEqual(flow.currentView, .permissionRequest)

        _ = flow.updateAuthorizationStatus(.authorized)
        XCTAssertEqual(flow.currentView, .dashboard)

        _ = flow.updateAuthorizationStatus(.restricted)
        XCTAssertEqual(flow.currentView, .permissionRequest)
    }
}
