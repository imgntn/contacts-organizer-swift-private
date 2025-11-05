//
//  DataQualityAnalyzerTests.swift
//  Contacts OrganizerTests
//
//  Unit tests for data quality analysis logic
//

import XCTest
@testable import Contacts_Organizer

final class DataQualityAnalyzerTests: XCTestCase {

    var analyzer: DataQualityAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = DataQualityAnalyzer.shared
    }

    // MARK: - Missing Name Detection

    func testMissingNameDetection() {
        let contacts = [
            ContactSummary(id: "1", fullName: "No Name", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "", organization: nil, phoneNumbers: ["555-5678"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let missingNameIssues = issues.filter { $0.issueType == .missingName }
        XCTAssertEqual(missingNameIssues.count, 2, "Should detect both contacts with missing names")
        XCTAssertEqual(missingNameIssues.first?.severity, .high, "Missing name should be high severity")
    }

    // MARK: - Missing Contact Info Detection

    func testNoContactInfoDetection() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let noContactInfoIssues = issues.filter { $0.issueType == .noContactInfo }
        XCTAssertEqual(noContactInfoIssues.count, 1, "Should detect contact with no phone or email")
        XCTAssertEqual(noContactInfoIssues.first?.severity, .high, "No contact info should be high severity")
    }

    // MARK: - Missing Phone Detection

    func testMissingPhoneDetection() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let missingPhoneIssues = issues.filter { $0.issueType == .missingPhone }
        XCTAssertEqual(missingPhoneIssues.count, 1, "Should detect contact with no phone")
        XCTAssertEqual(missingPhoneIssues.first?.severity, .medium, "Missing phone should be medium severity")
    }

    // MARK: - Missing Email Detection

    func testMissingEmailDetection() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let missingEmailIssues = issues.filter { $0.issueType == .missingEmail }
        XCTAssertEqual(missingEmailIssues.count, 1, "Should detect contact with no email")
        XCTAssertEqual(missingEmailIssues.first?.severity, .low, "Missing email should be low severity")
    }

    // MARK: - Incomplete Data Detection

    func testIncompleteDataDetection() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let incompleteIssues = issues.filter { $0.issueType == .incompleteData }
        XCTAssertEqual(incompleteIssues.count, 1, "Should detect contact with missing organization")
        XCTAssertEqual(incompleteIssues.first?.severity, .low, "Incomplete data should be low severity")
    }

    // MARK: - Complete Contact (No Issues)

    func testCompleteContact() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Company", phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: true, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        XCTAssertEqual(issues.count, 0, "Complete contact should have no issues")
    }

    // MARK: - Multiple Issues

    func testMultipleIssuesOnSameContact() {
        let contacts = [
            ContactSummary(id: "1", fullName: "No Name", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        XCTAssertTrue(issues.count >= 2, "Contact with multiple problems should have multiple issues")
        XCTAssertTrue(issues.contains { $0.issueType == .missingName }, "Should detect missing name")
        XCTAssertTrue(issues.contains { $0.issueType == .noContactInfo }, "Should detect no contact info")
    }

    // MARK: - Issue Sorting

    func testIssuesSortedBySeverity() {
        let contacts = [
            ContactSummary(id: "1", fullName: "No Name", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        // Issues should be sorted with high severity first
        let firstIssue = issues.first
        let lastIssue = issues.last

        XCTAssertEqual(firstIssue?.severity, .high, "First issue should be high severity")
        XCTAssertTrue(firstIssue!.severity.rawValue <= lastIssue!.severity.rawValue, "Issues should be sorted by severity")
    }

    // MARK: - Summary Generation

    func testSummaryGeneration() {
        let issues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingName, description: "Test", severity: .high),
            DataQualityIssue(contactId: "2", contactName: "Test", issueType: .missingPhone, description: "Test", severity: .medium),
            DataQualityIssue(contactId: "3", contactName: "Test", issueType: .missingEmail, description: "Test", severity: .low)
        ]

        let summary = analyzer.generateSummary(issues: issues)

        XCTAssertEqual(summary.totalIssues, 3, "Should count all issues")
        XCTAssertEqual(summary.highSeverityCount, 1, "Should count high severity issues")
        XCTAssertEqual(summary.mediumSeverityCount, 1, "Should count medium severity issues")
        XCTAssertEqual(summary.lowSeverityCount, 1, "Should count low severity issues")
    }

    // MARK: - Health Score

    func testHealthScoreForNoIssues() {
        let summary = analyzer.generateSummary(issues: [])

        XCTAssertEqual(summary.healthScore, 100.0, "Health score should be 100 with no issues")
    }

    func testHealthScoreDecreasesWithIssues() {
        let issues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingName, description: "Test", severity: .high)
        ]

        let summary = analyzer.generateSummary(issues: issues)

        XCTAssertLessThan(summary.healthScore, 100.0, "Health score should decrease with issues")
        XCTAssertEqual(summary.healthScore, 90.0, accuracy: 0.1, "High priority issue should reduce score by 10 points")
    }

    func testHealthScoreSeverityWeighting() {
        // Test high priority: -10 points each
        let highIssues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingName, description: "Test", severity: .high),
            DataQualityIssue(contactId: "2", contactName: "Test", issueType: .noContactInfo, description: "Test", severity: .high)
        ]
        let highSummary = analyzer.generateSummary(issues: highIssues)
        XCTAssertEqual(highSummary.healthScore, 80.0, accuracy: 0.1, "2 high priority issues should reduce score by 20 points")

        // Test medium priority: -3 points each
        let mediumIssues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingPhone, description: "Test", severity: .medium),
            DataQualityIssue(contactId: "2", contactName: "Test", issueType: .missingPhone, description: "Test", severity: .medium)
        ]
        let mediumSummary = analyzer.generateSummary(issues: mediumIssues)
        XCTAssertEqual(mediumSummary.healthScore, 94.0, accuracy: 0.1, "2 medium priority issues should reduce score by 6 points")

        // Test low priority: -0.5 points each
        let lowIssues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingEmail, description: "Test", severity: .low),
            DataQualityIssue(contactId: "2", contactName: "Test", issueType: .missingEmail, description: "Test", severity: .low)
        ]
        let lowSummary = analyzer.generateSummary(issues: lowIssues)
        XCTAssertEqual(lowSummary.healthScore, 99.0, accuracy: 0.1, "2 low priority issues should reduce score by 1 point")
    }

    func testHealthScoreLowPriorityCappedAt5Percent() {
        // Create 20 low priority issues (would be 10 points without cap)
        var lowIssues: [DataQualityIssue] = []
        for i in 0..<20 {
            lowIssues.append(
                DataQualityIssue(contactId: "\(i)", contactName: "Test", issueType: .missingEmail, description: "Test", severity: .low)
            )
        }

        let summary = analyzer.generateSummary(issues: lowIssues)

        // Should be capped at 5% penalty = 95% score
        XCTAssertEqual(summary.healthScore, 95.0, accuracy: 0.1, "Low priority issues should be capped at 5% impact")
    }

    func testHealthScoreMixedSeverities() {
        let mixedIssues = [
            DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingName, description: "Test", severity: .high),        // -10
            DataQualityIssue(contactId: "2", contactName: "Test", issueType: .missingPhone, description: "Test", severity: .medium),     // -3
            DataQualityIssue(contactId: "3", contactName: "Test", issueType: .missingPhone, description: "Test", severity: .medium),     // -3
            DataQualityIssue(contactId: "4", contactName: "Test", issueType: .missingEmail, description: "Test", severity: .low),        // -0.5
            DataQualityIssue(contactId: "5", contactName: "Test", issueType: .incompleteData, description: "Test", severity: .low)       // -0.5
        ]
        // Total: -10 - 3 - 3 - 0.5 - 0.5 = -17 points

        let summary = analyzer.generateSummary(issues: mixedIssues)

        XCTAssertEqual(summary.healthScore, 83.0, accuracy: 0.1, "Mixed severity issues should be weighted correctly")
    }

    // MARK: - Empty Input

    func testEmptyContactList() {
        let contacts: [ContactSummary] = []
        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        XCTAssertEqual(issues.count, 0, "Should return empty array for empty input")
    }

    // MARK: - Performance

    func testPerformanceWithLargeDataset() {
        var contacts: [ContactSummary] = []
        for i in 0..<1000 {
            contacts.append(
                ContactSummary(
                    id: "\(i)",
                    fullName: i % 2 == 0 ? "Person \(i)" : "No Name",
                    organization: i % 3 == 0 ? "Company" : nil,
                    phoneNumbers: i % 2 == 0 ? ["555-\(i)"] : [],
                    emailAddresses: i % 3 == 0 ? ["person\(i)@example.com"] : [],
                    hasProfileImage: false,
                    creationDate: nil,
                    modificationDate: nil
                )
            )
        }

        measure {
            _ = analyzer.analyzeDataQuality(contacts: contacts)
        }
    }
}
