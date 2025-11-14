import XCTest
@testable import Contacts_Organizer

final class DiagnosticsCenterTests: XCTestCase {

    @MainActor override func setUp() {
        DiagnosticsCenter.shared.resetForTesting()
    }

    @MainActor func testRecordStoresEntries() {
        DiagnosticsCenter.shared.record("Test message", severity: .warning, metadata: "meta")
        XCTAssertEqual(DiagnosticsCenter.shared.entries.count, 1)
        XCTAssertEqual(DiagnosticsCenter.shared.entries.first?.message, "Test message")
        XCTAssertEqual(DiagnosticsCenter.shared.entries.first?.metadata, "meta")
        XCTAssertEqual(DiagnosticsCenter.shared.entries.first?.severity, .warning)
    }

    @MainActor func testPerformanceRecordingRespectsThreshold() {
        DiagnosticsCenter.shared.recordPerformance(operation: "Slow op", duration: 1.0, threshold: 0.5)
        XCTAssertEqual(DiagnosticsCenter.shared.entries.count, 1)

        DiagnosticsCenter.shared.resetForTesting()
        DiagnosticsCenter.shared.recordPerformance(operation: "Fast op", duration: 0.1, threshold: 0.5)
        XCTAssertTrue(DiagnosticsCenter.shared.entries.isEmpty)
    }
}
