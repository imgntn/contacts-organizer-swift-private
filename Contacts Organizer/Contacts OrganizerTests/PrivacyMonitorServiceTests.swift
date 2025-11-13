import XCTest
@testable import Contacts_Organizer

@MainActor
final class PrivacyMonitorServiceTests: XCTestCase {
    private var monitor: PrivacyMonitorService!

    override func setUp() async throws {
        try await super.setUp()
        monitor = PrivacyMonitorService(startMonitoringImmediately: false)
    }

    override func tearDown() async throws {
        monitor.stopMonitoring()
        monitor = nil
        try await super.tearDown()
    }

    func testRecordingProcessingMetricsUpdatesAverages() {
        monitor.recordContactFetch(duration: 0.5)
        monitor.recordDuplicateDetection(duration: 0.25)
        monitor.recordAnalysis(duration: 0.75)

        let metrics = monitor.currentMetrics.processingMetrics
        XCTAssertEqual(metrics.totalOperationsPerformed, 3)
        XCTAssertNotNil(metrics.averageContactFetchTime)
        XCTAssertNotNil(metrics.averageDuplicateDetectionTime)
        XCTAssertNotNil(metrics.averageAnalysisTime)
    }

    func testRefreshMetricsUpdatesTimestamp() {
        let previousDate = monitor.currentMetrics.lastUpdated
        monitor.refreshMetrics()
        XCTAssertTrue(monitor.currentMetrics.lastUpdated >= previousDate)
    }
}
