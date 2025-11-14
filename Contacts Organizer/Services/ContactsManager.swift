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
    enum RefreshReason: String {
        case contactStoreChange
        case mutation
    }

    struct RefreshTrigger: Identifiable, Equatable {
        let id = UUID()
        let reason: RefreshReason
        let timestamp = Date()
    }
    static let shared = ContactsManager()

    nonisolated(unsafe) private let store = CNContactStore()
    private lazy var changeHistoryWrapper = ContactChangeHistoryWrapper(store: store)

    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var contacts: [ContactSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statistics: ContactStatistics?
    @Published var groups: [CNGroup] = []
    @Published var recentActivities: [RecentActivity] = []
    @Published private(set) var refreshTrigger = RefreshTrigger(reason: .mutation)

    // Use a dedicated queue for CNContactStore I/O to avoid QoS inversions
    private let contactsQueue = DispatchQueue(label: "com.playablefuture.contactsorganizer.contacts", qos: .utility)
    private let recentActivityDefaultsKey = "recentActivityLog"
    private let recencyCacheDefaultsKey = "contactRecencyInfoCache"
    private let changeHistoryTokenDefaultsKey = "contactChangeHistoryAnchor"
    private var contactStoreObserver: NSObjectProtocol?
    private var refreshDebounceWorkItem: DispatchWorkItem?
    private var contactRecencyInfo: [String: ContactRecencyInfo] = [:]
    private var changeHistoryAnchor: Data?
    private let editableContactKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor
    ]

#if DEBUG
    struct BackupOverride {
        let contacts: [CNContact]
        let userDirectory: URL
        let appDirectory: URL
    }

    struct SnapshotOverride {
        let contacts: [CNContact]
        let snapshotDirectory: URL
    }

    struct MergeOverride {
        let destination: CNContact
        let sources: [CNContact]
        let onSave: (CNMutableContact, [CNContact]) -> Void
    }

    nonisolated(unsafe) static var backupOverride: BackupOverride?
    nonisolated(unsafe) static var snapshotOverride: SnapshotOverride?
    nonisolated(unsafe) static var mergeOverride: MergeOverride?
#endif

    private init() {
        updateAuthorizationStatus()
        loadRecencyState()
        Task { @MainActor in
            loadRecentActivities()
        }
        startContactStoreObservation()
    }

    deinit {
        if let contactStoreObserver {
            NotificationCenter.default.removeObserver(contactStoreObserver)
        }
    }

    private func startContactStoreObservation() {
        contactStoreObserver = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleContactStoreChange()
        }
    }

    private func handleContactStoreChange() {
        refreshDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.publishRefresh(reason: .contactStoreChange)
        }
        refreshDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func publishRefresh(reason: RefreshReason) {
        Task { @MainActor in
            self.refreshTrigger = RefreshTrigger(reason: reason)
        }
    }

    func signalDataMutation() {
        publishRefresh(reason: .mutation)
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

    @MainActor
    func logActivity(_ entry: RecentActivity) {
        recentActivities.insert(entry, at: 0)
        if recentActivities.count > 12 {
            recentActivities = Array(recentActivities.prefix(12))
        }
        persistRecentActivities()
    }

    @MainActor
    func logActivity(kind: RecentActivity.Kind, title: String, detail: String, icon: String) {
        logActivity(RecentActivity(kind: kind, title: title, detail: detail, icon: icon))
    }

    @MainActor
    private func loadRecentActivities() {
        guard let data = UserDefaults.standard.data(forKey: recentActivityDefaultsKey),
              let decoded = try? JSONDecoder().decode([RecentActivity].self, from: data) else {
            recentActivities = []
            return
        }
        recentActivities = decoded
    }

    @MainActor
    private func persistRecentActivities() {
        guard let data = try? JSONEncoder().encode(recentActivities) else { return }
        UserDefaults.standard.set(data, forKey: recentActivityDefaultsKey)
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
                    self.refreshRecencyInfoFromHistory()

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
                        // Extended contact information
                        CNContactNicknameKey as CNKeyDescriptor,
                        CNContactJobTitleKey as CNKeyDescriptor,
                        CNContactDepartmentNameKey as CNKeyDescriptor,
                        CNContactPostalAddressesKey as CNKeyDescriptor,
                        CNContactUrlAddressesKey as CNKeyDescriptor,
                        CNContactSocialProfilesKey as CNKeyDescriptor,
                        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                    ]

                    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                    var fetchedContacts: [ContactSummary] = []

                    try self.store.enumerateContacts(with: request) { contact, _ in
                        let recency = self.contactRecencyInfo[contact.identifier]
                        fetchedContacts.append(ContactSummary(from: contact, recencyInfo: recency))
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

        // Extended statistics from new features
        let contactsWithSocialMedia = contacts.filter { !$0.socialProfiles.isEmpty }.count
        let contactsWithAddress = contacts.filter { !$0.postalAddresses.isEmpty }.count
        let contactsWithJobTitle = contacts.filter { $0.jobTitle != nil && !$0.jobTitle!.isEmpty }.count
        let contactsWithWebsite = contacts.filter { !$0.urlAddresses.isEmpty }.count
        let contactsWithNickname = contacts.filter { $0.nickname != nil && !$0.nickname!.isEmpty }.count
        let contactsWithIM = contacts.filter { !$0.instantMessageAddresses.isEmpty }.count

        // Calculate high detail contacts (5+ data points)
        let highDetailContacts = contacts.filter { contact in
            var dataPoints = 0
            if !contact.phoneNumbers.isEmpty { dataPoints += 1 }
            if !contact.emailAddresses.isEmpty { dataPoints += 1 }
            if contact.organization != nil { dataPoints += 1 }
            if contact.jobTitle != nil { dataPoints += 1 }
            if !contact.postalAddresses.isEmpty { dataPoints += 1 }
            if !contact.socialProfiles.isEmpty { dataPoints += 1 }
            if !contact.urlAddresses.isEmpty { dataPoints += 1 }
            if contact.birthday != nil { dataPoints += 1 }
            return dataPoints >= 5
        }.count

        let now = Date()
        let additionCutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let updateCutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let mostRecentAddition = contacts.compactMap { $0.creationDate ?? $0.modificationDate }.max()
        let mostRecentUpdate = contacts.compactMap { $0.modificationDate }.max()

        let recentlyAddedCount = contacts.filter { contact in
            guard let created = contact.creationDate ?? contact.modificationDate else { return false }
            return created >= additionCutoff
        }.count

        let recentlyUpdatedCount = contacts.filter { contact in
            guard let modified = contact.modificationDate else { return false }
            return modified >= updateCutoff
        }.count

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
            suggestions: suggestions,
            contactsWithSocialMedia: contactsWithSocialMedia,
            contactsWithAddress: contactsWithAddress,
            contactsWithJobTitle: contactsWithJobTitle,
            contactsWithWebsite: contactsWithWebsite,
            contactsWithNickname: contactsWithNickname,
            contactsWithInstantMessaging: contactsWithIM,
            highDetailContacts: highDetailContacts,
            recentlyAddedCount: recentlyAddedCount,
            recentlyUpdatedCount: recentlyUpdatedCount,
            mostRecentAddition: mostRecentAddition,
            mostRecentUpdate: mostRecentUpdate
        )
    }

    // MARK: - Contact Operations

    func mergeContacts(using configuration: MergeConfiguration) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

#if DEBUG
        if let override = ContactsManager.mergeOverride {
            let mergedContact = MergeEngine.mergedContact(
                configuration: configuration,
                destinationContact: override.destination,
                sourceContacts: override.sources
            )
            override.onSave(mergedContact, override.sources)
            return true
        }
#endif

        do {
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

            guard let destinationContact = try? store.unifiedContact(
                withIdentifier: configuration.primaryContactId,
                keysToFetch: keysToFetch
            ) else {
                await MainActor.run {
                    errorMessage = "Failed to fetch destination contact"
                }
                return false
            }

            let sourceIds = configuration.sourceContactIds
            var sourceContacts: [CNContact] = []
            for sourceId in sourceIds {
                if let contact = try? store.unifiedContact(
                    withIdentifier: sourceId,
                    keysToFetch: keysToFetch
                ) {
                    sourceContacts.append(contact)
                }
            }

            let mergedContact = MergeEngine.mergedContact(
                configuration: configuration,
                destinationContact: destinationContact,
                sourceContacts: sourceContacts
            )

            let saveRequest = CNSaveRequest()
            saveRequest.update(mergedContact)
            for source in sourceContacts {
                saveRequest.delete(source.mutableCopy() as! CNMutableContact)
            }
            try store.execute(saveRequest)

            print("✅ Successfully merged \(sourceIds.count) contacts into \(configuration.primaryContactId)")

            await fetchAllContacts()
            signalDataMutation()
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to merge contacts: \(error.localizedDescription)"
            }
            print("❌ Merge error: \(error)")
            return false
        }
    }

    // MARK: - Quick Fix Helpers

    private func performContactMutation(
        contactId: String,
        mutation: @escaping (CNMutableContact) throws -> Void
    ) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    let contact = try self.store.unifiedContact(
                        withIdentifier: contactId,
                        keysToFetch: self.editableContactKeys
                    )

                    guard let mutable = contact.mutableCopy() as? CNMutableContact else {
                        continuation.resume(returning: false)
                        return
                    }

                    try mutation(mutable)

                    let saveRequest = CNSaveRequest()
                    saveRequest.update(mutable)
                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to update contact: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func addPhoneNumber(_ phoneNumber: String, label: String = CNLabelPhoneNumberMobile, to contactId: String) async -> Bool {
        let success = await performContactMutation(contactId: contactId) { contact in
            let labeledValue = CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: phoneNumber))
            contact.phoneNumbers.append(labeledValue)
        }

        if success {
            signalDataMutation()
        }
        return success
    }

    func addEmailAddress(_ emailAddress: String, label: String = CNLabelWork, to contactId: String) async -> Bool {
        let success = await performContactMutation(contactId: contactId) { contact in
            let labeledValue = CNLabeledValue(label: label, value: emailAddress as NSString)
            contact.emailAddresses.append(labeledValue)
        }

        if success {
            signalDataMutation()
        }
        return success
    }

    func removePhoneNumber(_ phoneNumber: String, from contactId: String) async -> Bool {
        let success = await performContactMutation(contactId: contactId) { contact in
            contact.phoneNumbers.removeAll { $0.value.stringValue == phoneNumber }
        }
        if success {
            signalDataMutation()
        }
        return success
    }

    func removeEmailAddress(_ emailAddress: String, from contactId: String) async -> Bool {
        let success = await performContactMutation(contactId: contactId) { contact in
            contact.emailAddresses.removeAll { $0.value as String == emailAddress }
        }
        if success {
            signalDataMutation()
        }
        return success
    }

    func updateFullName(_ contactId: String, fullName: String) async -> Bool {
        let components = parseNameComponents(fullName)
        let success = await performContactMutation(contactId: contactId) { contact in
            contact.givenName = components.given
            contact.familyName = components.family
        }
        if success {
            signalDataMutation()
        }
        return success
    }

    func fetchNameComponents(contactId: String) async -> (given: String, family: String)? {
        await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let keys: [CNKeyDescriptor] = [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor
                    ]
                    let contact = try self.store.unifiedContact(withIdentifier: contactId, keysToFetch: keys)
                    continuation.resume(returning: (contact.givenName, contact.familyName))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func parseNameComponents(_ fullName: String) -> (given: String, family: String) {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }
        let parts = trimmed.split(separator: " ")
        if parts.count == 1 {
            return (String(parts[0]), "")
        } else {
            let given = String(parts.first!)
            let family = parts.dropFirst().joined(separator: " ")
            return (given, family)
        }
    }

    func addContacts(_ contactIds: [String], toGroupNamed groupName: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }
        guard !contactIds.isEmpty else { return true }

        let result = await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    let group = try self.ensureGroup(named: groupName)
                    let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
                    let existingMembers = try self.store.unifiedContacts(
                        matching: predicate,
                        keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
                    )
                    let memberIds = Set(existingMembers.map { $0.identifier })
                    let mutableGroup = group.mutableCopy() as! CNMutableGroup
                    let saveRequest = CNSaveRequest()
                    var addedMember = false

                    for contactId in contactIds where !memberIds.contains(contactId) {
                        let contact = try self.store.unifiedContact(
                            withIdentifier: contactId,
                            keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
                        )
                        saveRequest.addMember(contact, to: mutableGroup)
                        addedMember = true
                    }

                    if addedMember {
                        try self.store.execute(saveRequest)
                    }

                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to update group: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
        }

        if result {
            signalDataMutation()
        }
        return result
    }

    func addContact(_ contactId: String, toGroupNamed groupName: String) async -> Bool {
        return await addContacts([contactId], toGroupNamed: groupName)
    }

    func archiveContact(_ contactId: String) async -> Bool {
        return await addContact(contactId, toGroupNamed: HealthIssueActionCatalog.archiveGroupName)
    }

    func archiveContacts(_ contactIds: [String]) async -> Bool {
        return await addContacts(contactIds, toGroupNamed: HealthIssueActionCatalog.archiveGroupName)
    }

    func removeContact(_ contactId: String, fromGroupNamed groupName: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    guard let group = try self.group(named: groupName) else {
                        continuation.resume(returning: false)
                        return
                    }

                    let contact = try self.store.unifiedContact(
                        withIdentifier: contactId,
                        keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
                    )

                    let mutableGroup = group.mutableCopy() as! CNMutableGroup
                    let saveRequest = CNSaveRequest()
                    saveRequest.removeMember(contact, from: mutableGroup)
                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to remove contact from group: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func ensureGroup(named groupName: String) throws -> CNGroup {
        let existingGroups = try store.groups(matching: nil)
        if let group = existingGroups.first(where: { $0.name == groupName }) {
            return group
        }

        let newGroup = CNMutableGroup()
        newGroup.name = groupName
        let saveRequest = CNSaveRequest()
        saveRequest.add(newGroup, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        let refreshedGroups = try store.groups(matching: nil)
        guard let created = refreshedGroups.first(where: { $0.name == groupName }) else {
            throw NSError(domain: "ContactsManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create group \(groupName)"])
        }
        return created
    }

    private func group(named groupName: String) throws -> CNGroup? {
        let existingGroups = try store.groups(matching: nil)
        return existingGroups.first(where: { $0.name == groupName })
    }

    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool = false, replaceExisting: Bool = false) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        // Use the dedicated queue instead of Task.detached
        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    let existingGroups = try self.store.groups(matching: nil)
                    if let existing = existingGroups.first(where: { $0.name == name }) {
                        if replaceExisting {
                            let deleteRequest = CNSaveRequest()
                            deleteRequest.delete(existing.mutableCopy() as! CNMutableGroup)
                            try self.store.execute(deleteRequest)
                        } else if !allowDuplicateNames {
                            Task { @MainActor in
                                self.errorMessage = "Group '\(name)' already exists"
                            }
                            continuation.resume(returning: false)
                            return
                        }
                    }

                    if !allowDuplicateNames {
                        // Duplicate check already handled above
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

    func deleteGroup(named groupName: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    guard let group = try self.group(named: groupName) else {
                        continuation.resume(returning: false)
                        return
                    }

                    guard let mutableGroup = group.mutableCopy() as? CNMutableGroup else {
                        continuation.resume(returning: false)
                        return
                    }

                    let saveRequest = CNSaveRequest()
                    saveRequest.delete(mutableGroup)
                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to delete group: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func renameGroup(_ group: CNGroup, to newName: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    let groups = try self.store.groups(matching: nil)
                    if groups.contains(where: { $0.name == newName }) {
                        Task { @MainActor in
                            self.errorMessage = "Group '\(newName)' already exists"
                        }
                        continuation.resume(returning: false)
                        return
                    }

                    guard let mutableGroup = group.mutableCopy() as? CNMutableGroup else {
                        continuation.resume(returning: false)
                        return
                    }

                    mutableGroup.name = newName
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(mutableGroup)
                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to rename group: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func renameGroup(named currentName: String, to newName: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    guard let group = try self.group(named: currentName),
                          let mutable = group.mutableCopy() as? CNMutableGroup else {
                        continuation.resume(returning: false)
                        return
                    }

                    mutable.name = newName
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(mutable)
                    try self.store.execute(saveRequest)
                    continuation.resume(returning: true)
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to rename group: \(error.localizedDescription)"
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

    func fetchContacts(forGroupNamed groupName: String) async -> [ContactSummary] {
        guard let targetGroup = await withCheckedContinuation({ (continuation: CheckedContinuation<CNGroup?, Never>) in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let group = try? self.group(named: groupName)
                continuation.resume(returning: group)
            }
        }) else {
            return []
        }

        return await fetchContactsForGroup(targetGroup)
    }

    func removeContacts(_ contactIds: [String], fromGroupNamed groupName: String) async -> Bool {
        guard !contactIds.isEmpty else { return true }
        var succeeded = true
        for contactId in contactIds {
            let result = await removeContact(contactId, fromGroupNamed: groupName)
            succeeded = succeeded && result
        }
        return succeeded
    }

    func duplicateGroupSnapshots(keepFirst: Bool = true) async -> [ManualGroupSnapshot] {
        let duplicates = await findDuplicateGroups()
        var snapshots: [ManualGroupSnapshot] = []
        for (_, groups) in duplicates {
            let groupsToDelete = keepFirst ? Array(groups.dropFirst()) : Array(groups.dropLast())
            for group in groupsToDelete {
                let contacts = await fetchContactsForGroup(group)
                let contactIds = contacts.map { $0.id }
                snapshots.append(ManualGroupSnapshot(name: group.name, contactIds: contactIds))
            }
        }
        return snapshots
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
                        // Extended contact information
                        CNContactNicknameKey as CNKeyDescriptor,
                        CNContactJobTitleKey as CNKeyDescriptor,
                        CNContactDepartmentNameKey as CNKeyDescriptor,
                        CNContactPostalAddressesKey as CNKeyDescriptor,
                        CNContactUrlAddressesKey as CNKeyDescriptor,
                        CNContactSocialProfilesKey as CNKeyDescriptor,
                        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                    ]

                    let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
                    self.refreshRecencyInfoFromHistory()

                    let contacts = try self.store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                    let summaries = contacts.map { contact -> ContactSummary in
                        let recency = self.contactRecencyInfo[contact.identifier]
                        return ContactSummary(from: contact, recencyInfo: recency)
                    }

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

    func createSafetySnapshot(tag: String) async -> URL? {
        guard authorizationStatus == .authorized else { return nil }

#if DEBUG
        if let override = ContactsManager.snapshotOverride {
            return await createSnapshotUsingOverride(override: override, tag: tag)
        }
#endif

        return await withCheckedContinuation { continuation in
            contactsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let keysToFetch: [CNKeyDescriptor] = [
                        CNContactVCardSerialization.descriptorForRequiredKeys()
                    ]

                    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                    var allContacts: [CNContact] = []

                    try self.store.enumerateContacts(with: request) { contact, _ in
                        allContacts.append(contact)
                    }

                    let vCardData = try CNContactVCardSerialization.data(with: allContacts)

                    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let snapshotsFolder = appSupportURL.appendingPathComponent("com.playablefuture.contactsorganizer/Snapshots", isDirectory: true)
                    try FileManager.default.createDirectory(at: snapshotsFolder, withIntermediateDirectories: true)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    let timestamp = dateFormatter.string(from: Date())
                    let sanitizedTag = sanitizeFilenameComponent(tag)
                    let filename = "\(sanitizedTag)_\(timestamp).vcf"
                    let fileURL = snapshotsFolder.appendingPathComponent(filename)

                    try vCardData.write(to: fileURL)
                    continuation.resume(returning: fileURL)
                } catch {
                    print("❌ Snapshot error: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func createBackup(saveToURL: URL? = nil) async -> (userBackup: URL?, appBackup: URL?) {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Not authorized to access contacts"
            }
            return (nil, nil)
        }

#if DEBUG
        if let override = ContactsManager.backupOverride {
            return await performBackupUsingOverride(
                contacts: override.contacts,
                userDirectory: override.userDirectory,
                appDirectory: override.appDirectory,
                saveToURL: saveToURL
            )
        }
#endif

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
                    let filename = makeBackupFilename()

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

#if DEBUG
    private func performBackupUsingOverride(
        contacts: [CNContact],
        userDirectory: URL,
        appDirectory: URL,
        saveToURL: URL?
    ) async -> (userBackup: URL?, appBackup: URL?) {
        return await withCheckedContinuation { continuation in
            contactsQueue.async {
                do {
                    let vCardData = try CNContactVCardSerialization.data(with: contacts)
                    let filename = self.makeBackupFilename()

                    let userFileURL: URL
                    if let saveToURL {
                        try FileManager.default.createDirectory(at: saveToURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        userFileURL = saveToURL
                    } else {
                        try FileManager.default.createDirectory(at: userDirectory, withIntermediateDirectories: true)
                        userFileURL = userDirectory.appendingPathComponent(filename)
                    }
                    try vCardData.write(to: userFileURL)

                    try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                    let appFileURL = appDirectory.appendingPathComponent(filename)
                    try vCardData.write(to: appFileURL)

                    continuation.resume(returning: (userFileURL, appFileURL))
                } catch {
                    print("❌ Backup override error: \(error)")
                    Task { @MainActor in
                        self.errorMessage = "Failed to create backup: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: (nil, nil))
                }
            }
        }
    }

    private func createSnapshotUsingOverride(override: SnapshotOverride, tag: String) async -> URL? {
        return await withCheckedContinuation { continuation in
            contactsQueue.async {
                do {
                    let vCardData = try CNContactVCardSerialization.data(with: override.contacts)
                    let sanitizedTag = self.sanitizeFilenameComponent(tag)
                    let filename = self.makeBackupFilename(prefix: sanitizedTag)
                    try FileManager.default.createDirectory(at: override.snapshotDirectory, withIntermediateDirectories: true)
                    let destination = override.snapshotDirectory.appendingPathComponent(filename)
                    try vCardData.write(to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    print("❌ Snapshot override error: \(error)")
                    Task { @MainActor in
                        self.errorMessage = "Failed to create snapshot: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
#endif

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func makeBackupFilename(prefix: String = "Contacts_Backup") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "\(prefix)_\(timestamp).vcf"
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

    nonisolated private static func evaluateCondition(_ matches: Bool, condition: CustomCriteria.Rule.Condition) -> Bool {
        switch condition {
        case .exists:
            return matches
        case .notExists:
            return !matches
        case .contains:
            return matches
        }
    }

    nonisolated private static func daysThreshold(from value: String?, defaultValue: Int) -> Int {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              let parsed = Int(value),
              parsed > 0 else {
            return defaultValue
        }
        return parsed
    }

    nonisolated private static func cutoffDate(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date.distantPast
    }

    nonisolated private static func contactDetailScore(_ contact: ContactSummary) -> Int {
        var dataPoints = 0
        if !contact.phoneNumbers.isEmpty { dataPoints += 1 }
        if !contact.emailAddresses.isEmpty { dataPoints += 1 }
        if contact.organization != nil { dataPoints += 1 }
        if contact.jobTitle != nil { dataPoints += 1 }
        if !contact.postalAddresses.isEmpty { dataPoints += 1 }
        if !contact.socialProfiles.isEmpty { dataPoints += 1 }
        if !contact.urlAddresses.isEmpty { dataPoints += 1 }
        if contact.birthday != nil { dataPoints += 1 }
        return dataPoints
    }

    nonisolated private static func matchesRule(contact: ContactSummary, rule: CustomCriteria.Rule) -> Bool {
        switch rule.field {
        case .hasPhone:
            return evaluateCondition(!contact.phoneNumbers.isEmpty, condition: rule.condition)

        case .hasEmail:
            return evaluateCondition(!contact.emailAddresses.isEmpty, condition: rule.condition)

        case .hasOrganization:
            let hasOrg = contact.organization != nil && !contact.organization!.isEmpty
            return evaluateCondition(hasOrg, condition: rule.condition)

        case .hasPhoto:
            return evaluateCondition(contact.hasProfileImage, condition: rule.condition)

        case .organizationContains:
            guard let value = rule.value, !value.isEmpty else { return false }
            let contains = (contact.organization ?? "").localizedCaseInsensitiveContains(value)
            return evaluateCondition(contains, condition: rule.condition)

        case .nameContains:
            guard let value = rule.value else { return false }
            // Check if the value matches at word boundaries
            let name = contact.fullName.lowercased()
            let searchValue = value.lowercased()

            // Split name into words and check if any word matches
            let words = name.components(separatedBy: .whitespaces)
            let matches = words.contains { word in
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
            return evaluateCondition(matches, condition: rule.condition)

        // Phase 1: Quick wins using existing data
        case .phoneOnly:
            return evaluateCondition(!contact.phoneNumbers.isEmpty && contact.emailAddresses.isEmpty, condition: rule.condition)

        case .emailOnly:
            return evaluateCondition(!contact.emailAddresses.isEmpty && contact.phoneNumbers.isEmpty, condition: rule.condition)

        case .noCriticalInfo:
            return evaluateCondition(contact.phoneNumbers.isEmpty && contact.emailAddresses.isEmpty, condition: rule.condition)

        case .multiplePhones:
            return evaluateCondition(contact.phoneNumbers.count >= 2, condition: rule.condition)

        case .multipleEmails:
            return evaluateCondition(contact.emailAddresses.count >= 2, condition: rule.condition)

        // Phase 2: Time-based criteria
        case .recentlyAdded:
            let threshold = daysThreshold(from: rule.value, defaultValue: 30)
            guard let createdDate = contact.creationDate ?? contact.modificationDate else { return false }
            let matches = createdDate >= cutoffDate(daysAgo: threshold)
            return evaluateCondition(matches, condition: rule.condition)

        case .recentlyModified:
            let threshold = daysThreshold(from: rule.value, defaultValue: 30)
            guard let modifiedDate = contact.modificationDate ?? contact.creationDate else { return false }
            let matches = modifiedDate >= cutoffDate(daysAgo: threshold)
            return evaluateCondition(matches, condition: rule.condition)

        case .staleContact:
            let threshold = daysThreshold(from: rule.value, defaultValue: 365)
            guard let lastActivity = contact.modificationDate ?? contact.creationDate else { return false }
            let matches = lastActivity < cutoffDate(daysAgo: threshold)
            return evaluateCondition(matches, condition: rule.condition)

        case .birthdayThisMonth:
            guard let birthday = contact.birthday else { return false }
            let calendar = Calendar.current
            let now = Date()
            let birthdayMonth = calendar.component(.month, from: birthday)
            let currentMonth = calendar.component(.month, from: now)
            let matches = birthdayMonth == currentMonth
            return evaluateCondition(matches, condition: rule.condition)

        case .birthdayThisWeek:
            guard let birthday = contact.birthday else { return false }
            let calendar = Calendar.current
            let now = Date()

            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return false
            }

            let birthdayDay = calendar.component(.day, from: birthday)
            let birthdayMonth = calendar.component(.month, from: birthday)

            var birthdayComponents = DateComponents()
            birthdayComponents.month = birthdayMonth
            birthdayComponents.day = birthdayDay
            birthdayComponents.year = calendar.component(.year, from: now)

            guard let thisYearBirthday = calendar.date(from: birthdayComponents) else {
                return false
            }

            let matches = (thisYearBirthday >= weekInterval.start) && (thisYearBirthday < weekInterval.end)
            return evaluateCondition(matches, condition: rule.condition)

        // Phase 3: Social Media & Digital Presence
        case .hasSocialProfile:
            return evaluateCondition(!contact.socialProfiles.isEmpty, condition: rule.condition)

        case .hasLinkedIn:
            let hasLinkedIn = contact.socialProfiles.contains { $0.service.lowercased().contains("linkedin") }
            return evaluateCondition(hasLinkedIn, condition: rule.condition)

        case .hasTwitter:
            let hasTwitter = contact.socialProfiles.contains {
                let service = $0.service.lowercased()
                return service.contains("twitter") || service.contains("x")
            }
            return evaluateCondition(hasTwitter, condition: rule.condition)

        case .multipleSocialProfiles:
            return evaluateCondition(contact.socialProfiles.count >= 2, condition: rule.condition)

        case .hasWebsite:
            return evaluateCondition(!contact.urlAddresses.isEmpty, condition: rule.condition)

        case .hasInstantMessaging:
            return evaluateCondition(!contact.instantMessageAddresses.isEmpty, condition: rule.condition)

        case .digitallyConnected:
            // Has at least 2 of: social profiles, instant messaging, or website
            let hasCategories = [
                !contact.socialProfiles.isEmpty,
                !contact.instantMessageAddresses.isEmpty,
                !contact.urlAddresses.isEmpty
            ].filter { $0 }.count
            return evaluateCondition(hasCategories >= 2, condition: rule.condition)

        // Phase 3: Geographic & Address
        case .hasAddress:
            return evaluateCondition(!contact.postalAddresses.isEmpty, condition: rule.condition)

        case .missingAddress:
            return evaluateCondition(contact.postalAddresses.isEmpty, condition: rule.condition)

        case .multipleAddresses:
            return evaluateCondition(contact.postalAddresses.count >= 2, condition: rule.condition)

        case .cityMatches:
            guard let value = rule.value, !value.isEmpty else { return false }
            let matches = contact.postalAddresses.contains { $0.localizedCaseInsensitiveContains(value) }
            return evaluateCondition(matches, condition: rule.condition)

        // Phase 3: Professional Information
        case .hasJobTitle:
            let hasTitle = contact.jobTitle != nil && !contact.jobTitle!.isEmpty
            return evaluateCondition(hasTitle, condition: rule.condition)

        case .hasDepartment:
            let hasDept = contact.departmentName != nil && !contact.departmentName!.isEmpty
            return evaluateCondition(hasDept, condition: rule.condition)

        case .jobTitleContains:
            guard let jobTitle = contact.jobTitle, let value = rule.value, !value.isEmpty else { return false }
            let matches = jobTitle.localizedCaseInsensitiveContains(value)
            return evaluateCondition(matches, condition: rule.condition)

        case .professionalContact:
            // Has organization, job title, and email
            let hasOrg = contact.organization != nil && !contact.organization!.isEmpty
            let hasTitle = contact.jobTitle != nil && !contact.jobTitle!.isEmpty
            let hasEmail = !contact.emailAddresses.isEmpty
            return evaluateCondition(hasOrg && hasTitle && hasEmail, condition: rule.condition)

        case .careerNetwork:
            // Has job title and LinkedIn
            let hasTitle = contact.jobTitle != nil && !contact.jobTitle!.isEmpty
            let hasLinkedIn = contact.socialProfiles.contains { $0.service.lowercased().contains("linkedin") }
            return evaluateCondition(hasTitle && hasLinkedIn, condition: rule.condition)

        // Phase 3: Nickname & Detail Level
        case .hasNickname:
            let hasNick = contact.nickname != nil && !contact.nickname!.isEmpty
            return evaluateCondition(hasNick, condition: rule.condition)

        case .nicknameContains:
            guard let nickname = contact.nickname, let value = rule.value, !value.isEmpty else { return false }
            let matches = nickname.localizedCaseInsensitiveContains(value)
            return evaluateCondition(matches, condition: rule.condition)

        case .highDetailContact:
            let matches = contactDetailScore(contact) >= 5
            return evaluateCondition(matches, condition: rule.condition)

        case .basicContact:
            let score = contactDetailScore(contact)
            let matches = score <= 2 && score >= 1
            return evaluateCondition(matches, condition: rule.condition)

        case .businessContact:
            // Has organization, job title, and website
            let hasOrg = contact.organization != nil && !contact.organization!.isEmpty
            let hasTitle = contact.jobTitle != nil && !contact.jobTitle!.isEmpty
            let hasWebsite = !contact.urlAddresses.isEmpty
            return evaluateCondition(hasOrg && hasTitle && hasWebsite, condition: rule.condition)

        case .personalContact:
            // No organization or job title
            let hasOrg = contact.organization != nil && !contact.organization!.isEmpty
            let hasTitle = contact.jobTitle != nil && !contact.jobTitle!.isEmpty
            return evaluateCondition(!hasOrg && !hasTitle, condition: rule.condition)
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
                    CustomCriteria.Rule(field: .recentlyAdded, condition: .exists, value: "30")
                ]))
            ),
            SmartGroupDefinition(
                name: "Recently Modified (Last 30 Days)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .recentlyModified, condition: .exists, value: "30")
                ]))
            ),
            SmartGroupDefinition(
                name: "Stale Contacts (1+ Year)",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .staleContact, condition: .exists, value: "365")
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
            ),

            // Phase 3: Social Media & Digital Presence
            SmartGroupDefinition(
                name: "Connected on LinkedIn",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasLinkedIn, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Connected on Twitter/X",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasTwitter, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Social Media Savvy",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .multipleSocialProfiles, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Missing Social Media",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasSocialProfile, condition: .notExists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Has Instant Messaging",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasInstantMessaging, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Digitally Connected",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .digitallyConnected, condition: .exists)
                ]))
            ),

            // Phase 3: Geographic & Address
            SmartGroupDefinition(
                name: "Has Address",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasAddress, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Missing Address",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .missingAddress, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Multiple Addresses",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .multipleAddresses, condition: .exists)
                ]))
            ),

            // Phase 3: Professional Information
            SmartGroupDefinition(
                name: "Has Job Title",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasJobTitle, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Has Department",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasDepartment, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Professional Network",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .professionalContact, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Career Network",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .careerNetwork, condition: .exists)
                ]))
            ),

            // Phase 3: Digital Presence & Websites
            SmartGroupDefinition(
                name: "Has Website",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasWebsite, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Business Contacts",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .businessContact, condition: .exists)
                ]))
            ),

            // Phase 3: Nickname & Detail Level
            SmartGroupDefinition(
                name: "Has Nickname",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .hasNickname, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Highly Detailed Contacts",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .highDetailContact, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Basic Contacts Only",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .basicContact, condition: .exists)
                ]))
            ),
            SmartGroupDefinition(
                name: "Personal Contacts",
                groupingType: .custom(CustomCriteria(rules: [
                    CustomCriteria.Rule(field: .personalContact, condition: .exists)
                ]))
            ),

            // Phase 3: Geographic grouping (enhanced existing)
            SmartGroupDefinition(
                name: "By City",
                groupingType: .geographic(.byCity)
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

// MARK: - Undo Manager

@MainActor
final class ContactsUndoManager: ObservableObject {
    struct OperationRecord: Identifiable {
        let id = UUID()
        let description: String
        let undoAction: () async -> Bool
        let redoAction: () async -> Bool
    }

    @Published private(set) var undoStack: [OperationRecord] = []
    @Published private(set) var redoStack: [OperationRecord] = []
    @Published private(set) var isPerforming = false

    var canUndo: Bool { !undoStack.isEmpty && !isPerforming }
    var canRedo: Bool { !redoStack.isEmpty && !isPerforming }
    var undoDescription: String? { undoStack.last?.description }
    var redoDescription: String? { redoStack.last?.description }

    func register(description: String, undo: @escaping () async -> Bool, redo: @escaping () async -> Bool) {
        let record = OperationRecord(description: description, undoAction: undo, redoAction: redo)
        undoStack.append(record)
        redoStack.removeAll()
    }

    func undo() {
        guard !isPerforming, let record = undoStack.popLast() else { return }
        isPerforming = true
        Task {
            let success = await record.undoAction()
            await MainActor.run {
                if success {
                    redoStack.append(record)
                } else {
                    undoStack.append(record)
                }
                isPerforming = false
            }
        }
    }

    func redo() {
        guard !isPerforming, let record = redoStack.popLast() else { return }
        isPerforming = true
        Task {
            let success = await record.redoAction()
            await MainActor.run {
                if success {
                    undoStack.append(record)
                } else {
                    redoStack.append(record)
                }
                isPerforming = false
            }
        }
    }

    /// Blocks until the current undo/redo operation completes.
    func waitForIdle() async {
        while isPerforming {
            await Task.yield()
        }
    }
}

enum UndoEffect {
    case addedPhone(contactId: String, value: String)
    case addedEmail(contactId: String, value: String)
    case addedToGroup(contactId: String, groupName: String)
    case archivedContact(contactId: String)
    case updatedName(contactId: String, previousGiven: String, previousFamily: String, newValue: String)
}

extension ContactsUndoManager {
    func register(effect: UndoEffect, actionTitle: String, contactsManager: ContactActionPerforming) {
        switch effect {
        case .addedPhone(let contactId, let value):
            register(description: "Undo \(actionTitle)") {
                await contactsManager.removePhoneNumber(value, from: contactId)
            } redo: {
                await contactsManager.addPhoneNumber(value, label: CNLabelPhoneNumberMobile, to: contactId)
            }

        case .addedEmail(let contactId, let value):
            register(description: "Undo \(actionTitle)") {
                await contactsManager.removeEmailAddress(value, from: contactId)
            } redo: {
                await contactsManager.addEmailAddress(value, label: CNLabelWork, to: contactId)
            }

        case .addedToGroup(let contactId, let groupName):
            register(description: "Undo \(actionTitle)") {
                await contactsManager.removeContact(contactId, fromGroupNamed: groupName)
            } redo: {
                await contactsManager.addContact(contactId, toGroupNamed: groupName)
            }

        case .archivedContact(let contactId):
            register(description: "Undo \(actionTitle)") {
                await contactsManager.removeContact(contactId, fromGroupNamed: HealthIssueActionCatalog.archiveGroupName)
            } redo: {
                await contactsManager.archiveContact(contactId)
            }

        case .updatedName(let contactId, let previousGiven, let previousFamily, let newValue):
            register(description: "Undo \(actionTitle)") {
                await contactsManager.updateFullName(contactId, fullName: "\(previousGiven) \(previousFamily)".trimmingCharacters(in: .whitespaces))
            } redo: {
                await contactsManager.updateFullName(contactId, fullName: newValue)
            }
        }
    }
}

extension ContactsManager {
    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool) async -> Bool {
        await createGroup(
            name: name,
            contactIds: contactIds,
            allowDuplicateNames: allowDuplicateNames,
            replaceExisting: false
        )
    }
}

extension ContactsManager: SmartGroupContactPerforming {}
extension ContactsManager: ManualGroupContactPerforming {}

private extension ContactsManager {
    func loadRecencyState() {
        let defaults = UserDefaults.standard
        if let cachedData = defaults.data(forKey: recencyCacheDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: ContactRecencyInfo].self, from: cachedData) {
            contactRecencyInfo = decoded
        }
        changeHistoryAnchor = defaults.data(forKey: changeHistoryTokenDefaultsKey)
    }

    func persistRecencyState(recencyChanged: Bool) {
        let defaults = UserDefaults.standard
        if recencyChanged, let cacheData = try? JSONEncoder().encode(contactRecencyInfo) {
            defaults.set(cacheData, forKey: recencyCacheDefaultsKey)
        }
        defaults.set(changeHistoryAnchor, forKey: changeHistoryTokenDefaultsKey)
    }

    func refreshRecencyInfoFromHistory(retryOnReset: Bool = true) {
        guard authorizationStatus == .authorized else { return }

        var recencyChanged = false
        let request = CNChangeHistoryFetchRequest()
        request.startingToken = changeHistoryAnchor
        request.shouldUnifyResults = true

        var currentToken: NSData?
        let events: [CNChangeHistoryEvent]
        do {
            events = try changeHistoryWrapper.fetchChangeHistory(
                with: request,
                currentHistoryToken: &currentToken
            ) ?? []
        } catch let nsError as NSError {
            handleChangeHistoryError(nsError, retryOnReset: retryOnReset)
            return
        }

        for event in events {
            let now = Date()
            switch event {
            case let addEvent as CNChangeHistoryAddContactEvent:
                contactRecencyInfo[addEvent.contact.identifier] = ContactRecencyInfo(
                    createdAt: now,
                    modifiedAt: now
                )
                recencyChanged = true
            case let updateEvent as CNChangeHistoryUpdateContactEvent:
                let identifier = updateEvent.contact.identifier
                if var info = contactRecencyInfo[identifier] {
                    info.updateModified(date: now)
                    contactRecencyInfo[identifier] = info
                } else {
                    contactRecencyInfo[identifier] = ContactRecencyInfo(createdAt: now, modifiedAt: now)
                }
                recencyChanged = true
            case let deleteEvent as CNChangeHistoryDeleteContactEvent:
                if contactRecencyInfo.removeValue(forKey: deleteEvent.contactIdentifier) != nil {
                    recencyChanged = true
                }
            case _ as CNChangeHistoryDropEverythingEvent:
                contactRecencyInfo.removeAll()
                changeHistoryAnchor = nil
                recencyChanged = true
            default:
                break
            }
        }

        if let newToken = currentToken as Data? {
            changeHistoryAnchor = newToken
        } else {
            changeHistoryAnchor = store.currentHistoryToken
        }

        persistRecencyState(recencyChanged: recencyChanged)
    }

    private func handleChangeHistoryError(_ error: NSError, retryOnReset: Bool) {
        if error.domain == CNErrorDomain,
           let code = CNError.Code(rawValue: error.code),
           code == .changeHistoryExpired,
           retryOnReset {
            contactRecencyInfo.removeAll()
            changeHistoryAnchor = nil
            persistRecencyState(recencyChanged: true)
            refreshRecencyInfoFromHistory(retryOnReset: false)
        } else {
            print("❌ Change history fetch failed: \(error)")
        }
    }
}
