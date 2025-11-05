//
//  TestDataGenerator.swift
//  Contacts Organizer
//
//  Service for generating realistic test contact data for development and testing
//

import Foundation
import Contacts

class TestDataGenerator {
    static let shared = TestDataGenerator()

    private init() {}

    // MARK: - Sample Data

    private let firstNames = [
        "John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Jennifer",
        "William", "Lisa", "James", "Mary", "Christopher", "Patricia", "Daniel", "Linda",
        "Matthew", "Barbara", "Anthony", "Elizabeth", "Mark", "Susan", "Donald", "Jessica",
        "Steven", "Karen", "Paul", "Nancy", "Andrew", "Betty", "Joshua", "Margaret",
        "Kenneth", "Sandra", "Kevin", "Ashley", "Brian", "Kimberly", "George", "Donna"
    ]

    private let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
        "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White",
        "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
        "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green"
    ]

    private let companies = [
        "Apple Inc.", "Google", "Microsoft", "Amazon", "Meta", "Tesla", "IBM", "Oracle",
        "Salesforce", "Adobe", "Netflix", "Spotify", "Uber", "Airbnb", "Twitter",
        "LinkedIn", "Dropbox", "Slack", "Zoom", "GitHub", "Stripe", "Square",
        "PayPal", "eBay", "Shopify", "Atlassian", "Autodesk", "Intuit", "ServiceNow",
        "Workday", "DocuSign", "HubSpot", "Zendesk", "Twilio", "Okta", "Splunk",
        "Acme Corp", "Tech Solutions", "Digital Ventures", "Innovation Labs"
    ]

    private let emailDomains = [
        "gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com",
        "company.com", "work.net", "business.org", "email.com", "mail.com"
    ]

    // MARK: - Generate Test Contacts

    func generateTestContacts(count: Int = 100) -> [ContactSummary] {
        var contacts: [ContactSummary] = []

        // Generate unique contacts
        for i in 0..<count {
            let contact = generateRandomContact(id: "test-\(i)")
            contacts.append(contact)
        }

        // Add some duplicates (10% of contacts)
        let duplicateCount = max(1, count / 10)
        for i in 0..<duplicateCount {
            if i < contacts.count {
                let original = contacts[i]

                // Create variations of duplicates
                if i % 3 == 0 {
                    // Exact name duplicate
                    contacts.append(generateDuplicateContact(from: original, id: "dup-exact-\(i)", variation: .exactName))
                } else if i % 3 == 1 {
                    // Similar name duplicate
                    contacts.append(generateDuplicateContact(from: original, id: "dup-similar-\(i)", variation: .similarName))
                } else {
                    // Same phone/email duplicate
                    contacts.append(generateDuplicateContact(from: original, id: "dup-contact-\(i)", variation: .sameContact))
                }
            }
        }

        // Add some incomplete contacts (5% of contacts)
        let incompleteCount = max(1, count / 20)
        for i in 0..<incompleteCount {
            let incomplete = generateIncompleteContact(id: "incomplete-\(i)")
            contacts.append(incomplete)
        }

        return contacts.shuffled()
    }

    // MARK: - Contact Generation Helpers

    private func generateRandomContact(id: String) -> ContactSummary {
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        let fullName = "\(firstName) \(lastName)"

        let hasOrg = Bool.random()
        let organization = hasOrg ? companies.randomElement() : nil

        let phoneCount = Int.random(in: 1...3)
        let phoneNumbers = (0..<phoneCount).map { _ in generatePhoneNumber() }

        let emailCount = Int.random(in: 1...2)
        let emailAddresses = (0..<emailCount).map { _ in
            generateEmail(firstName: firstName, lastName: lastName)
        }

        let hasPhoto = Bool.random()

        return ContactSummary(
            id: id,
            fullName: fullName,
            organization: organization,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            hasProfileImage: hasPhoto,
            creationDate: randomDate(),
            modificationDate: randomDate()
        )
    }

    private enum DuplicateVariation {
        case exactName
        case similarName
        case sameContact
    }

    private func generateDuplicateContact(from original: ContactSummary, id: String, variation: DuplicateVariation) -> ContactSummary {
        switch variation {
        case .exactName:
            // Same name, different contact info
            return ContactSummary(
                id: id,
                fullName: original.fullName,
                organization: Bool.random() ? original.organization : companies.randomElement(),
                phoneNumbers: [generatePhoneNumber()],
                emailAddresses: [generateRandomEmail()],
                hasProfileImage: Bool.random(),
                creationDate: randomDate(),
                modificationDate: randomDate()
            )

        case .similarName:
            // Similar name (typo or variation)
            let variations = [
                original.fullName.replacingOccurrences(of: "a", with: "e"),
                original.fullName + "e",
                original.fullName.dropLast() + String(original.fullName.last ?? "a")
            ]
            let similarName = variations.randomElement() ?? original.fullName

            return ContactSummary(
                id: id,
                fullName: similarName,
                organization: original.organization,
                phoneNumbers: [generatePhoneNumber()],
                emailAddresses: [generateRandomEmail()],
                hasProfileImage: Bool.random(),
                creationDate: randomDate(),
                modificationDate: randomDate()
            )

        case .sameContact:
            // Same phone or email
            let useSamePhone = Bool.random()
            return ContactSummary(
                id: id,
                fullName: original.fullName + " Jr.",
                organization: original.organization,
                phoneNumbers: useSamePhone ? original.phoneNumbers : [generatePhoneNumber()],
                emailAddresses: useSamePhone ? [generateRandomEmail()] : original.emailAddresses,
                hasProfileImage: Bool.random(),
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
        }
    }

    private func generateIncompleteContact(id: String) -> ContactSummary {
        let type = Int.random(in: 0...3)
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!

        switch type {
        case 0:
            // Missing name
            return ContactSummary(
                id: id,
                fullName: "No Name",
                organization: nil,
                phoneNumbers: [generatePhoneNumber()],
                emailAddresses: [],
                hasProfileImage: false,
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
        case 1:
            // Missing phone
            return ContactSummary(
                id: id,
                fullName: "\(firstName) \(lastName)",
                organization: nil,
                phoneNumbers: [],
                emailAddresses: [generateEmail(firstName: firstName, lastName: lastName)],
                hasProfileImage: false,
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
        case 2:
            // Missing email
            return ContactSummary(
                id: id,
                fullName: "\(firstName) \(lastName)",
                organization: nil,
                phoneNumbers: [generatePhoneNumber()],
                emailAddresses: [],
                hasProfileImage: false,
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
        default:
            // Missing all contact info
            return ContactSummary(
                id: id,
                fullName: "\(firstName) \(lastName)",
                organization: companies.randomElement(),
                phoneNumbers: [],
                emailAddresses: [],
                hasProfileImage: false,
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
        }
    }

    // MARK: - Data Generation Utilities

    private func generatePhoneNumber() -> String {
        let areaCode = Int.random(in: 200...999)
        let prefix = Int.random(in: 200...999)
        let lineNumber = Int.random(in: 1000...9999)
        return String(format: "(%03d) %03d-%04d", areaCode, prefix, lineNumber)
    }

    private func generateEmail(firstName: String, lastName: String) -> String {
        let domain = emailDomains.randomElement()!
        let separator = Bool.random() ? "." : "_"
        return "\(firstName.lowercased())\(separator)\(lastName.lowercased())@\(domain)"
    }

    private func generateRandomEmail() -> String {
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        return generateEmail(firstName: firstName, lastName: lastName)
    }

    private func randomDate() -> Date {
        let now = Date()
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let randomInterval = TimeInterval.random(in: 0...(365 * 24 * 60 * 60))
        return oneYearAgo.addingTimeInterval(randomInterval)
    }
}
