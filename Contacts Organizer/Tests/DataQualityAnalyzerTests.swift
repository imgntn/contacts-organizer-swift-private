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

    // MARK: - Organization Suggestion Detection

    func testOrganizationSuggestion() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let issues = analyzer.analyzeDataQuality(contacts: contacts)

        let suggestions = issues.filter { $0.issueType == .suggestion }
        XCTAssertEqual(suggestions.count, 1, "Should suggest organization for complete contacts")
        XCTAssertEqual(suggestions.first?.severity, .suggestion, "Organization info should be a suggestion")
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

final class MergePlanTests: XCTestCase {

    func testMergePlanCapturesAllValues() {
        let contactA = ContactSummary(
            id: "1",
            fullName: "Alice Example",
            organization: "Acme",
            phoneNumbers: ["111-1111"],
            emailAddresses: ["alice@example.com"],
            hasProfileImage: false,
            creationDate: nil,
            modificationDate: nil
        )

        let contactB = ContactSummary(
            id: "2",
            fullName: "Alice Example",
            organization: nil,
            phoneNumbers: ["222-2222"],
            emailAddresses: ["alice@work.com"],
            hasProfileImage: true,
            creationDate: nil,
            modificationDate: nil
        )

        let group = DuplicateGroup(contacts: [contactA, contactB], matchType: .exactName, confidence: 0.95)
        let plan = MergePlan.initial(for: group)

        XCTAssertTrue(plan.selectedPhoneNumbers.contains("111-1111"))
        XCTAssertTrue(plan.selectedPhoneNumbers.contains("222-2222"))
        XCTAssertEqual(plan.preferredNameContactId, group.primaryContact.id)
        XCTAssertEqual(plan.preferredPhotoContactId, contactB.id)
    }

    func testUniqueValueBuilderDeduplicatesEntries() {
        let contactA = ContactSummary(
            id: "1",
            fullName: "Bob",
            organization: nil,
            phoneNumbers: ["111-1111"],
            emailAddresses: [],
            hasProfileImage: false,
            creationDate: nil,
            modificationDate: nil
        )
        let contactB = ContactSummary(
            id: "2",
            fullName: "Bob",
            organization: nil,
            phoneNumbers: ["111-1111", "333-3333"],
            emailAddresses: [],
            hasProfileImage: false,
            creationDate: nil,
            modificationDate: nil
        )

        let options = MergePlanBuilder.uniqueValues(for: [contactA, contactB], keyPath: \.phoneNumbers)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options.first(where: { $0.value == "111-1111" })?.owners.count, 2)
    }
}

final class HealthIssueActionCatalogTests: XCTestCase {

    func testMissingPhoneActionsIncludeAddPhone() {
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingPhone, description: "", severity: .medium)
        let actions = HealthIssueActionCatalog.actions(for: issue)
        XCTAssertTrue(actions.contains { action in
            if case .addPhone = action.type { return true }
            return false
        })
    }

    func testActionsAlwaysIncludeMarkReviewed() {
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .noContactInfo, description: "", severity: .high)
        let actions = HealthIssueActionCatalog.actions(for: issue)
        XCTAssertTrue(actions.contains { action in
            if case .addToGroup(let name) = action.type {
                return name == HealthIssueActionCatalog.reviewedGroupName
            }
            return false
        })
    }

    func testMarkReviewedAddsToReviewedGroup() {
        let issue = DataQualityIssue(contactId: "10", contactName: "Test", issueType: .suggestion, description: "", severity: .suggestion)
        let actions = HealthIssueActionCatalog.actions(for: issue)
        guard let markAction = actions.last else {
            return XCTFail("Expected mark reviewed action")
        }
        if case .addToGroup(let name) = markAction.type {
            XCTAssertEqual(name, HealthIssueActionCatalog.reviewedGroupName)
        } else {
            XCTFail("Mark reviewed should add contact to reviewed group")
        }
    }

    func testMissingEmailProvidesAddEmailAndGroup() {
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingEmail, description: "", severity: .low)
        let actions = HealthIssueActionCatalog.actions(for: issue)

        XCTAssertTrue(actions.contains { action in
            if case .addEmail = action.type { return true }
            return false
        }, "Missing email should offer an add email action")

        XCTAssertTrue(actions.contains { action in
            if case .addToGroup(let name) = action.type {
                return name == HealthIssueActionCatalog.emailFollowUpGroupName
            }
            return false
        }, "Missing email should add to the email follow-up group")
    }

    func testNoContactInfoIncludesArchiveOption() {
        let issue = DataQualityIssue(contactId: "2", contactName: "Test", issueType: .noContactInfo, description: "", severity: .high)
        let actions = HealthIssueActionCatalog.actions(for: issue)

        XCTAssertTrue(actions.contains { action in
            if case .archive = action.type { return true }
            return false
        }, "No contact info should expose the archive option")
    }

    func testSuggestionOnlyProvidesGeneralFollowUp() {
        let issue = DataQualityIssue(contactId: "3", contactName: "Test", issueType: .suggestion, description: "", severity: .suggestion)
        let actions = HealthIssueActionCatalog.actions(for: issue)

        XCTAssertTrue(actions.contains { action in
            if case .addToGroup(let name) = action.type {
                return name == HealthIssueActionCatalog.generalFollowUpGroupName
            }
            return false
        })
    }
}

final class MergeConfigurationTests: XCTestCase {

    func testSourceContactIdsExcludePrimary() {
        let configuration = MergeConfiguration(
            primaryContactId: "primary",
            mergingContactIds: ["primary", "a", "b"],
            preferredNameSourceId: nil,
            preferredOrganizationSourceId: nil,
            preferredPhotoSourceId: nil,
            includedPhoneNumbers: nil,
            includedEmailAddresses: nil
        )

        XCTAssertEqual(configuration.sourceContactIds.sorted(), ["a", "b"], "Only non-primary IDs should be returned")
    }
}
