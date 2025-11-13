import XCTest
@testable import Contacts_Organizer

final class TestDataGeneratorTests: XCTestCase {

    func testGeneratorProducesDuplicatesAndIncompleteContacts() {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 40)
        let ids = contacts.map(\.id)

        XCTAssertTrue(ids.contains { $0.contains("dup-") }, "Generator should include duplicate contacts for realism")
        XCTAssertTrue(ids.contains { $0.contains("incomplete-") }, "Generator should include incomplete contacts for quality tests")

        let hasPhone = contacts.contains { !$0.phoneNumbers.isEmpty }
        let hasEmail = contacts.contains { !$0.emailAddresses.isEmpty }
        XCTAssertTrue(hasPhone)
        XCTAssertTrue(hasEmail)
    }
}
