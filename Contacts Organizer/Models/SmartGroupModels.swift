//
//  SmartGroupModels.swift
//  Contacts Organizer
//
//  Models for smart group functionality
//

import Foundation

// MARK: - Smart Group Definition

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

// MARK: - Geographic Criteria

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

// MARK: - Custom Criteria

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
        }

        enum Condition: String, Codable {
            case exists = "Exists"
            case notExists = "Does Not Exist"
            case contains = "Contains"
        }
    }
}

// MARK: - Smart Group Result

struct SmartGroupResult: Identifiable {
    let id = UUID()
    let groupName: String
    let contacts: [ContactSummary]
    let criteria: SmartGroupDefinition.GroupingType
}
