//
//  SmartGroupTests.swift
//  Contacts OrganizerTests
//
//  Unit tests for smart group generation logic
//

import XCTest
@testable import Contacts_Organizer

final class SmartGroupTests: XCTestCase {

    // MARK: - Organization Grouping

    func testOrganizationGrouping() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "3", fullName: "Bob Johnson", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "4", fullName: "Alice Williams", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let definition = SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 2, "Should create 2 organization groups")
        XCTAssertTrue(results.contains { $0.groupName == "Apple" }, "Should have Apple group")
        XCTAssertTrue(results.contains { $0.groupName == "Google" }, "Should have Google group")
    }

    func testOrganizationGroupingMinimumTwoContacts() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let definition = SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should not create groups with only 1 contact")
    }

    // MARK: - Custom Criteria - Has Phone

    func testCustomCriteriaHasPhone() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasPhone, condition: .exists)
        ])
        let definition = SmartGroupDefinition(name: "Has Phone", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 1, "Should contain one contact with phone")
        XCTAssertEqual(results.first?.contacts.first?.id, "1", "Should be the contact with phone")
    }

    // MARK: - Custom Criteria - Missing Email

    func testCustomCriteriaMissingEmail() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: ["jane@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasEmail, condition: .notExists)
        ])
        let definition = SmartGroupDefinition(name: "Missing Email", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 1, "Should contain one contact without email")
        XCTAssertEqual(results.first?.contacts.first?.id, "1", "Should be the contact without email")
    }

    // MARK: - Custom Criteria - Multiple Rules

    func testCustomCriteriaMultipleRules() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: ["555-5678"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasPhone, condition: .exists),
            CustomCriteria.Rule(field: .hasEmail, condition: .exists)
        ])
        let definition = SmartGroupDefinition(name: "Complete Contacts", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 1, "Should contain one contact with both phone and email")
        XCTAssertEqual(results.first?.contacts.first?.id, "1", "Should be the complete contact")
    }

    // MARK: - Custom Criteria - Organization Contains

    func testCustomCriteriaOrganizationContains() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Apple Inc.", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple Store", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "3", fullName: "Bob Johnson", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .organizationContains, condition: .contains, value: "Apple")
        ])
        let definition = SmartGroupDefinition(name: "Apple Contacts", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 2, "Should contain two contacts with Apple in organization")
    }

    // MARK: - Custom Criteria - Name Contains

    func testCustomCriteriaNameContains() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Johnny Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .nameContains, condition: .contains, value: "John")
        ])
        let definition = SmartGroupDefinition(name: "John Contacts", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 2, "Should contain two contacts with John in name")
    }

    // MARK: - Custom Criteria - Has Photo

    func testCustomCriteriaHasPhoto() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: true, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let criteria = CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasPhoto, condition: .exists)
        ])
        let definition = SmartGroupDefinition(name: "Has Photo", groupingType: .custom(criteria))
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(results.first?.contacts.count, 1, "Should contain one contact with photo")
        XCTAssertEqual(results.first?.contacts.first?.id, "1", "Should be the contact with photo")
    }

    // MARK: - Multiple Definitions

    func testMultipleDefinitions() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let definitions = [
            SmartGroupDefinition(name: "By Organization", groupingType: .organization),
            SmartGroupDefinition(name: "Complete Contacts", groupingType: .custom(CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhone, condition: .exists),
                CustomCriteria.Rule(field: .hasEmail, condition: .exists)
            ])))
        ]

        let results = ContactsManager.shared.generateSmartGroups(definitions: definitions, using: contacts)

        XCTAssertEqual(results.count, 2, "Should create groups for both definitions")
    }

    // MARK: - Disabled Definitions

    func testDisabledDefinitionsNotGenerated() {
        let contacts = [
            ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let definition = SmartGroupDefinition(name: "By Organization", groupingType: .organization, isEnabled: false)
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should not generate groups for disabled definitions")
    }

    // MARK: - Default Smart Groups

    func testDefaultSmartGroups() {
        let defaults = ContactsManager.defaultSmartGroups

        XCTAssertTrue(defaults.count > 0, "Should have default smart group definitions")
        XCTAssertTrue(defaults.allSatisfy { $0.isEnabled }, "All default groups should be enabled")
    }

    // MARK: - Empty Contact List

    func testEmptyContactList() {
        let contacts: [ContactSummary] = []
        let definition = SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        let results = ContactsManager.shared.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should return empty results for empty contact list")
    }
}
