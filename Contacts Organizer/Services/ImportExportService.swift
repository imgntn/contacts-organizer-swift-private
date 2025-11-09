//
//  ImportExportService.swift
//  Contacts Organizer
//
//  Service for importing and exporting contact databases
//

import Foundation
import Contacts

class ImportExportService {
    static let shared = ImportExportService()

    private init() {}

    // MARK: - Export

    func exportContacts(_ contacts: [ContactSummary], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(contacts)
        try data.write(to: url)
    }

    func exportContactsToJSON(_ contacts: [ContactSummary]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(contacts)
    }

    // MARK: - Import

    func importContacts(from url: URL) throws -> [ContactSummary] {
        let data = try Data(contentsOf: url)
        return try importContactsFromData(data)
    }

    func importContactsFromData(_ data: Data) throws -> [ContactSummary] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ContactSummary].self, from: data)
    }

    // MARK: - Test Database

    func generateAndSaveTestDatabase(count: Int = 100, to url: URL) throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: count)
        try exportContacts(contacts, to: url)
    }

    func loadTestDatabase() -> [ContactSummary] {
        // Generate test contacts on the fly
        return TestDataGenerator.shared.generateTestContacts(count: 100)
    }

    // MARK: - Default Locations

    func defaultExportURL(filename: String = "contacts_export.json") -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(filename)
    }

    func defaultTestDatabaseURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("test_contacts.json")
    }
}

// MARK: - Codable Support for ContactSummary

extension ContactSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case id, fullName, organization, phoneNumbers, emailAddresses, hasProfileImage, creationDate, modificationDate, birthday
        case nickname, jobTitle, departmentName, postalAddresses, urlAddresses, socialProfiles, instantMessageAddresses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        organization = try container.decodeIfPresent(String.self, forKey: .organization)
        phoneNumbers = try container.decode([String].self, forKey: .phoneNumbers)
        emailAddresses = try container.decode([String].self, forKey: .emailAddresses)
        hasProfileImage = try container.decode(Bool.self, forKey: .hasProfileImage)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)

        // Extended properties (with backwards compatibility)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        departmentName = try container.decodeIfPresent(String.self, forKey: .departmentName)
        postalAddresses = try container.decodeIfPresent([String].self, forKey: .postalAddresses) ?? []
        urlAddresses = try container.decodeIfPresent([String].self, forKey: .urlAddresses) ?? []
        socialProfiles = try container.decodeIfPresent([SocialProfile].self, forKey: .socialProfiles) ?? []
        instantMessageAddresses = try container.decodeIfPresent([String].self, forKey: .instantMessageAddresses) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encodeIfPresent(organization, forKey: .organization)
        try container.encode(phoneNumbers, forKey: .phoneNumbers)
        try container.encode(emailAddresses, forKey: .emailAddresses)
        try container.encode(hasProfileImage, forKey: .hasProfileImage)
        try container.encodeIfPresent(creationDate, forKey: .creationDate)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
        try container.encodeIfPresent(birthday, forKey: .birthday)

        // Extended properties
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try container.encodeIfPresent(departmentName, forKey: .departmentName)
        try container.encode(postalAddresses, forKey: .postalAddresses)
        try container.encode(urlAddresses, forKey: .urlAddresses)
        try container.encode(socialProfiles, forKey: .socialProfiles)
        try container.encode(instantMessageAddresses, forKey: .instantMessageAddresses)
    }
}
