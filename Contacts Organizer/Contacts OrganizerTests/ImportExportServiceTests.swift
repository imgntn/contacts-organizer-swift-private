//
//  ImportExportServiceTests.swift
//  Contacts OrganizerTests
//
//  Regression tests for JSON import/export and local test database generation.
//

import XCTest
@testable import Contacts_Organizer

final class ImportExportServiceTests: XCTestCase {

    var service: ImportExportService!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = ImportExportService.shared
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent("ImportExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        service = nil
        try super.tearDownWithError()
    }

    func testExportImportRoundTripPreservesExtendedFields() throws {
        let profile = SocialProfile(service: "Mastodon", username: "@sample", url: "https://example.social/@sample")
        let original = ContactSummary(
            id: "contact-1",
            fullName: "Casey Tester",
            organization: "Example Labs",
            phoneNumbers: ["+1-555-000-0000"],
            emailAddresses: ["casey@example.com"],
            hasProfileImage: true,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            modificationDate: Date(timeIntervalSince1970: 1_700_010_000),
            birthday: Date(timeIntervalSince1970: 600_000_000),
            nickname: "Ace",
            jobTitle: "QA Lead",
            departmentName: "Automation",
            postalAddresses: ["Portland"],
            urlAddresses: ["https://contactsorganizer.app"],
            socialProfiles: [profile],
            instantMessageAddresses: ["Signal:casey"]
        )

        let data = try service.exportContactsToJSON([original])
        let decoded = try service.importContactsFromData(data)

        XCTAssertEqual(decoded.count, 1)
        let contact = decoded[0]
        XCTAssertEqual(contact.fullName, original.fullName)
        XCTAssertEqual(contact.organization, original.organization)
        XCTAssertEqual(contact.phoneNumbers, original.phoneNumbers)
        XCTAssertEqual(contact.emailAddresses, original.emailAddresses)
        XCTAssertEqual(contact.nickname, original.nickname)
        XCTAssertEqual(contact.jobTitle, original.jobTitle)
        XCTAssertEqual(contact.departmentName, original.departmentName)
        XCTAssertEqual(contact.postalAddresses, ["Portland"])
        XCTAssertEqual(contact.urlAddresses, ["https://contactsorganizer.app"])
        XCTAssertEqual(contact.socialProfiles.first?.service, profile.service)
        XCTAssertEqual(contact.socialProfiles.first?.username, profile.username)
        XCTAssertEqual(contact.instantMessageAddresses, ["Signal:casey"])
    }

    func testGenerateAndSaveTestDatabaseCreatesReadableFile() throws {
        let outputURL = tempDirectory.appendingPathComponent("test_contacts.json")
        try service.generateAndSaveTestDatabase(count: 5, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let contacts = try service.importContacts(from: outputURL)
        XCTAssertGreaterThanOrEqual(contacts.count, 5, "Generated database should contain requested number of contacts")
    }

    func testDefaultExportURLUsesDocumentsDirectory() {
        let customFilename = "custom_export.json"
        let expectedDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let exportURL = service.defaultExportURL(filename: customFilename)

        XCTAssertTrue(exportURL.path.hasPrefix(expectedDirectory.path), "Export URL should live in the documents directory")
        XCTAssertEqual(exportURL.lastPathComponent, customFilename)
    }
}
