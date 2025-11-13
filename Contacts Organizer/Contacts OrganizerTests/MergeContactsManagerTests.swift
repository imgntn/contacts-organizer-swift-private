import XCTest
import Contacts
@testable import Contacts_Organizer

final class MergeContactsManagerTests: XCTestCase {

    override func tearDown() async throws {
        ContactsManager.mergeOverride = nil
        try await super.tearDown()
    }

    func testMergeContactsUsesOverridePipeline() async {
        let destination = makeContact(given: "Primary", family: "Person", organization: "Old Org", phones: ["111"], emails: ["old@example.com"])
        let source = makeContact(given: "Secondary", family: "User", organization: "New Org", phones: ["222"], emails: ["new@example.com"])

        let expectation = XCTestExpectation(description: "merge executed")

        let destinationID = destination.identifier
        let sourceID = source.identifier

        ContactsManager.mergeOverride = ContactsManager.MergeOverride(
            destination: destination,
            sources: [source],
            onSave: { merged, deleted in
                XCTAssertEqual(merged.givenName, "Secondary")
                XCTAssertEqual(merged.phoneNumbers.map { $0.value.stringValue }, ["111", "222"])
                XCTAssertEqual(deleted.map { $0.identifier }, [sourceID])
                expectation.fulfill()
            }
        )

        let configuration = MergeConfiguration(
            primaryContactId: destinationID,
            mergingContactIds: [destinationID, sourceID],
            preferredNameSourceId: sourceID,
            preferredOrganizationSourceId: sourceID,
            preferredPhotoSourceId: nil,
            includedPhoneNumbers: ["111", "222"],
            includedEmailAddresses: ["new@example.com"]
        )

        await MainActor.run {
            ContactsManager.shared.authorizationStatus = .authorized
        }
        let success = await ContactsManager.shared.mergeContacts(using: configuration)
        XCTAssertTrue(success)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    private func makeContact(
        given: String,
        family: String,
        organization: String?,
        phones: [String],
        emails: [String]
    ) -> CNContact {
        let contact = CNMutableContact()
        contact.givenName = given
        contact.familyName = family
        contact.organizationName = organization ?? ""
        contact.phoneNumbers = phones.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        contact.emailAddresses = emails.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        return contact.copy() as! CNContact
    }
}
