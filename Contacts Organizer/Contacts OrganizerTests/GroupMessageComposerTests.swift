import XCTest
@testable import Contacts_Organizer

final class GroupMessageComposerTests: XCTestCase {
    func testComposerListsContactsWithDetails() {
        let contacts = [
            ContactSummary(id: "1", fullName: "Alice Example", organization: "Org", phoneNumbers: ["111"], emailAddresses: ["alice@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "2", fullName: "Bob NoEmail", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        ]

        let body = GroupMessageComposer.makeBody(for: contacts, groupName: "VIP")

        XCTAssertTrue(body.contains("Contacts from VIP (2)"))
        XCTAssertTrue(body.contains("• Alice Example (Org) ☎︎ 111 ✉︎ alice@example.com"))
        XCTAssertTrue(body.contains("• Bob NoEmail"))
    }

    func testComposerAddsOverflowLine() {
        let contacts = (0..<30).map { index in
            ContactSummary(id: "\(index)", fullName: "Contact \(index)", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
        }

        let body = GroupMessageComposer.makeBody(for: contacts, groupName: "Large", maxEntries: 5)
        XCTAssertTrue(body.contains("…and 25 more"))
    }
}
