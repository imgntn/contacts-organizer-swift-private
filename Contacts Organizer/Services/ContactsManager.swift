//
//  ContactsManager.swift
//  Contacts Organizer
//
//  Main service for managing contacts via CNContactStore
//

import Foundation
import Contacts
import SwiftUI
import Combine

class ContactsManager: ObservableObject {
    static let shared = ContactsManager()

    nonisolated(unsafe) private let store = CNContactStore()

    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var contacts: [ContactSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statistics: ContactStatistics?
    @Published var groups: [CNGroup] = []

    private init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func updateAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async -> Bool {
        print("📱 Requesting contacts access...")
        print("📱 Current status: \(CNContactStore.authorizationStatus(for: .contacts).rawValue)")

        do {
            let granted = try await store.requestAccess(for: .contacts)
            print("📱 Access granted: \(granted)")

            await MainActor.run {
                updateAuthorizationStatus()
                print("📱 New status: \(authorizationStatus.rawValue)")
            }
            return granted
        } catch {
            print("❌ Error requesting access: \(error)")
            await MainActor.run {
                errorMessage = "Failed to request access: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Fetch Contacts

    func fetchAllContacts() async {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Not authorized to access contacts"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Run blocking operation on background thread (detached to avoid main thread blocking)
        let result = await Task.detached { [weak self] in
            guard let self = self else { return Result<([ContactSummary], ContactStatistics), Error>.failure(NSError(domain: "ContactsManager", code: -1)) }

            do {
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactMiddleNameKey as CNKeyDescriptor,
                    CNContactOrganizationNameKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor,
                    CNContactImageDataAvailableKey as CNKeyDescriptor,
                    CNContactDatesKey as CNKeyDescriptor,
                    CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                ]

                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var fetchedContacts: [ContactSummary] = []

                try self.store.enumerateContacts(with: request) { contact, _ in
                    fetchedContacts.append(ContactSummary(from: contact))
                }

                let stats = self.calculateStatistics(from: fetchedContacts)

                return .success((fetchedContacts, stats))
            } catch {
                return .failure(error)
            }
        }.value

        await MainActor.run {
            switch result {
            case .success(let (fetchedContacts, stats)):
                self.contacts = fetchedContacts
                self.statistics = stats
                self.isLoading = false
            case .failure(let error):
                self.errorMessage = "Failed to fetch contacts: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Statistics

    nonisolated private func calculateStatistics(from contacts: [ContactSummary], issues: [DataQualityIssue]? = nil) -> ContactStatistics {
        let totalContacts = contacts.count
        let contactsWithPhone = contacts.filter { !$0.phoneNumbers.isEmpty }.count
        let contactsWithEmail = contacts.filter { !$0.emailAddresses.isEmpty }.count
        let contactsWithBoth = contacts.filter { !$0.phoneNumbers.isEmpty && !$0.emailAddresses.isEmpty }.count
        let contactsWithOrg = contacts.filter { $0.organization != nil }.count
        let contactsWithPhoto = contacts.filter { $0.hasProfileImage }.count

        // Count issues by severity
        let highPriority = issues?.filter { $0.severity == .high }.count ?? 0
        let mediumPriority = issues?.filter { $0.severity == .medium }.count ?? 0
        let lowPriority = issues?.filter { $0.severity == .low }.count ?? 0

        return ContactStatistics(
            totalContacts: totalContacts,
            contactsWithPhone: contactsWithPhone,
            contactsWithEmail: contactsWithEmail,
            contactsWithBoth: contactsWithBoth,
            contactsWithOrganization: contactsWithOrg,
            contactsWithPhoto: contactsWithPhoto,
            duplicateGroups: 0, // Will be calculated by duplicate detector
            dataQualityIssues: issues?.count ?? 0,
            highPriorityIssues: highPriority,
            mediumPriorityIssues: mediumPriority,
            lowPriorityIssues: lowPriority
        )
    }

    // MARK: - Contact Operations

    func mergeContacts(sourceIds: [String], destinationId: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        do {
            // Fetch all contacts with all needed keys
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactMiddleNameKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactDepartmentNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPostalAddressesKey as CNKeyDescriptor,
                CNContactUrlAddressesKey as CNKeyDescriptor,
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactNoteKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactSocialProfilesKey as CNKeyDescriptor,
                CNContactInstantMessageAddressesKey as CNKeyDescriptor
            ]

            // Fetch destination contact (the one we'll keep)
            guard let destinationContact = try? store.unifiedContact(
                withIdentifier: destinationId,
                keysToFetch: keysToFetch
            ) else {
                await MainActor.run {
                    errorMessage = "Failed to fetch destination contact"
                }
                return false
            }

            // Fetch source contacts (the ones we'll merge in and delete)
            var sourceContacts: [CNContact] = []
            for sourceId in sourceIds {
                if let contact = try? store.unifiedContact(
                    withIdentifier: sourceId,
                    keysToFetch: keysToFetch
                ) {
                    sourceContacts.append(contact)
                }
            }

            // Create mutable copy of destination
            let mergedContact = destinationContact.mutableCopy() as! CNMutableContact

            // Merge phone numbers (avoid duplicates)
            var existingPhones = Set(mergedContact.phoneNumbers.map { $0.value.stringValue })
            for source in sourceContacts {
                for phone in source.phoneNumbers {
                    let phoneString = phone.value.stringValue
                    if !existingPhones.contains(phoneString) {
                        mergedContact.phoneNumbers.append(phone)
                        existingPhones.insert(phoneString)
                    }
                }
            }

            // Merge email addresses (avoid duplicates)
            var existingEmails = Set(mergedContact.emailAddresses.map { $0.value as String })
            for source in sourceContacts {
                for email in source.emailAddresses {
                    let emailString = email.value as String
                    if !existingEmails.contains(emailString) {
                        mergedContact.emailAddresses.append(email)
                        existingEmails.insert(emailString)
                    }
                }
            }

            // Merge addresses (avoid duplicates)
            for source in sourceContacts {
                for address in source.postalAddresses {
                    // Check if this address already exists
                    let isDuplicate = mergedContact.postalAddresses.contains { existing in
                        let existingAddr = existing.value
                        let sourceAddr = address.value
                        return existingAddr.street == sourceAddr.street &&
                               existingAddr.city == sourceAddr.city &&
                               existingAddr.postalCode == sourceAddr.postalCode
                    }
                    if !isDuplicate {
                        mergedContact.postalAddresses.append(address)
                    }
                }
            }

            // Merge URLs (avoid duplicates)
            var existingUrls = Set(mergedContact.urlAddresses.map { $0.value as String })
            for source in sourceContacts {
                for url in source.urlAddresses {
                    let urlString = url.value as String
                    if !existingUrls.contains(urlString) {
                        mergedContact.urlAddresses.append(url)
                        existingUrls.insert(urlString)
                    }
                }
            }

            // Merge social profiles (avoid duplicates)
            for source in sourceContacts {
                for profile in source.socialProfiles {
                    let isDuplicate = mergedContact.socialProfiles.contains { existing in
                        existing.value.service == profile.value.service &&
                        existing.value.username == profile.value.username
                    }
                    if !isDuplicate {
                        mergedContact.socialProfiles.append(profile)
                    }
                }
            }

            // Merge instant message addresses (avoid duplicates)
            for source in sourceContacts {
                for im in source.instantMessageAddresses {
                    let isDuplicate = mergedContact.instantMessageAddresses.contains { existing in
                        existing.value.service == im.value.service &&
                        existing.value.username == im.value.username
                    }
                    if !isDuplicate {
                        mergedContact.instantMessageAddresses.append(im)
                    }
                }
            }

            // Merge notes (append if destination note is empty or different)
            for source in sourceContacts {
                if !source.note.isEmpty && source.note != mergedContact.note {
                    if mergedContact.note.isEmpty {
                        mergedContact.note = source.note
                    } else {
                        mergedContact.note += "\n\n---\n\n" + source.note
                    }
                }
            }

            // Use organization info from source if destination doesn't have it
            if mergedContact.organizationName.isEmpty {
                for source in sourceContacts {
                    if !source.organizationName.isEmpty {
                        mergedContact.organizationName = source.organizationName
                        mergedContact.departmentName = source.departmentName
                        mergedContact.jobTitle = source.jobTitle
                        break
                    }
                }
            }

            // Use birthday from source if destination doesn't have it
            if mergedContact.birthday == nil {
                for source in sourceContacts {
                    if let birthday = source.birthday {
                        mergedContact.birthday = birthday
                        break
                    }
                }
            }

            // Use image from source if destination doesn't have one
            if mergedContact.imageData == nil {
                for source in sourceContacts {
                    if let imageData = source.imageData {
                        mergedContact.imageData = imageData
                        break
                    }
                }
            }

            // Create save request
            let saveRequest = CNSaveRequest()

            // Update the merged contact
            saveRequest.update(mergedContact)

            // Delete source contacts
            for source in sourceContacts {
                saveRequest.delete(source.mutableCopy() as! CNMutableContact)
            }

            // Execute the save request
            try store.execute(saveRequest)

            print("✅ Successfully merged \(sourceIds.count) contacts into \(destinationId)")

            // Refresh contacts after merge
            await fetchAllContacts()

            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to merge contacts: \(error.localizedDescription)"
            }
            print("❌ Merge error: \(error)")
            return false
        }
    }

    func createGroup(name: String, contactIds: [String]) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        do {
            let group = CNMutableGroup()
            group.name = name

            let saveRequest = CNSaveRequest()
            saveRequest.add(group, toContainerWithIdentifier: nil)

            // Add contacts to group
            for contactId in contactIds {
                if let contact = try? store.unifiedContact(
                    withIdentifier: contactId,
                    keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor]
                ) {
                    saveRequest.addMember(contact, to: group)
                }
            }

            try store.execute(saveRequest)
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Fetch Groups

    func fetchAllGroups() async {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Not authorized to access contacts"
            }
            return
        }

        do {
            let fetchedGroups = try store.groups(matching: nil)

            await MainActor.run {
                self.groups = fetchedGroups
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch groups: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Backup

    func createBackup(saveToURL: URL? = nil) async -> (userBackup: URL?, appBackup: URL?) {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Not authorized to access contacts"
            }
            return (nil, nil)
        }

        // Run blocking operation on background thread (detached to avoid main thread blocking)
        let result = await Task.detached { [weak self] in
            guard let self = self else { return Result<(URL?, URL?), Error>.failure(NSError(domain: "ContactsManager", code: -1)) }

            do {
                // Fetch all contacts with all available keys
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactVCardSerialization.descriptorForRequiredKeys()
                ]

                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var allContacts: [CNContact] = []

                try self.store.enumerateContacts(with: request) { contact, _ in
                    allContacts.append(contact)
                }

                // Convert to vCard data
                let vCardData = try CNContactVCardSerialization.data(with: allContacts)

                // Create filename with timestamp
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Contacts_Backup_\(timestamp).vcf"

                var userBackupURL: URL?
                var appBackupURL: URL?

                // Save to user-specified location (if provided)
                if let saveToURL = saveToURL {
                    try vCardData.write(to: saveToURL)
                    userBackupURL = saveToURL
                    print("✅ User backup created: \(saveToURL.path)")
                } else {
                    // Default to Downloads folder
                    let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                    let fileURL = downloadsURL.appendingPathComponent(filename)
                    try vCardData.write(to: fileURL)
                    userBackupURL = fileURL
                    print("✅ User backup created: \(fileURL.path)")
                }

                // Always save a safety copy to app's Application Support directory
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let appBackupFolder = appSupportURL.appendingPathComponent("com.playablefuture.contactsorganizer/Backups", isDirectory: true)

                // Create backup directory if it doesn't exist
                try FileManager.default.createDirectory(at: appBackupFolder, withIntermediateDirectories: true)

                let appBackupFile = appBackupFolder.appendingPathComponent(filename)
                try vCardData.write(to: appBackupFile)
                appBackupURL = appBackupFile
                print("✅ Safety backup created: \(appBackupFile.path)")

                return .success((userBackupURL, appBackupURL))

            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let urls):
            return urls
        case .failure(let error):
            await MainActor.run {
                errorMessage = "Failed to create backup: \(error.localizedDescription)"
            }
            return (nil, nil)
        }
    }

    // MARK: - Smart Groups

    func generateSmartGroups(definitions: [SmartGroupDefinition], using testContacts: [ContactSummary]? = nil) -> [SmartGroupResult] {
        var results: [SmartGroupResult] = []
        let contactsList = testContacts ?? self.contacts  // Use test contacts if provided, otherwise use real contacts

        for definition in definitions where definition.isEnabled {
            switch definition.groupingType {
            case .geographic(let criteria):
                results.append(contentsOf: Self.groupByGeography(contactsList, criteria: criteria))

            case .organization:
                results.append(contentsOf: Self.groupByOrganization(contactsList))

            case .custom(let criteria):
                results.append(contentsOf: Self.groupByCustomCriteria(contactsList, name: definition.name, criteria: criteria))
            }
        }

        return results
    }

    nonisolated private static func groupByGeography(_ contacts: [ContactSummary], criteria: GeographicCriteria) -> [SmartGroupResult] {
        let contactsWithLocation = contacts.filter { contact in
            guard let org = contact.organization else { return false }
            return !org.isEmpty
        }

        return [SmartGroupResult(
            groupName: "Contacts with Location Info",
            contacts: contactsWithLocation,
            criteria: .geographic(criteria)
        )]
    }

    nonisolated private static func groupByOrganization(_ contacts: [ContactSummary]) -> [SmartGroupResult] {
        var organizationGroups: [String: [ContactSummary]] = [:]

        for contact in contacts {
            if let org = contact.organization, !org.isEmpty {
                organizationGroups[org, default: []].append(contact)
            }
        }

        return organizationGroups
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .map { org, contacts in
                SmartGroupResult(
                    groupName: org,
                    contacts: contacts,
                    criteria: .organization
                )
            }
    }

    nonisolated private static func groupByCustomCriteria(_ contacts: [ContactSummary], name: String, criteria: CustomCriteria) -> [SmartGroupResult] {
        let matchingContacts = contacts.filter { contact in
            criteria.rules.allSatisfy { rule in
                Self.matchesRule(contact: contact, rule: rule)
            }
        }

        guard !matchingContacts.isEmpty else { return [] }

        return [SmartGroupResult(
            groupName: name,
            contacts: matchingContacts,
            criteria: .custom(criteria)
        )]
    }

    nonisolated private static func matchesRule(contact: ContactSummary, rule: CustomCriteria.Rule) -> Bool {
        switch rule.field {
        case .hasPhone:
            return rule.condition == .exists ? !contact.phoneNumbers.isEmpty : contact.phoneNumbers.isEmpty

        case .hasEmail:
            return rule.condition == .exists ? !contact.emailAddresses.isEmpty : contact.emailAddresses.isEmpty

        case .hasOrganization:
            let hasOrg = contact.organization != nil && !contact.organization!.isEmpty
            return rule.condition == .exists ? hasOrg : !hasOrg

        case .hasPhoto:
            return rule.condition == .exists ? contact.hasProfileImage : !contact.hasProfileImage

        case .organizationContains:
            guard let org = contact.organization, let value = rule.value else { return false }
            return org.localizedCaseInsensitiveContains(value)

        case .nameContains:
            guard let value = rule.value else { return false }
            // Check if the value matches at word boundaries
            let name = contact.fullName.lowercased()
            let searchValue = value.lowercased()

            // Split name into words and check if any word matches
            let words = name.components(separatedBy: .whitespaces)
            return words.contains { word in
                // Exact match or starts with search value and isn't too long
                // (e.g., "Johnny" matches "John", but "Johnson" doesn't)
                if word == searchValue {
                    return true
                }
                if word.hasPrefix(searchValue) {
                    // Allow words that are at most 2 characters longer (handles variants like "Johnny")
                    return word.count <= searchValue.count + 2
                }
                return false
            }

        // Phase 1: Quick wins using existing data
        case .phoneOnly:
            return !contact.phoneNumbers.isEmpty && contact.emailAddresses.isEmpty

        case .emailOnly:
            return !contact.emailAddresses.isEmpty && contact.phoneNumbers.isEmpty

        case .noCriticalInfo:
            return contact.phoneNumbers.isEmpty && contact.emailAddresses.isEmpty

        case .multiplePhones:
            return contact.phoneNumbers.count >= 2

        case .multipleEmails:
            return contact.emailAddresses.count >= 2
        }
    }

    // MARK: - Default Smart Group Definitions

    static var defaultSmartGroups: [SmartGroupDefinition] {
        return [
            SmartGroupDefinition(
                name: "By Organization",
                groupingType: .organization
            ),
            SmartGroupDefinition(
                name: "Complete Contacts",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasPhone, condition: .exists),
                    CustomCriteria.Rule(field: .hasEmail, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Missing Email",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasEmail, condition: .notExists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Has Photo",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasPhoto, condition: .exists)
                ]))
            ),

            // Phase 1: Quick wins using existing data
            SmartGroupDefinition(
                name: "Missing Critical Info",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .noCriticalInfo, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Phone Only (No Email)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .phoneOnly, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Email Only (No Phone)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .emailOnly, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Multiple Phone Numbers",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .multiplePhones, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Multiple Email Addresses",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .multipleEmails, condition: .exists)
                ]))
            )
        ]
    }

    // MARK: - Test Data & Import/Export

    @MainActor
    func updateStatisticsWithIssues(_ issues: [DataQualityIssue]) {
        // Recalculate statistics with issue severity counts
        self.statistics = calculateStatistics(from: self.contacts, issues: issues)
    }

    func loadTestContacts(count: Int = 100) async {
        await MainActor.run {
            isLoading = true
        }

        let testContacts = TestDataGenerator.shared.generateTestContacts(count: count)

        await MainActor.run {
            self.contacts = testContacts
            self.statistics = calculateStatistics(from: testContacts)
            self.isLoading = false
        }
    }

    func importContacts(from url: URL) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let importedContacts = try ImportExportService.shared.importContacts(from: url)

            await MainActor.run {
                self.contacts = importedContacts
                self.statistics = calculateStatistics(from: importedContacts)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to import contacts: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func exportContacts(to url: URL) async -> Bool {
        do {
            try ImportExportService.shared.exportContacts(contacts, to: url)
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to export contacts: \(error.localizedDescription)"
            }
            return false
        }
    }

    func generateTestDatabase(count: Int = 100, saveTo url: URL? = nil) async -> Bool {
        let destination = url ?? ImportExportService.shared.defaultTestDatabaseURL()

        do {
            try ImportExportService.shared.generateAndSaveTestDatabase(count: count, to: destination)
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate test database: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Utility

    func resetError() {
        errorMessage = nil
    }
}
