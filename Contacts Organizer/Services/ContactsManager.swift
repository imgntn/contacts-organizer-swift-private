//
//  ContactsManager.swift
//  Contacts Organizer
//
//  Main service for managing contacts via CNContactStore
//

import Foundation
@preconcurrency import Contacts
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

    // Use a dedicated queue for CNContactStore I/O to avoid QoS inversions
    private let contactsQueue = DispatchQueue(label: "com.playablefuture.contactsorganizer.contacts", qos: .utility)

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

        // Track performance
        let startTime = Date()

        // Run CNContactStore work on a utility queue to avoid QoS inversion
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<([ContactSummary], ContactStatistics), Error>, Never>) in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(NSError(domain: "ContactsManager", code: -1)))
                    return
                }

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
                        CNContactBirthdayKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                    ]

                    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                    var fetchedContacts: [ContactSummary] = []

                    try self.store.enumerateContacts(with: request) { contact, _ in
                        fetchedContacts.append(ContactSummary(from: contact))
                    }

                    let stats = self.calculateStatistics(from: fetchedContacts)
                    continuation.resume(returning: .success((fetchedContacts, stats)))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        await MainActor.run {
            switch result {
            case .success(let (fetchedContacts, stats)):
                self.contacts = fetchedContacts
                self.statistics = stats
                self.isLoading = false
                // Record performance metrics
                PrivacyMonitorService.shared.recordContactFetch(duration: duration)
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
        let suggestions = issues?.filter { $0.severity == .suggestion }.count ?? 0

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
            lowPriorityIssues: lowPriority,
            suggestions: suggestions
        )
    }

    // MARK: - Contact Operations

    func mergeContacts(sourceIds: [String], destinationId: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        do {
            // Fetch all contacts with all needed keys (exclude CNContactNoteKey to avoid entitlement issues)
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

            // Notes merge removed (CNContact.note is restricted by entitlement)

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

        // Use the dedicated queue instead of Task.detached
        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    // Check if group with this name already exists
                    let existingGroups = try self.store.groups(matching: nil)
                    if existingGroups.contains(where: { $0.name == name }) {
                        Task { @MainActor in
                            self.errorMessage = "Group '\(name)' already exists"
                        }
                        continuation.resume(returning: false)
                        return
                    }

                    let group = CNMutableGroup()
                    group.name = name

                    let saveRequest = CNSaveRequest()
                    saveRequest.add(group, toContainerWithIdentifier: nil)

                    // Add contacts to group
                    for contactId in contactIds {
                        if let contact = try? self.store.unifiedContact(
                            withIdentifier: contactId,
                            keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor]
                        ) {
                            saveRequest.addMember(contact, to: group)
                        }
                    }

                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to create group: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
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

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[CNGroup], Error>, Never>) in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(NSError(domain: "ContactsManager", code: -1)))
                    return
                }
                do {
                    let fetchedGroups = try self.store.groups(matching: nil)
                    continuation.resume(returning: .success(fetchedGroups))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        await MainActor.run {
            switch result {
            case .success(let fetchedGroups):
                self.groups = fetchedGroups
            case .failure(let error):
                self.errorMessage = "Failed to fetch groups: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Fetch Contacts for Group

    func fetchContactsForGroup(_ group: CNGroup) async -> [ContactSummary] {
        guard authorizationStatus == .authorized else { return [] }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

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
                        CNContactBirthdayKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                    ]

                    let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
                    let contacts = try self.store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                    let summaries = contacts.map { ContactSummary(from: $0) }

                    continuation.resume(returning: summaries)
                } catch {
                    print("Failed to fetch contacts for group: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Duplicate Group Detection & Cleanup

    func findDuplicateGroups() async -> [String: [CNGroup]] {
        guard authorizationStatus == .authorized else { return [:] }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[CNGroup], Error>, Never>) in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(NSError(domain: "ContactsManager", code: -1)))
                    return
                }
                do {
                    let fetchedGroups = try self.store.groups(matching: nil)
                    continuation.resume(returning: .success(fetchedGroups))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        switch result {
        case .success(let fetchedGroups):
            var groupsByName: [String: [CNGroup]] = [:]
            for group in fetchedGroups {
                groupsByName[group.name, default: []].append(group)
            }
            return groupsByName.filter { $0.value.count > 1 }
        case .failure(let error):
            await MainActor.run {
                self.errorMessage = "Failed to find duplicates: \(error.localizedDescription)"
            }
            return [:]
        }
    }

    func deleteDuplicateGroups(keepFirst: Bool = true) async -> (deleted: Int, errors: Int) {
        guard authorizationStatus == .authorized else { return (0, 0) }

        let duplicates = await findDuplicateGroups()
        var deletedCount = 0
        var errorCount = 0

        for (_, groups) in duplicates {
            // Keep the first one, delete the rest
            let groupsToDelete = keepFirst ? Array(groups.dropFirst()) : Array(groups.dropLast())

            for group in groupsToDelete {
                let result = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                    contactsQueue.async { [weak self] in
                        guard let self = self else {
                            continuation.resume(returning: false)
                            return
                        }
                        let saveRequest = CNSaveRequest()
                        saveRequest.delete(group.mutableCopy() as! CNMutableGroup)
                        do {
                            try self.store.execute(saveRequest)
                            continuation.resume(returning: true)
                        } catch {
                            print("Failed to delete duplicate group '\(group.name)': \(error)")
                            continuation.resume(returning: false)
                        }
                    }
                }
                if result { deletedCount += 1 } else { errorCount += 1 }
            }
        }

        // Refresh groups list
        await fetchAllGroups()

        return (deletedCount, errorCount)
    }

    // MARK: - Backup

    func createBackup(saveToURL: URL? = nil) async -> (userBackup: URL?, appBackup: URL?) {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Not authorized to access contacts"
            }
            return (nil, nil)
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<(URL?, URL?), Error>, Never>) in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(NSError(domain: "ContactsManager", code: -1)))
                    return
                }

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

                    continuation.resume(returning: .success((userBackupURL, appBackupURL)))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

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

    func generateSmartGroups(definitions: [SmartGroupDefinition], using testContacts: [ContactSummary]? = nil) async -> [SmartGroupResult] {
        // Keep this as CPU-bound work; not CNContactStore I/O
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] }

            var results: [SmartGroupResult] = []

            // Use test contacts if provided, otherwise use real contacts
            let contactsList: [ContactSummary]
            if let testContacts = testContacts {
                contactsList = testContacts
            } else {
                contactsList = await MainActor.run { self.contacts }
            }

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
        }.value
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

        // Phase 2: Time-based criteria
        case .recentlyAdded:
            guard let creationDate = contact.creationDate else { return false }
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            return creationDate >= thirtyDaysAgo

        case .recentlyModified:
            guard let modificationDate = contact.modificationDate else { return false }
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            return modificationDate >= thirtyDaysAgo

        case .staleContact:
            guard let modificationDate = contact.modificationDate else { return false }
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            return modificationDate < oneYearAgo

        case .birthdayThisMonth:
            guard let birthday = contact.birthday else { return false }
            let calendar = Calendar.current
            let now = Date()
            let birthdayMonth = calendar.component(.month, from: birthday)
            let currentMonth = calendar.component(.month, from: now)
            return birthdayMonth == currentMonth

        case .birthdayThisWeek:
            guard let birthday = contact.birthday else { return false }
            let calendar = Calendar.current
            let now = Date()

            // Get current week's start and end dates
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
                  let weekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end else {
                return false
            }

            // Get birthday's day and month
            let birthdayDay = calendar.component(.day, from: birthday)
            let birthdayMonth = calendar.component(.month, from: birthday)

            // Create this year's birthday date
            var birthdayComponents = DateComponents()
            birthdayComponents.month = birthdayMonth
            birthdayComponents.day = birthdayDay
            birthdayComponents.year = calendar.component(.year, from: now)

            guard let thisYearBirthday = calendar.date(from: birthdayComponents) else {
                return false
            }

            // Check if birthday falls within this week
            return thisYearBirthday >= weekStart && thisYearBirthday < weekEnd
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
            ),

            // Phase 2: Time-based smart groups
            SmartGroupDefinition(
                name: "Recently Added (Last 30 Days)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .recentlyAdded, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Recently Modified (Last 30 Days)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .recentlyModified, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Stale Contacts (1+ Year)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .staleContact, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Birthday This Month",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .birthdayThisMonth, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Birthday This Week",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .birthdayThisWeek, condition: .exists)
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
