//
//  SmartGroupService.swift
//  Contacts Organizer
//
//  Service for creating and managing smart groups
//

import Foundation

class SmartGroupService: @unchecked Sendable {
    static let shared = SmartGroupService()

    private init() {}

    // MARK: - Generate Smart Groups

    nonisolated func generateSmartGroups(from contacts: [ContactSummary], definitions: [SmartGroupDefinition]) -> [SmartGroupResult] {
        let startTime = Date()
        var results: [SmartGroupResult] = []

        for definition in definitions where definition.isEnabled {
            switch definition.groupingType {
            case .geographic(let criteria):
                results.append(contentsOf: groupByGeography(contacts, criteria: criteria))

            case .organization:
                results.append(contentsOf: groupByOrganization(contacts))

            case .custom(let criteria):
                results.append(contentsOf: groupByCustomCriteria(contacts, name: definition.name, criteria: criteria))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        DiagnosticsCenter.logPerformance(
            operation: "Smart group generation (\(contacts.count) contacts)",
            duration: duration,
            threshold: DiagnosticsThresholds.smartGroupGeneration
        )

        return results
    }

    // MARK: - Geographic Grouping

    nonisolated private func groupByGeography(_ contacts: [ContactSummary], criteria: GeographicCriteria) -> [SmartGroupResult] {
        // For now, we'll use organization as a proxy since ContactSummary doesn't have address
        // In a real implementation, you'd need to fetch full CNContact objects with addresses

        // Group contacts that have location-related info
        let contactsWithLocation = contacts.filter { contact in
            // Check if organization might contain location info
            guard let org = contact.organization else { return false }
            return !org.isEmpty
        }

        switch criteria {
        case .byCity:
            // Simple implementation - would need full address data
            return [SmartGroupResult(
                groupName: "Contacts with Location Info",
                contacts: contactsWithLocation,
                criteria: .geographic(criteria)
            )]

        case .byState:
            return [SmartGroupResult(
                groupName: "Contacts with Location Info",
                contacts: contactsWithLocation,
                criteria: .geographic(criteria)
            )]

        case .byCountry:
            return [SmartGroupResult(
                groupName: "Contacts with Location Info",
                contacts: contactsWithLocation,
                criteria: .geographic(criteria)
            )]
        }
    }

    // MARK: - Organization Grouping

    nonisolated private func groupByOrganization(_ contacts: [ContactSummary]) -> [SmartGroupResult] {
        // Group contacts by organization
        var organizationGroups: [String: [ContactSummary]] = [:]

        for contact in contacts {
            if let org = contact.organization, !org.isEmpty {
                organizationGroups[org, default: []].append(contact)
            }
        }

        // Only return groups with 2+ contacts
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

    // MARK: - Custom Criteria Grouping

    nonisolated private func groupByCustomCriteria(_ contacts: [ContactSummary], name: String, criteria: CustomCriteria) -> [SmartGroupResult] {
        let matchingContacts = contacts.filter { contact in
            // All rules must match
            criteria.rules.allSatisfy { rule in
                matchesRule(contact: contact, rule: rule)
            }
        }

        guard !matchingContacts.isEmpty else { return [] }

        return [SmartGroupResult(
            groupName: name,
            contacts: matchingContacts,
            criteria: .custom(criteria)
        )]
    }

    // MARK: - Rule Matching

    nonisolated private func matchesRule(contact: ContactSummary, rule: CustomCriteria.Rule) -> Bool {
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
            return contact.fullName.localizedCaseInsensitiveContains(value)
        }
    }

    // MARK: - Preset Definitions

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
            )
        ]
    }
}
