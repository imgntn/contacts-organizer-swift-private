import XCTest
@testable import Contacts_Organizer

final class GroupExportServiceFileTests: XCTestCase {
    private var tempDirectory: TemporaryDirectory!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = try TemporaryDirectory(subdirectory: "exports-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        GroupExportService.testDownloadsDirectory = nil
        tempDirectory?.remove()
        tempDirectory = nil
        try await super.tearDown()
    }

    func testExportToCSVWritesIntoDownloadsOverride() throws {
        GroupExportService.testDownloadsDirectory = tempDirectory.url
        let contacts = [
            ContactSummary(id: "1", fullName: "Alice", organization: "Org", phoneNumbers: ["111"], emailAddresses: ["alice@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let url = GroupExportService.shared.exportToCSV(contacts: contacts, groupName: "VIP")
        XCTAssertNotNil(url)
        if let url {
            XCTAssertTrue(url.path.hasPrefix(tempDirectory.url.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let contents = try String(contentsOf: url)
            XCTAssertTrue(contents.contains("Alice"))
        }
    }

    func testCreateVCardFileStoresTempFile() throws {
        let contacts = [
            ContactSummary(id: "1", fullName: "Bob", organization: nil, phoneNumbers: ["555"], emailAddresses: ["bob@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let url = GroupExportService.shared.createVCardFile(contacts: contacts, groupName: "TestGroup")
        XCTAssertNotNil(url)
        if let url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let contents = try String(contentsOf: url)
            XCTAssertTrue(contents.contains("FN:Bob"))
        }
    }
}
