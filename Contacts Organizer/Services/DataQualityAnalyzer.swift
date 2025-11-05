//
//  DataQualityAnalyzer.swift
//  Contacts Organizer
//
//  Service for analyzing contact data quality and identifying issues
//

import Foundation

class DataQualityAnalyzer: @unchecked Sendable {
    static let shared = DataQualityAnalyzer()

    private init() {}

    // MARK: - Main Analysis Method

    nonisolated func analyzeDataQuality(contacts: [ContactSummary]) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []

        for contact in contacts {
            issues.append(contentsOf: checkContact(contact))
        }

        return issues.sorted { $0.severity.rawValue < $1.severity.rawValue }
    }

    // MARK: - Contact Checking

    nonisolated private func checkContact(_ contact: ContactSummary) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []

        // Check for missing name
        if contact.fullName.isEmpty || contact.fullName == "No Name" {
            issues.append(
                DataQualityIssue(
                    contactId: contact.id,
                    contactName: contact.fullName,
                    issueType: .missingName,
                    description: "Contact has no name",
                    severity: .high
                )
            )
        }

        // Check for no contact information
        if contact.phoneNumbers.isEmpty && contact.emailAddresses.isEmpty {
            issues.append(
                DataQualityIssue(
                    contactId: contact.id,
                    contactName: contact.fullName,
                    issueType: .noContactInfo,
                    description: "Contact has no phone number or email address",
                    severity: .high
                )
            )
        }

        // Check for missing phone
        if contact.phoneNumbers.isEmpty && !contact.emailAddresses.isEmpty {
            issues.append(
                DataQualityIssue(
                    contactId: contact.id,
                    contactName: contact.fullName,
                    issueType: .missingPhone,
                    description: "Contact has no phone number",
                    severity: .medium
                )
            )
        }

        // Check for missing email
        if contact.emailAddresses.isEmpty && !contact.phoneNumbers.isEmpty {
            issues.append(
                DataQualityIssue(
                    contactId: contact.id,
                    contactName: contact.fullName,
                    issueType: .missingEmail,
                    description: "Contact has no email address",
                    severity: .low
                )
            )
        }

        // Check for incomplete data (no organization when it might be expected)
        if contact.organization == nil &&
           !contact.phoneNumbers.isEmpty &&
           !contact.emailAddresses.isEmpty {
            // This is a lower priority issue
            issues.append(
                DataQualityIssue(
                    contactId: contact.id,
                    contactName: contact.fullName,
                    issueType: .incompleteData,
                    description: "Contact might benefit from organization info",
                    severity: .low
                )
            )
        }

        return issues
    }

    // MARK: - Summary Statistics

    func generateSummary(issues: [DataQualityIssue]) -> DataQualitySummary {
        let highSeverity = issues.filter { $0.severity == .high }.count
        let mediumSeverity = issues.filter { $0.severity == .medium }.count
        let lowSeverity = issues.filter { $0.severity == .low }.count

        let issuesByType = Dictionary(grouping: issues) { $0.issueType }

        return DataQualitySummary(
            totalIssues: issues.count,
            highSeverityCount: highSeverity,
            mediumSeverityCount: mediumSeverity,
            lowSeverityCount: lowSeverity,
            missingNameCount: issuesByType[.missingName]?.count ?? 0,
            missingPhoneCount: issuesByType[.missingPhone]?.count ?? 0,
            missingEmailCount: issuesByType[.missingEmail]?.count ?? 0,
            noContactInfoCount: issuesByType[.noContactInfo]?.count ?? 0,
            incompleteDataCount: issuesByType[.incompleteData]?.count ?? 0
        )
    }
}

// MARK: - Supporting Types

struct DataQualitySummary {
    let totalIssues: Int
    let highSeverityCount: Int
    let mediumSeverityCount: Int
    let lowSeverityCount: Int
    let missingNameCount: Int
    let missingPhoneCount: Int
    let missingEmailCount: Int
    let noContactInfoCount: Int
    let incompleteDataCount: Int

    var healthScore: Double {
        // Calculate a health score based on severity distribution
        guard totalIssues > 0 else { return 100.0 }

        // Use same weights as ContactStatistics for consistency:
        // - High priority issues: -10 points each (critical problems)
        // - Medium priority issues: -3 points each (significant problems)
        // - Low priority issues: -0.5 points each, CAPPED AT 5% max impact

        let highPenalty = Double(highSeverityCount) * 10.0
        let mediumPenalty = Double(mediumSeverityCount) * 3.0
        let lowPenalty = min(Double(lowSeverityCount) * 0.5, 5.0) // Cap low priority at 5%

        let totalPenalty = highPenalty + mediumPenalty + lowPenalty

        return max(0, 100.0 - totalPenalty)
    }
}
