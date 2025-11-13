import XCTest
import Contacts
@testable import Contacts_Organizer

final class MergeEngineTests: XCTestCase {

    func testMergePlanProducesConfigurationWithSelectedValues() {
        let contacts = [
            ContactSummary(id: "primary", fullName: "Primary Person", organization: "Org", phoneNumbers: ["111", "222"], emailAddresses: ["primary@example.com"], hasProfileImage: false, creationDate: nil, modificationDate: nil),
            ContactSummary(id: "secondary", fullName: "Secondary Person", organization: "Alt Org", phoneNumbers: ["333"], emailAddresses: ["secondary@example.com"], hasProfileImage: true, creationDate: nil, modificationDate: nil)
        ]
        let group = DuplicateGroup(contacts: contacts, matchType: .exactName, confidence: 1.0)

        var plan = MergePlan.initial(for: group)
        plan.preferredNameContactId = "secondary"
        plan.preferredOrganizationContactId = "secondary"
        plan.preferredPhotoContactId = "secondary"
        plan.selectedPhoneNumbers.remove("222")
        plan.selectedEmailAddresses = ["primary@example.com"]

        let configuration = plan.configuration(primaryContactId: "primary", group: group)

        XCTAssertEqual(configuration.primaryContactId, "primary")
        XCTAssertEqual(configuration.mergingContactIds.sorted(), ["primary", "secondary"])
        XCTAssertEqual(configuration.preferredNameSourceId, "secondary")
        XCTAssertEqual(configuration.preferredOrganizationSourceId, "secondary")
        XCTAssertEqual(configuration.preferredPhotoSourceId, "secondary")
        XCTAssertEqual(configuration.includedPhoneNumbers, ["111", "333"])
        XCTAssertEqual(configuration.includedEmailAddresses, ["primary@example.com"])
    }

    func testMergeEngineRespectsPreferredSourcesAndAllowedValues() {
        let destination = makeContact(
            id: "dest",
            given: "Old",
            family: "Name",
            organization: "Old Org",
            phones: ["111", "222"],
            emails: ["old@example.com"]
        )

        let source = makeContact(
            id: "source",
            given: "New",
            family: "Name",
            organization: "New Org",
            phones: ["333", "555"],
            emails: ["new@example.com", "keep@example.com"]
        )

        let configuration = MergeConfiguration(
            primaryContactId: "dest",
            mergingContactIds: ["dest", "source"],
            preferredNameSourceId: "source",
            preferredOrganizationSourceId: "source",
            preferredPhotoSourceId: nil,
            includedPhoneNumbers: ["111", "333"],
            includedEmailAddresses: ["keep@example.com"]
        )

        let merged = MergeEngine.mergedContact(
            configuration: configuration,
            destinationContact: destination,
            sourceContacts: [source]
        )

        XCTAssertEqual(merged.givenName, "New")
        XCTAssertEqual(merged.familyName, "Name")
        XCTAssertEqual(merged.organizationName, "New Org")

        let mergedPhones = Set(merged.phoneNumbers.map { $0.value.stringValue })
        XCTAssertEqual(mergedPhones, ["111", "333"])

        let mergedEmails = Set(merged.emailAddresses.map { $0.value as String })
        XCTAssertEqual(mergedEmails, ["keep@example.com"])
    }

    // MARK: - Helpers

    private func makeContact(
        id: String,
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
        contact.phoneNumbers = phones.map {
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
        }
        contact.emailAddresses = emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
        contact.setValue(id, forKey: "identifier")
        return contact.copy() as! CNContact
    }
}
