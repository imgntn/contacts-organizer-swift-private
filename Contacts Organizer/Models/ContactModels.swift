//
//  ContactModels.swift
//  Contacts Organizer
//
//  Data models for contact management
//

import Foundation
import Contacts

// MARK: - Contact Summary
struct ContactSummary: Identifiable, Hashable, Sendable {
    let id: String
    let fullName: String
    let organization: String?
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let hasProfileImage: Bool
    let creationDate: Date?
    let modificationDate: Date?
    let birthday: Date?

    init(from contact: CNContact) {
        self.id = contact.identifier
        self.fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? "No Name"
        self.organization = contact.organizationName.isEmpty ? nil : contact.organizationName
        self.phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        self.emailAddresses = contact.emailAddresses.map { $0.value as String }
        self.hasProfileImage = contact.imageDataAvailable
        self.creationDate = contact.dates.first?.value as? Date
        self.modificationDate = contact.dates.last?.value as? Date
        self.birthday = contact.birthday?.date
    }

    // Initializer for testing
    init(id: String, fullName: String, organization: String?, phoneNumbers: [String], emailAddresses: [String], hasProfileImage: Bool, creationDate: Date?, modificationDate: Date?, birthday: Date? = nil) {
        self.id = id
        self.fullName = fullName
        self.organization = organization
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.hasProfileImage = hasProfileImage
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.birthday = birthday
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
struct DataQualityIssue: Identifiable, Sendable {
    let id = UUID()
    let contactId: String
    let contactName: String
    let issueType: IssueType
    let description: String
    let severity: Severity

    enum IssueType: Sendable {
        case missingName
        case missingPhone
        case missingEmail
        case noContactInfo
        case invalidFormat
        case incompleteData
    }

    enum Severity: Int, Sendable {
        case high = 0
        case medium = 1
        case low = 2

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "yellow"
            }
        }
    }
}

// MARK: - Equatable Conformance
extension DataQualityIssue.IssueType: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.missingName, .missingName),
             (.missingPhone, .missingPhone),
             (.missingEmail, .missingEmail),
             (.noContactInfo, .noContactInfo),
             (.invalidFormat, .invalidFormat),
             (.incompleteData, .incompleteData):
            return true
        default:
            return false
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
    let highPriorityIssues: Int
    let mediumPriorityIssues: Int
    let lowPriorityIssues: Int

    var dataQualityScore: Double {
        guard totalContacts > 0 else { return 100.0 }

        // Calculate quality score based on issue severity:
        // - High priority issues: -10 points each (critical problems)
        // - Medium priority issues: -3 points each (significant problems)
        // - Low priority issues: -0.5 points each (minor issues, max 5% impact)

        let highPenalty = Double(highPriorityIssues) * 10.0
        let mediumPenalty = Double(mediumPriorityIssues) * 3.0
        let lowPenalty = min(Double(lowPriorityIssues) * 0.5, 5.0) // Cap low priority at 5%

        let totalPenalty = highPenalty + mediumPenalty + lowPenalty

        return max(0, 100.0 - totalPenalty)
    }
}

// MARK: - Smart Group Models

struct SmartGroupDefinition: Identifiable, Codable {
    let id: UUID
    var name: String
    var groupingType: GroupingType
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, groupingType: GroupingType, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.groupingType = groupingType
        self.isEnabled = isEnabled
    }

    enum GroupingType: Codable {
        case geographic(GeographicCriteria)
        case organization
        case custom(CustomCriteria)
    }
}

enum GeographicCriteria: Codable {
    case byCity
    case byState
    case byCountry

    var displayName: String {
        switch self {
        case .byCity: return "By City"
        case .byState: return "By State/Province"
        case .byCountry: return "By Country"
        }
    }
}

struct CustomCriteria: Codable {
    var rules: [Rule]

    struct Rule: Codable, Identifiable {
        let id: UUID
        var field: Field
        var condition: Condition
        var value: String?

        init(id: UUID = UUID(), field: Field, condition: Condition, value: String? = nil) {
            self.id = id
            self.field = field
            self.condition = condition
            self.value = value
        }

        enum Field: String, Codable, CaseIterable {
            case hasPhone = "Has Phone"
            case hasEmail = "Has Email"
            case hasOrganization = "Has Organization"
            case hasPhoto = "Has Photo"
            case organizationContains = "Organization Contains"
            case nameContains = "Name Contains"
            // Phase 1: Quick wins using existing data
            case phoneOnly = "Phone Only (No Email)"
            case emailOnly = "Email Only (No Phone)"
            case noCriticalInfo = "No Critical Info"
            case multiplePhones = "Multiple Phones"
            case multipleEmails = "Multiple Emails"
            // Phase 2: Time-based criteria
            case recentlyAdded = "Recently Added"
            case recentlyModified = "Recently Modified"
            case staleContact = "Stale Contact"
            case birthdayThisMonth = "Birthday This Month"
            case birthdayThisWeek = "Birthday This Week"
        }

        enum Condition: String, Codable {
            case exists = "Exists"
            case notExists = "Does Not Exist"
            case contains = "Contains"
        }
    }
}

struct SmartGroupResult: Identifiable {
    let id = UUID()
    let groupName: String
    let contacts: [ContactSummary]
    let criteria: SmartGroupDefinition.GroupingType
}
