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

    func testOrganizationGrouping() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "4", fullName: "Alice Williams", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let hasApple = await MainActor.run { results.contains { $0.groupName == "Apple" } }
        let hasGoogle = await MainActor.run { results.contains { $0.groupName == "Google" } }

        XCTAssertEqual(results.count, 2, "Should create 2 organization groups")
        XCTAssertTrue(hasApple, "Should have Apple group")
        XCTAssertTrue(hasGoogle, "Should have Google group")
    }

    func testOrganizationGroupingMinimumTwoContacts() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should not create groups with only 1 contact")
    }

    // MARK: - Custom Criteria - Has Phone

    func testCustomCriteriaHasPhone() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhone, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Has Phone", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with phone")
        XCTAssertEqual(firstId, "1", "Should be the contact with phone")
    }

    // MARK: - Custom Criteria - Missing Email

    func testCustomCriteriaMissingEmail() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: ["jane@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasEmail, condition: .notExists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Missing Email", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact without email")
        XCTAssertEqual(firstId, "1", "Should be the contact without email")
    }

    // MARK: - Custom Criteria - Multiple Rules

    func testCustomCriteriaMultipleRules() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: ["555-5678"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhone, condition: .exists),
                CustomCriteria.Rule(field: .hasEmail, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Complete Contacts", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with both phone and email")
        XCTAssertEqual(firstId, "1", "Should be the complete contact")
    }

    // MARK: - Custom Criteria - Organization Contains

    func testCustomCriteriaOrganizationContains() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: "Apple Inc.", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple Store", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: "Google", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .organizationContains, condition: .contains, value: "Apple")
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Apple Contacts", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 2, "Should contain two contacts with Apple in organization")
    }

    // MARK: - Custom Criteria - Name Contains

    func testCustomCriteriaNameContains() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Johnny Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .nameContains, condition: .contains, value: "John")
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "John Contacts", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 2, "Should contain two contacts with John in name")
    }

    // MARK: - Custom Criteria - Has Photo

    func testCustomCriteriaHasPhoto() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: true, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhoto, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Has Photo", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with photo")
        XCTAssertEqual(firstId, "1", "Should be the contact with photo")
    }

    func testRecentlyAddedCriteriaHonorsThreshold() async {
        let now = Date()
        let contacts = await MainActor.run {
            [
                ContactSummary(
                    id: "recent",
                    fullName: "New Contact",
                    organization: nil,
                    phoneNumbers: [],
                    emailAddresses: [],
                    hasProfileImage: false,
                    creationDate: Calendar.current.date(byAdding: .day, value: -5, to: now),
                    modificationDate: now
                ),
                ContactSummary(
                    id: "old",
                    fullName: "Older Contact",
                    organization: nil,
                    phoneNumbers: [],
                    emailAddresses: [],
                    hasProfileImage: false,
                    creationDate: Calendar.current.date(byAdding: .day, value: -90, to: now),
                    modificationDate: Calendar.current.date(byAdding: .day, value: -60, to: now)
                )
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .recentlyAdded, condition: .exists, value: "30")
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Recently Added", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let ids = await MainActor.run { results.first?.contacts.map { $0.id } ?? [] }
        XCTAssertEqual(ids, ["recent"])
    }

    func testStaleContactCriteriaUsesLastActivity() async {
        let now = Date()
        let contacts = await MainActor.run {
            [
                ContactSummary(
                    id: "stale",
                    fullName: "Dormant Contact",
                    organization: nil,
                    phoneNumbers: [],
                    emailAddresses: [],
                    hasProfileImage: false,
                    creationDate: Calendar.current.date(byAdding: .day, value: -800, to: now),
                    modificationDate: Calendar.current.date(byAdding: .day, value: -400, to: now)
                ),
                ContactSummary(
                    id: "active",
                    fullName: "Active Contact",
                    organization: nil,
                    phoneNumbers: [],
                    emailAddresses: [],
                    hasProfileImage: false,
                    creationDate: Calendar.current.date(byAdding: .day, value: -600, to: now),
                    modificationDate: Calendar.current.date(byAdding: .day, value: -30, to: now)
                )
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .staleContact, condition: .exists, value: "365")
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Stale Contacts", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let ids = await MainActor.run { results.first?.contacts.map { $0.id } ?? [] }
        XCTAssertEqual(ids, ["stale"])
    }

    // MARK: - Multiple Definitions

    func testMultipleDefinitions() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: ["555-1234"], emailAddresses: ["john@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let definitions = await MainActor.run {
            [
                SmartGroupDefinition(name: "By Organization", groupingType: .organization),
                SmartGroupDefinition(name: "Complete Contacts", groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasPhone, condition: .exists),
                    CustomCriteria.Rule(field: .hasEmail, condition: .exists)
                ])))
            ]
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: definitions, using: contacts)

        XCTAssertEqual(results.count, 2, "Should create groups for both definitions")
    }

    // MARK: - Disabled Definitions

    func testDisabledDefinitionsNotGenerated() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: "Apple", phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "By Organization", groupingType: .organization, isEnabled: false)
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should not generate groups for disabled definitions")
    }

    // MARK: - Phase 1 Smart Groups

    func testPhase1NoCriticalInfo() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .noCriticalInfo, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Missing Critical Info", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with no phone or email")
        XCTAssertEqual(firstId, "1", "Should be the contact with no critical info")
    }

    func testPhase1PhoneOnly() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: ["jane@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: ["555-5678"], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .phoneOnly, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Phone Only", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with phone only")
        XCTAssertEqual(firstId, "1", "Should be the contact with phone only")
    }

    func testPhase1EmailOnly() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: ["jane@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: ["555-5678"], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .emailOnly, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Email Only", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with email only")
        XCTAssertEqual(firstId, "2", "Should be the contact with email only")
    }

    func testPhase1MultiplePhones() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: ["555-1234", "555-5678"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: ["555-9999"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: ["555-1111", "555-2222", "555-3333"], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .multiplePhones, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Multiple Phones", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let contains1 = await MainActor.run { results.first?.contacts.contains { $0.id == "1" } } ?? false
        let contains3 = await MainActor.run { results.first?.contacts.contains { $0.id == "3" } } ?? false

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 2, "Should contain two contacts with multiple phones")
        XCTAssertTrue(contains1, "Should include contact 1")
        XCTAssertTrue(contains3, "Should include contact 3")
    }

    func testPhase1MultipleEmails() async {
        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: ["john@work.com", "john@personal.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: ["jane@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
                ContactSummary(id: "3", fullName: "Bob Johnson", organization: nil, phoneNumbers: [], emailAddresses: ["bob1@example.com", "bob2@example.com", "bob3@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .multipleEmails, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Multiple Emails", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let contains1 = await MainActor.run { results.first?.contacts.contains { $0.id == "1" } } ?? false
        let contains3 = await MainActor.run { results.first?.contacts.contains { $0.id == "3" } } ?? false

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 2, "Should contain two contacts with multiple emails")
        XCTAssertTrue(contains1, "Should include contact 1")
        XCTAssertTrue(contains3, "Should include contact 3")
    }

    // MARK: - Phase 2 Time-Based Smart Groups

    func testPhase2RecentlyAdded() async {
        let now = Date()
        let twentyDaysAgo = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        let fortyDaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: now)!

        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: twentyDaysAgo, modificationDate: nil),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: fortyDaysAgo, modificationDate: nil)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .recentlyAdded, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Recently Added", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one recently added contact")
        XCTAssertEqual(firstId, "1", "Should be contact added 20 days ago")
    }

    func testPhase2RecentlyModified() async {
        let now = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: now)!

        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: tenDaysAgo),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: sixtyDaysAgo)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .recentlyModified, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Recently Modified", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one recently modified contact")
        XCTAssertEqual(firstId, "1", "Should be contact modified 10 days ago")
    }

    func testPhase2StaleContacts() async {
        let now = Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now)!
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now)!

        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: twoYearsAgo),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: threeMonthsAgo)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .staleContact, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Stale Contacts", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one stale contact")
        XCTAssertEqual(firstId, "1", "Should be contact not modified in 2 years")
    }

    func testPhase2BirthdayThisMonth() async {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Create birthday in this month
        var thisMonthComponents = DateComponents()
        thisMonthComponents.year = currentYear - 30
        thisMonthComponents.month = currentMonth
        thisMonthComponents.day = 15
        let thisMonthBirthday = calendar.date(from: thisMonthComponents)!

        // Create birthday in different month
        var otherMonthComponents = DateComponents()
        otherMonthComponents.year = currentYear - 25
        otherMonthComponents.month = (currentMonth % 12) + 1
        otherMonthComponents.day = 20
        let otherMonthBirthday = calendar.date(from: otherMonthComponents)!

        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil, birthday: thisMonthBirthday),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil, birthday: otherMonthBirthday)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .birthdayThisMonth, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Birthday This Month", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with birthday this month")
        XCTAssertEqual(firstId, "1", "Should be contact with birthday this month")
    }

    func testPhase2BirthdayThisWeek() async {
        let calendar = Calendar.current
        let now = Date()

        // Get current week interval
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            XCTFail("Could not get week interval")
            return
        }

        // Create birthday within this week (use middle of week)
        let midWeek = Date(timeInterval: weekInterval.duration / 2, since: weekInterval.start)
        let currentYear = calendar.component(.year, from: now)

        var thisWeekComponents = DateComponents()
        thisWeekComponents.year = currentYear - 30
        thisWeekComponents.month = calendar.component(.month, from: midWeek)
        thisWeekComponents.day = calendar.component(.day, from: midWeek)
        let thisWeekBirthday = calendar.date(from: thisWeekComponents)!

        // Create birthday outside this week
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now)!
        var nextWeekComponents = DateComponents()
        nextWeekComponents.year = currentYear - 25
        nextWeekComponents.month = calendar.component(.month, from: nextWeek)
        nextWeekComponents.day = calendar.component(.day, from: nextWeek)
        let nextWeekBirthday = calendar.date(from: nextWeekComponents)!

        let contacts = await MainActor.run {
            [
                ContactSummary(id: "1", fullName: "John Smith", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil, birthday: thisWeekBirthday),
                ContactSummary(id: "2", fullName: "Jane Doe", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil, birthday: nextWeekBirthday)
            ]
        }
        let criteria = await MainActor.run {
            CustomCriteria(rules: [
                CustomCriteria.Rule(field: .birthdayThisWeek, condition: .exists)
            ])
        }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "Birthday This Week", groupingType: .custom(criteria))
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        let firstCount = await MainActor.run { results.first?.contacts.count }
        let firstId = await MainActor.run { results.first?.contacts.first?.id }

        XCTAssertEqual(results.count, 1, "Should create one group")
        XCTAssertEqual(firstCount, 1, "Should contain one contact with birthday this week")
        XCTAssertEqual(firstId, "1", "Should be contact with birthday this week")
    }

    // MARK: - Default Smart Groups

    func testDefaultSmartGroups() async {
        let defaults = await MainActor.run { ContactsManager.defaultSmartGroups }

        let allEnabled = await MainActor.run { defaults.allSatisfy { $0.isEnabled } }

        XCTAssertTrue(defaults.count > 0, "Should have default smart group definitions")
        XCTAssertTrue(allEnabled, "All default groups should be enabled")
    }

    // MARK: - Empty Contact List

    func testEmptyContactList() async {
        let contacts = await MainActor.run { [ContactSummary]() }
        let definition = await MainActor.run {
            SmartGroupDefinition(name: "By Organization", groupingType: .organization)
        }
        let manager = await MainActor.run { ContactsManager.shared }
        let results = await manager.generateSmartGroups(definitions: [definition], using: contacts)

        XCTAssertEqual(results.count, 0, "Should return empty results for empty contact list")
    }

    // MARK: - Performance Tests

    func testSmartGroupGenerationPerformance() async {
        // Generate a large dataset
        let largeContactSet = await MainActor.run {
            TestDataGenerator.shared.generateTestContacts(count: 1000)
        }

        // Use all default smart group definitions (14 groups)
        let definitions = await MainActor.run {
            ContactsManager.defaultSmartGroups
        }

        let manager = await MainActor.run { ContactsManager.shared }

        // Measure performance of generating all smart groups
        measure {
            // Use detached to avoid capturing XCTestCase context inside Task
            let expectation = self.expectation(description: "Smart groups generated")
            Task.detached {
                let _ = await manager.generateSmartGroups(definitions: definitions, using: largeContactSet)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }

        // Also verify it completes successfully
        let results = await manager.generateSmartGroups(definitions: definitions, using: largeContactSet)
        XCTAssertGreaterThan(results.count, 0, "Should generate at least some smart groups from 1000 contacts")
    }
}
