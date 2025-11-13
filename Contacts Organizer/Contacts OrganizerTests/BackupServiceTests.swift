import XCTest
import Contacts
@testable import Contacts_Organizer

final class BackupServiceTests: XCTestCase {
    private var userDirectory: TemporaryDirectory!
    private var appDirectory: TemporaryDirectory!
    private var snapshotDirectory: TemporaryDirectory!

    override func setUp() async throws {
        try await super.setUp()
        userDirectory = try TemporaryDirectory(subdirectory: "user-\(UUID().uuidString)")
        appDirectory = try TemporaryDirectory(subdirectory: "app-\(UUID().uuidString)")
        snapshotDirectory = try TemporaryDirectory(subdirectory: "snapshot-\(UUID().uuidString)")

        await MainActor.run {
            ContactsManager.shared.authorizationStatus = .authorized
        }
    }

    override func tearDown() async throws {
        ContactsManager.backupOverride = nil
        ContactsManager.snapshotOverride = nil
        userDirectory?.remove()
        appDirectory?.remove()
        snapshotDirectory?.remove()
        userDirectory = nil
        appDirectory = nil
        snapshotDirectory = nil
        try await super.tearDown()
    }

    func testCreateBackupWritesUserAndAppCopies() async throws {
        let contacts = makeSampleContacts()
        ContactsManager.backupOverride = ContactsManager.BackupOverride(
            contacts: contacts,
            userDirectory: userDirectory.url,
            appDirectory: appDirectory.url
        )

        let result = await ContactsManager.shared.createBackup(saveToURL: nil)

        guard let userURL = result.userBackup, let appURL = result.appBackup else {
            return XCTFail("Expected backup URLs")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: userURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appURL.path))

        let expectedData = try CNContactVCardSerialization.data(with: contacts)
        let userData = try Data(contentsOf: userURL)
        let appData = try Data(contentsOf: appURL)
        XCTAssertEqual(userData, expectedData)
        XCTAssertEqual(appData, expectedData)
    }

    func testCreateBackupPropagatesWriteErrors() async throws {
        let contacts = makeSampleContacts()
        let invalidAppURL = appDirectory.url.appendingPathComponent("not_a_directory.vcf")
        FileManager.default.createFile(atPath: invalidAppURL.path, contents: nil)

        ContactsManager.backupOverride = ContactsManager.BackupOverride(
            contacts: contacts,
            userDirectory: userDirectory.url,
            appDirectory: invalidAppURL
        )

        let result = await ContactsManager.shared.createBackup(saveToURL: nil)
        XCTAssertNil(result.userBackup)
        XCTAssertNil(result.appBackup)
    }

    func testCreateSafetySnapshotWritesFile() async throws {
        let contacts = makeSampleContacts()
        ContactsManager.snapshotOverride = ContactsManager.SnapshotOverride(
            contacts: contacts,
            snapshotDirectory: snapshotDirectory.url
        )

        let snapshotURL = await ContactsManager.shared.createSafetySnapshot(tag: "merge_test")
        XCTAssertNotNil(snapshotURL)
        if let snapshotURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotURL.path))
        }
    }

    // MARK: - Helpers

    private func makeSampleContacts() -> [CNContact] {
        let first = CNMutableContact()
        first.givenName = "Test"
        first.familyName = "User"
        first.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: "test@example.com" as NSString)]
        first.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0000"))]

        let second = CNMutableContact()
        second.givenName = "Second"
        second.familyName = "Person"
        second.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "second@example.com" as NSString)]
        second.phoneNumbers = [CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: "555-1111"))]

        return [first.copy() as! CNContact, second.copy() as! CNContact]
    }
}
