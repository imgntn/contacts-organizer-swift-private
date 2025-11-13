import XCTest
@testable import Contacts_Organizer

final class GroupExportServiceTests: XCTestCase {

    func testGenerateCSVStringEscapesSpecialCharacters() {
        let contacts = [
            ContactSummary(
                id: "1",
                fullName: "Doe, Jane",
                organization: "ACME \"Corp\"",
                phoneNumbers: ["123"],
                emailAddresses: ["jane@example.com"],
                hasProfileImage: false,
                creationDate: nil,
                modificationDate: nil
            )
        ]

        let csv = GroupExportService.shared.generateCSVString(contacts: contacts)
        let rows = csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 2, "CSV should contain header plus one data row")
        XCTAssertEqual(rows[0], "Full Name,Organization,Phone Numbers,Email Addresses,Has Photo")

        let fields = parseCSVLine(String(rows[1]))
        XCTAssertEqual(fields.count, 5)
        XCTAssertEqual(fields[0], "Doe, Jane")
        XCTAssertEqual(fields[1], "ACME \"Corp\"")
        XCTAssertEqual(fields[2], "123")
        XCTAssertEqual(fields[3], "jane@example.com")
        XCTAssertEqual(fields[4], "No")
    }

    func testGenerateVCardStringIncludesOrganizationAndContacts() {
        let contacts = [
            ContactSummary(
                id: "2",
                fullName: "John Smith",
                organization: "Org",
                phoneNumbers: ["555-1111"],
                emailAddresses: ["john@smith.com"],
                hasProfileImage: false,
                creationDate: nil,
                modificationDate: nil
            )
        ]

        let vcard = GroupExportService.shared.generateVCardString(contacts: contacts)
        XCTAssertTrue(vcard.contains("BEGIN:VCARD"))
        XCTAssertTrue(vcard.contains("FN:John Smith"))
        XCTAssertTrue(vcard.contains("ORG:Org"))
        XCTAssertTrue(vcard.contains("EMAIL;TYPE=WORK:john@smith.com"))
        XCTAssertTrue(vcard.contains("TEL;TYPE=WORK:555-1111"))
        XCTAssertTrue(vcard.contains("END:VCARD"))
    }

#if DEBUG
    func testExportToCSVWritesFileAndReturnsURLInTestDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        GroupExportService.testDownloadsDirectory = tempDir
        defer {
            GroupExportService.testDownloadsDirectory = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        let contacts = [
            ContactSummary(
                id: "1",
                fullName: "Jane Doe",
                organization: "ACME",
                phoneNumbers: ["123-456-7890"],
                emailAddresses: ["jane@example.com"],
                hasProfileImage: false,
                creationDate: nil,
                modificationDate: nil
            )
        ]

        let url = GroupExportService.shared.exportToCSV(contacts: contacts, groupName: "VIP List")
        XCTAssertNotNil(url)
        guard let fileURL = url else { return }
        XCTAssertTrue(fileURL.path.hasPrefix(tempDir.path))
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("Jane Doe"))
        XCTAssertTrue(contents.contains("ACME"))
    }

    func testExportToCSVSanitizesFilenameCharacters() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        GroupExportService.testDownloadsDirectory = tempDir
        defer {
            GroupExportService.testDownloadsDirectory = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        let url = GroupExportService.shared.exportToCSV(
            contacts: [],
            groupName: "Needs/Review: VIP?"
        )

        XCTAssertNotNil(url)
        guard let fileURL = url else { return }
        XCTAssertTrue(fileURL.lastPathComponent.contains("Needs_Review_VIP"))
    }
#endif
}

private func parseCSVLine(_ line: String) -> [String] {
    var values: [String] = []
    var current = ""
    var insideQuotes = false
    var chars = Array(line)
    var i = 0
    while i < chars.count {
        let char = chars[i]
        if char == "\"" {
            if insideQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                current.append("\"")
                i += 1
            } else {
                insideQuotes.toggle()
            }
        } else if char == "," && !insideQuotes {
            values.append(current)
            current = ""
        } else {
            current.append(char)
        }
        i += 1
    }
    values.append(current)
    return values
}
