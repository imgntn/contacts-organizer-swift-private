#!/usr/bin/env swift

import Foundation

// MARK: - ContactSummary Model

struct ContactSummary: Codable {
    let id: String
    let fullName: String
    let organization: String?
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let hasProfileImage: Bool
    let creationDate: Date?
    let modificationDate: Date?
}

// MARK: - Test Data Generator

let firstNames = [
    "John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Jennifer",
    "William", "Lisa", "James", "Mary", "Christopher", "Patricia", "Daniel", "Linda"
]

let lastNames = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore"
]

let companies = [
    "Apple Inc.", "Google", "Microsoft", "Amazon", "Meta", "Tesla",
    "Acme Corp", "Tech Solutions", "Digital Ventures", "Innovation Labs"
]

let emailDomains = ["gmail.com", "yahoo.com", "outlook.com", "company.com"]

func generatePhoneNumber() -> String {
    let areaCode = Int.random(in: 200...999)
    let prefix = Int.random(in: 200...999)
    let lineNumber = Int.random(in: 1000...9999)
    return String(format: "(%03d) %03d-%04d", areaCode, prefix, lineNumber)
}

func generateEmail(firstName: String, lastName: String) -> String {
    let domain = emailDomains.randomElement()!
    return "\(firstName.lowercased()).\(lastName.lowercased())@\(domain)"
}

func randomDate() -> Date {
    let now = Date()
    let oneYearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)
    let randomInterval = TimeInterval.random(in: 0...(365 * 24 * 60 * 60))
    return oneYearAgo.addingTimeInterval(randomInterval)
}

func generateTestContacts(count: Int = 100) -> [ContactSummary] {
    var contacts: [ContactSummary] = []

    for i in 0..<count {
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        let fullName = "\(firstName) \(lastName)"

        let organization = Bool.random() ? companies.randomElement() : nil

        let phoneCount = Int.random(in: 1...2)
        let phoneNumbers = (0..<phoneCount).map { _ in generatePhoneNumber() }

        let emailCount = Int.random(in: 1...2)
        let emailAddresses = (0..<emailCount).map { _ in
            generateEmail(firstName: firstName, lastName: lastName)
        }

        let contact = ContactSummary(
            id: "test-\(i)",
            fullName: fullName,
            organization: organization,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            hasProfileImage: Bool.random(),
            creationDate: randomDate(),
            modificationDate: randomDate()
        )
        contacts.append(contact)
    }

    // Add some duplicates
    for i in 0..<(count / 10) {
        if i < contacts.count {
            let original = contacts[i]
            let duplicate = ContactSummary(
                id: "dup-\(i)",
                fullName: original.fullName,
                organization: original.organization,
                phoneNumbers: [generatePhoneNumber()],
                emailAddresses: [generateEmail(firstName: "test", lastName: "user")],
                hasProfileImage: Bool.random(),
                creationDate: randomDate(),
                modificationDate: randomDate()
            )
            contacts.append(duplicate)
        }
    }

    return contacts.shuffled()
}

// MARK: - Main

let count = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 100 : 100
let outputFile = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "test_contacts.json"

print("Generating \(count) test contacts...")
let contacts = generateTestContacts(count: count)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601

do {
    let data = try encoder.encode(contacts)
    let url = URL(fileURLWithPath: outputFile)
    try data.write(to: url)
    print("✓ Generated \(contacts.count) contacts")
    print("✓ Saved to: \(outputFile)")
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
