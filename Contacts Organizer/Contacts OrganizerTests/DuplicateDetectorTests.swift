//
//  DuplicateDetectorTests.swift
//  Contacts OrganizerTests
//
//  Unit tests for duplicate detection logic
//

import XCTest
@testable import Contacts_Organizer

final class DuplicateDetectorTests: XCTestCase {

    var detector: DuplicateDetector!

    override func setUp() {
        super.setUp()
        detector = DuplicateDetector.shared
    }

    // MARK: - Exact Name Matching

    func testExactNameMatch() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 1, "Should find one duplicate group")
        XCTAssertEqual(duplicates.first?.contacts.count, 2, "Group should contain both contacts")
        XCTAssertEqual(duplicates.first?.matchType, .exactName, "Should be exact name match")
    }

    func testNoExactNameMatchWithDifferentNames() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 0, "Should not find duplicates with different names")
    }

    // MARK: - Phone Number Matching

    func testSamePhoneNumberMatch() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "J. Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 1, "Should find duplicate by phone number")
        XCTAssertEqual(duplicates.first?.matchType, .samePhone, "Should be phone match")
    }

    // MARK: - Email Matching

    func testSameEmailMatch() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "J. Smith", organization: nil, phoneNumbers: [], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 1, "Should find duplicate by email")
        XCTAssertEqual(duplicates.first?.matchType, .sameEmail, "Should be email match")
    }

    // MARK: - Similar Name Matching

    func testSimilarNameMatch() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jon Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 1, "Should find similar name match")
        XCTAssertEqual(duplicates.first?.matchType, .similarName, "Should be similar name match")
    }

    // MARK: - Multiple Matches

    func testMultipleMatchCriteria() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 1, "Should find one duplicate group")
        XCTAssertEqual(duplicates.first?.matchType, .multipleMatches, "Should be multiple matches")
    }

    // MARK: - Primary Contact Selection

    func testPrimaryContactSelectionWithMoreData() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Company", phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: true, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.first?.primaryContact.id, "1", "Should select contact with more data as primary")
    }

    // MARK: - Empty Input

    func testEmptyContactList() {
        let contacts: [ContactSummary] = []
        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 0, "Should return empty array for empty input")
    }

    // MARK: - Single Contact

    func testSingleContact() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let duplicates = detector.findDuplicates(in: contacts)

        XCTAssertEqual(duplicates.count, 0, "Should not find duplicates with single contact")
    }

    // MARK: - Performance

    func testPerformanceWithLargeDataset() {
        // Create 1000 contacts
        var contacts: [ContactSummary] = []
        for i in 0..<1000 {
            contacts.append(
                ContactSummary(
                    id: "\(i)",
                    fullName: "Person \(i)",
                    organization: i % 10 == 0 ? "Company" : nil,
                    phoneNumbers: i % 5 == 0 ? ["555-\(i)"] : [],
                    emailAddresses: i % 3 == 0 ? ["person\(i)@example.com"] : [],
                    hasProfileImage: false,
                    creationDate: nil,
                    modificationDate: nil
                )
            )
        }

        // Add some duplicates
        contacts.append(contacts[0]) // Exact duplicate
        contacts.append(contacts[1]) // Another duplicate

        measure {
            _ = detector.findDuplicates(in: contacts)
        }
    }
}
