//
//  ContactModels.swift
//  Contacts Organizer
//
//  Data models for contact management
//

import Foundation
import Contacts

// MARK: - Social Profile
struct SocialProfile: Identifiable, Hashable, Sendable, Codable {
    var id = UUID()
    let service: String  // "Twitter", "LinkedIn", "Facebook", etc.
    let username: String
    let url: String?
}

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

    // Extended contact information
    let nickname: String?
    let jobTitle: String?
    let departmentName: String?
    let postalAddresses: [String]        // City names extracted from addresses
    let urlAddresses: [String]           // Website URLs
    let socialProfiles: [SocialProfile]  // Social media profiles
    let instantMessageAddresses: [String] // IM service handles

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

        // Extended contact information
        self.nickname = contact.nickname.isEmpty ? nil : contact.nickname
        self.jobTitle = contact.jobTitle.isEmpty ? nil : contact.jobTitle
        self.departmentName = contact.departmentName.isEmpty ? nil : contact.departmentName

        // Extract city names from postal addresses
        self.postalAddresses = contact.postalAddresses.compactMap { labeledValue in
            let address = labeledValue.value
            return address.city.isEmpty ? nil : address.city
        }

        // Extract URLs
        self.urlAddresses = contact.urlAddresses.map { $0.value as String }

        // Extract social profiles
        self.socialProfiles = contact.socialProfiles.compactMap { labeledValue in
            let profile = labeledValue.value
            guard !profile.service.isEmpty,
                  !profile.username.isEmpty else { return nil }
            return SocialProfile(
                service: profile.service,
                username: profile.username,
                url: profile.urlString
            )
        }

        // Extract instant messaging addresses
        self.instantMessageAddresses = contact.instantMessageAddresses.compactMap { labeledValue in
            let imAddress = labeledValue.value
            return imAddress.username.isEmpty ? nil : "\(imAddress.service): \(imAddress.username)"
        }

        // DEBUG: Log contact data extraction for validation debugging
        if !phoneNumbers.isEmpty || !emailAddresses.isEmpty {
            print("📞 DEBUG ContactSummary - Contact: \(fullName) (\(id))")
            print("   📱 Raw CNContact phones count: \(contact.phoneNumbers.count)")
            print("   📧 Raw CNContact emails count: \(contact.emailAddresses.count)")
            print("   📱 Extracted phoneNumbers: \(phoneNumbers)")
            print("   📧 Extracted emailAddresses: \(emailAddresses)")

            // Check for empty strings
            let emptyPhones = phoneNumbers.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            let emptyEmails = emailAddresses.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !emptyPhones.isEmpty {
                print("   ⚠️  Found \(emptyPhones.count) empty phone number(s)")
            }
            if !emptyEmails.isEmpty {
                print("   ⚠️  Found \(emptyEmails.count) empty email address(es)")
            }
        }
    }

    // Initializer for testing
    init(
        id: String,
        fullName: String,
        organization: String?,
        phoneNumbers: [String],
        emailAddresses: [String],
        hasProfileImage: Bool,
        creationDate: Date?,
        modificationDate: Date?,
        birthday: Date? = nil,
        nickname: String? = nil,
        jobTitle: String? = nil,
        departmentName: String? = nil,
        postalAddresses: [String] = [],
        urlAddresses: [String] = [],
        socialProfiles: [SocialProfile] = [],
        instantMessageAddresses: [String] = []
    ) {
        self.id = id
        self.fullName = fullName
        self.organization = organization
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.hasProfileImage = hasProfileImage
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.birthday = birthday
        self.nickname = nickname
        self.jobTitle = jobTitle
        self.departmentName = departmentName
        self.postalAddresses = postalAddresses
        self.urlAddresses = urlAddresses
        self.socialProfiles = socialProfiles
        self.instantMessageAddresses = instantMessageAddresses
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
        case suggestion
    }

    enum Severity: Int, Sendable {
        case high = 0
        case medium = 1
        case low = 2
        case suggestion = 3

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "yellow"
            case .suggestion: return "blue"
            }
        }
    }
}

// MARK: - Equatable Conformance
extension DataQualityIssue: Equatable {
    static func == (lhs: DataQualityIssue, rhs: DataQualityIssue) -> Bool {
        lhs.id == rhs.id
    }
}

extension DataQualityIssue.IssueType: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.missingName, .missingName),
             (.missingPhone, .missingPhone),
             (.missingEmail, .missingEmail),
             (.noContactInfo, .noContactInfo),
             (.invalidFormat, .invalidFormat),
             (.incompleteData, .incompleteData),
             (.suggestion, .suggestion):
            return true
        default:
            return false
        }
    }
}

// MARK: - Merge Planning

struct MergeValueOption: Identifiable, Hashable {
    let id: String
    let value: String
    let owners: [ContactSummary]

    init(value: String, owners: [ContactSummary]) {
        self.id = value.isEmpty ? "__empty__" : value
        self.value = value
        self.owners = owners
    }

    var displayValue: String {
        value.isEmpty ? "Missing value" : value
    }

    var ownersDescription: String {
        owners.map { $0.fullName }.joined(separator: ", ")
    }
}

struct MergePlan: Equatable {
    var preferredNameContactId: String
    var preferredOrganizationContactId: String?
    var preferredPhotoContactId: String?
    var selectedPhoneNumbers: Set<String>
    var selectedEmailAddresses: Set<String>

    static func initial(for group: DuplicateGroup) -> MergePlan {
        MergePlan(
            preferredNameContactId: group.primaryContact.id,
            preferredOrganizationContactId: group.primaryContact.id,
            preferredPhotoContactId: group.contacts.first(where: { $0.hasProfileImage })?.id,
            selectedPhoneNumbers: Set(group.contacts.flatMap { $0.phoneNumbers }),
            selectedEmailAddresses: Set(group.contacts.flatMap { $0.emailAddresses })
        )
    }
}

struct MergeConfiguration {
    let primaryContactId: String
    let mergingContactIds: [String]
    var preferredNameSourceId: String?
    var preferredOrganizationSourceId: String?
    var preferredPhotoSourceId: String?
    var includedPhoneNumbers: Set<String>?
    var includedEmailAddresses: Set<String>?

    var sourceContactIds: [String] {
        mergingContactIds.filter { $0 != primaryContactId }
    }
}

enum MergePlanBuilder {
    static func uniqueValues(
        for contacts: [ContactSummary],
        keyPath: KeyPath<ContactSummary, [String]>
    ) -> [MergeValueOption] {
        var mapping: [String: [ContactSummary]] = [:]
        for contact in contacts {
            for value in contact[keyPath: keyPath] {
                mapping[value, default: []].append(contact)
            }
        }

        return mapping
            .map { MergeValueOption(value: $0.key, owners: $0.value) }
            .sorted { lhs, rhs in
                if lhs.value.isEmpty { return true }
                if rhs.value.isEmpty { return false }
                return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
            }
    }
}

// MARK: - Health Issue Actions

struct HealthIssueAction: Identifiable, Equatable {
    enum ActionType: Equatable {
        case addPhone
        case addEmail
        case addToGroup(name: String)
        case archive
        case updateName
    }

    let id = UUID()
    let title: String
    let icon: String
    let type: ActionType
    let inputPrompt: String?
    let inputPlaceholder: String?

    var requiresInput: Bool {
        switch type {
        case .addPhone, .addEmail, .updateName:
            return true
        default:
            return false
        }
    }
}

enum HealthIssueActionCatalog {
    static let phoneFollowUpGroupName = "Needs Phone Follow-Up"
    static let emailFollowUpGroupName = "Needs Email Follow-Up"
    static let generalFollowUpGroupName = "Needs Contact Cleanup"
    static let archiveGroupName = "Archive - Needs Info"
    static let reviewedGroupName = "Reviewed Health Issues"

    static func actions(for issue: DataQualityIssue) -> [HealthIssueAction] {
        var actions: [HealthIssueAction] = []

        switch issue.issueType {
        case .missingName:
            actions.append(HealthIssueAction(
                title: "Update Name",
                icon: "textformat",
                type: .updateName,
                inputPrompt: "Enter the full name for this contact.",
                inputPlaceholder: "Full Name"
            ))
            actions.append(addToGroupAction(title: "Add to Follow-Up", groupName: generalFollowUpGroupName))

        case .missingPhone:
            actions.append(HealthIssueAction(
                title: "Add Phone Number",
                icon: "phone.badge.plus",
                type: .addPhone,
                inputPrompt: "Enter the phone number you want to store on this contact.",
                inputPlaceholder: "+1 (555) 555-0100"
            ))
            actions.append(addToGroupAction(title: "Move to Needs Phone Group", groupName: phoneFollowUpGroupName))

        case .missingEmail:
            actions.append(HealthIssueAction(
                title: "Add Email Address",
                icon: "envelope.badge.plus",
                type: .addEmail,
                inputPrompt: "Enter the email address you want to add.",
                inputPlaceholder: "person@example.com"
            ))
            actions.append(addToGroupAction(title: "Move to Needs Email Group", groupName: emailFollowUpGroupName))

        case .noContactInfo:
            actions.append(addToGroupAction(title: "Add to Follow-Up Group", groupName: generalFollowUpGroupName))
            actions.append(HealthIssueAction(
                title: "Archive Contact",
                icon: "archivebox",
                type: .archive,
                inputPrompt: nil,
                inputPlaceholder: nil
            ))

        case .invalidFormat, .incompleteData, .suggestion:
            actions.append(addToGroupAction(title: "Add to Follow-Up Group", groupName: generalFollowUpGroupName))
        }

        actions.append(markReviewedAction)
        return actions
    }

    private static func addToGroupAction(title: String, groupName: String) -> HealthIssueAction {
        HealthIssueAction(
            title: title,
            icon: "folder.badge.questionmark",
            type: .addToGroup(name: groupName),
            inputPrompt: nil,
            inputPlaceholder: nil
        )
    }

    static var markReviewedAction: HealthIssueAction {
        HealthIssueAction(
            title: "Mark as Reviewed",
            icon: "checkmark.circle",
            type: .addToGroup(name: reviewedGroupName),
            inputPrompt: nil,
            inputPlaceholder: nil
        )
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
    let suggestions: Int

    // Extended statistics from new features
    let contactsWithSocialMedia: Int
    let contactsWithAddress: Int
    let contactsWithJobTitle: Int
    let contactsWithWebsite: Int
    let contactsWithNickname: Int
    let contactsWithInstantMessaging: Int
    let highDetailContacts: Int

    var dataQualityScore: Double {
        guard totalContacts > 0 else { return 100.0 }

        // Calculate quality score based on issue severity:
        // - High priority issues: -10 points each (critical problems)
        // - Medium priority issues: -3 points each (significant problems)
        // - Low priority issues: -0.5 points each (minor issues, max 5% impact)
        // - Suggestions: No penalty (helpful recommendations, not problems)

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

            // Phase 3: Social Media & Digital Presence
            case hasSocialProfile = "Has Social Media"
            case hasLinkedIn = "Has LinkedIn"
            case hasTwitter = "Has Twitter/X"
            case multipleSocialProfiles = "Multiple Social Platforms"
            case hasWebsite = "Has Website"
            case hasInstantMessaging = "Has Instant Messaging"
            case digitallyConnected = "Digitally Connected"

            // Phase 3: Geographic & Address
            case hasAddress = "Has Address"
            case missingAddress = "Missing Address"
            case multipleAddresses = "Multiple Addresses"
            case cityMatches = "City Matches"

            // Phase 3: Professional Information
            case hasJobTitle = "Has Job Title"
            case hasDepartment = "Has Department"
            case jobTitleContains = "Job Title Contains"
            case professionalContact = "Professional Contact"
            case careerNetwork = "Career Network"

            // Phase 3: Nickname & Detail Level
            case hasNickname = "Has Nickname"
            case nicknameContains = "Nickname Contains"
            case highDetailContact = "High Detail Contact"
            case basicContact = "Basic Contact"
            case businessContact = "Business Contact"
            case personalContact = "Personal Contact"
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
