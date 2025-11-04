//
//  ContactsManager.swift
//  Contacts Organizer
//
//  Main service for managing contacts via CNContactStore
//

import Foundation
import Contacts
import SwiftUI

class ContactsManager: ObservableObject {
    static let shared = ContactsManager()

    private let store = CNContactStore()

    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var contacts: [ContactSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statistics: ContactStatistics?

    private init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func updateAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return granted
        } catch {
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

            try store.enumerateContacts(with: request) { contact, _ in
                fetchedContacts.append(ContactSummary(from: contact))
            }

            let stats = calculateStatistics(from: fetchedContacts)

            await MainActor.run {
                self.contacts = fetchedContacts
                self.statistics = stats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch contacts: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Statistics

    private func calculateStatistics(from contacts: [ContactSummary]) -> ContactStatistics {
        let totalContacts = contacts.count
        let contactsWithPhone = contacts.filter { !$0.phoneNumbers.isEmpty }.count
        let contactsWithEmail = contacts.filter { !$0.emailAddresses.isEmpty }.count
        let contactsWithBoth = contacts.filter { !$0.phoneNumbers.isEmpty && !$0.emailAddresses.isEmpty }.count
        let contactsWithOrg = contacts.filter { $0.organization != nil }.count
        let contactsWithPhoto = contacts.filter { $0.hasProfileImage }.count

        return ContactStatistics(
            totalContacts: totalContacts,
            contactsWithPhone: contactsWithPhone,
            contactsWithEmail: contactsWithEmail,
            contactsWithBoth: contactsWithBoth,
            contactsWithOrganization: contactsWithOrg,
            contactsWithPhoto: contactsWithPhoto,
            duplicateGroups: 0, // Will be calculated by duplicate detector
            dataQualityIssues: 0 // Will be calculated by data quality analyzer
        )
    }

    // MARK: - Contact Operations

    func mergeContacts(sourceIds: [String], destinationId: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }

        do {
            // Fetch all contacts to merge
            let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            var contactsToMerge: [CNContact] = []

            for contactId in sourceIds + [destinationId] {
                if let contact = try? store.unifiedContact(withIdentifier: contactId, keysToFetch: keysToFetch) {
                    contactsToMerge.append(contact)
                }
            }

            // Create save request
            let saveRequest = CNSaveRequest()

            // In a real implementation, you would:
            // 1. Fetch full details of all contacts
            // 2. Merge data intelligently (combine phone numbers, emails, etc.)
            // 3. Update destination contact with merged data
            // 4. Delete source contacts
            // For now, this is a placeholder

            try store.execute(saveRequest)

            // Refresh contacts after merge
            await fetchAllContacts()

            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to merge contacts: \(error.localizedDescription)"
            }
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

    // MARK: - Utility

    func resetError() {
        errorMessage = nil
    }
}
