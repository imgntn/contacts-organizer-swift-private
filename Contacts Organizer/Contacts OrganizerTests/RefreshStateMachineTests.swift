import XCTest
@testable import Contacts_Organizer

final class RefreshStateMachineTests: XCTestCase {

    func testTriggerWhileIdleStartsRefresh() {
        var machine = RefreshStateMachine()
        let result = machine.handleTrigger(autoRefreshEnabled: true, isLoading: false, isAnalyzing: false)
        XCTAssertTrue(result)
        XCTAssertFalse(machine.consumePendingRefresh())
    }

    func testTriggerWhileBusyQueuesRefresh() {
        var machine = RefreshStateMachine()
        let result = machine.handleTrigger(autoRefreshEnabled: true, isLoading: true, isAnalyzing: false)
        XCTAssertFalse(result)
        XCTAssertTrue(machine.consumePendingRefresh())
    }

    func testPrepareForLoadReturnsFalseWhenBusy() {
        var machine = RefreshStateMachine()
        XCTAssertFalse(machine.prepareForLoad(isLoading: true, isAnalyzing: false))
        XCTAssertTrue(machine.consumePendingRefresh())
    }

    func testConsumePendingRefreshClearsFlag() {
        var machine = RefreshStateMachine()
        _ = machine.handleTrigger(autoRefreshEnabled: true, isLoading: true, isAnalyzing: false)
        XCTAssertTrue(machine.consumePendingRefresh())
        XCTAssertFalse(machine.consumePendingRefresh())
    }

    func testTriggerIgnoredWhenAutoRefreshDisabled() {
        var machine = RefreshStateMachine()
        let result = machine.handleTrigger(autoRefreshEnabled: false, isLoading: false, isAnalyzing: false)
        XCTAssertFalse(result)
        XCTAssertFalse(machine.consumePendingRefresh())
    }
}
