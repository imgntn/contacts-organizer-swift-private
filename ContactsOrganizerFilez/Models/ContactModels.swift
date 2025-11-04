//
//  ContactModels.swift
//  Contacts Organizer
//
//  Data models for contact management
//

import Foundation
import Contacts

// MARK: - Contact Summary
struct ContactSummary: Identifiable, Hashable {
    let id: String
    let fullName: String
    let organization: String?
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let hasProfileImage: Bool
    let creationDate: Date?
    let modificationDate: Date?

    init(from contact: CNContact) {
        self.id = contact.identifier
        self.fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? "No Name"
        self.organization = contact.organizationName.isEmpty ? nil : contact.organizationName
        self.phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        self.emailAddresses = contact.emailAddresses.map { $0.value as String }
        self.hasProfileImage = contact.imageDataAvailable
        self.creationDate = contact.dates.first?.value as? Date
        self.modificationDate = contact.dates.last?.value as? Date
    }
}

// MARK: - Duplicate Group
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let contacts: [ContactSummary]
    let matchType: MatchType
    let confidence: Double

    enum MatchType {
        case exactName
        case similarName
        case samePhone
        case sameEmail
        case multipleMatches
    }

    var primaryContact: ContactSummary {
        // Choose the most complete contact as primary
        contacts.max(by: { lhs, rhs in
            let lhsScore = lhs.phoneNumbers.count + lhs.emailAddresses.count + (lhs.organization != nil ? 1 : 0)
            let rhsScore = rhs.phoneNumbers.count + rhs.emailAddresses.count + (rhs.organization != nil ? 1 : 0)
            return lhsScore < rhsScore
        }) ?? contacts[0]
    }
}

// MARK: - Data Quality Issue
struct DataQualityIssue: Identifiable {
    let id = UUID()
    let contactId: String
    let contactName: String
    let issueType: IssueType
    let description: String
    let severity: Severity

    enum IssueType {
        case missingName
        case missingPhone
        case missingEmail
        case noContactInfo
        case invalidFormat
        case incompleteData
    }

    enum Severity {
        case high
        case medium
        case low

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "yellow"
            }
        }
    }
}

// MARK: - Contact Group
struct ContactGroup: Identifiable {
    let id = UUID()
    let name: String
    let contacts: [ContactSummary]
    let groupType: GroupType

    enum GroupType {
        case geographic
        case organizational
        case custom
    }
}

// MARK: - Statistics
struct ContactStatistics {
    let totalContacts: Int
    let contactsWithPhone: Int
    let contactsWithEmail: Int
    let contactsWithBoth: Int
    let contactsWithOrganization: Int
    let contactsWithPhoto: Int
    let duplicateGroups: Int
    let dataQualityIssues: Int

    var dataQualityScore: Double {
        guard totalContacts > 0 else { return 0 }
        let completeContacts = Double(contactsWithBoth)
        return (completeContacts / Double(totalContacts)) * 100
    }
}
