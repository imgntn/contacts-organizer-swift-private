//
//  DuplicateDetector.swift
//  Contacts Organizer
//
//  Service for detecting duplicate contacts using various matching algorithms
//

import Foundation

class DuplicateDetector {
    static let shared = DuplicateDetector()

    private init() {}

    // MARK: - Main Detection Method

    func findDuplicates(in contacts: [ContactSummary]) -> [DuplicateGroup] {
        var duplicateGroups: [DuplicateGroup] = []
        var processedIds: Set<String> = []

        for contact in contacts {
            // Skip if already processed
            if processedIds.contains(contact.id) {
                continue
            }

            var matches: [ContactSummary] = [contact]
            var matchType: DuplicateGroup.MatchType = .exactName
            var maxConfidence: Double = 0.0

            // Find all potential matches
            for otherContact in contacts {
                if contact.id == otherContact.id || processedIds.contains(otherContact.id) {
                    continue
                }

                if let (isMatch, type, confidence) = compareContacts(contact, otherContact) {
                    if isMatch {
                        matches.append(otherContact)
                        processedIds.insert(otherContact.id)
                        matchType = type
                        maxConfidence = max(maxConfidence, confidence)
                    }
                }
            }

            // If we found duplicates, create a group
            if matches.count > 1 {
                processedIds.insert(contact.id)
                duplicateGroups.append(
                    DuplicateGroup(
                        contacts: matches,
                        matchType: matchType,
                        confidence: maxConfidence
                    )
                )
            }
        }

        return duplicateGroups.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Comparison Logic

    private func compareContacts(
        _ contact1: ContactSummary,
        _ contact2: ContactSummary
    ) -> (isMatch: Bool, matchType: DuplicateGroup.MatchType, confidence: Double)? {

        // Check for exact name match
        if contact1.fullName.lowercased() == contact2.fullName.lowercased() {
            return (true, .exactName, 1.0)
        }

        // Check for same phone number
        let sharedPhones = Set(contact1.phoneNumbers).intersection(Set(contact2.phoneNumbers))
        if !sharedPhones.isEmpty {
            return (true, .samePhone, 0.95)
        }

        // Check for same email
        let sharedEmails = Set(contact1.emailAddresses).intersection(Set(contact2.emailAddresses))
        if !sharedEmails.isEmpty {
            return (true, .sameEmail, 0.95)
        }

        // Check for similar names using Levenshtein distance
        let similarity = calculateNameSimilarity(contact1.fullName, contact2.fullName)
        if similarity > 0.85 {
            // Also check if they share organization or other attributes
            let hasSharedAttributes = contact1.organization != nil &&
                                     contact2.organization != nil &&
                                     contact1.organization == contact2.organization

            if hasSharedAttributes {
                return (true, .similarName, similarity)
            } else if similarity > 0.90 {
                // Very similar names even without shared attributes
                return (true, .similarName, similarity)
            }
        }

        return nil
    }

    // MARK: - String Similarity

    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        let str1 = name1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = name2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle empty strings
        if str1.isEmpty || str2.isEmpty {
            return 0.0
        }

        // Calculate Levenshtein distance
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)

        // Convert distance to similarity score (0.0 to 1.0)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let len1 = str1Array.count
        let len2 = str2Array.count

        // Create matrix
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)

        // Initialize first row and column
        for i in 0...len1 {
            matrix[i][0] = i
        }
        for j in 0...len2 {
            matrix[0][j] = j
        }

        // Fill matrix
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = str1Array[i - 1] == str2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[len1][len2]
    }

    // MARK: - Duplicate Analysis

    func analyzeDuplicates(_ groups: [DuplicateGroup]) -> DuplicateAnalysis {
        let totalDuplicates = groups.reduce(0) { $0 + $1.contacts.count }
        let groupsByType = Dictionary(grouping: groups) { $0.matchType }

        return DuplicateAnalysis(
            totalGroups: groups.count,
            totalDuplicateContacts: totalDuplicates,
            highConfidenceGroups: groups.filter { $0.confidence > 0.9 }.count,
            mediumConfidenceGroups: groups.filter { $0.confidence > 0.7 && $0.confidence <= 0.9 }.count,
            lowConfidenceGroups: groups.filter { $0.confidence <= 0.7 }.count,
            exactNameMatches: groupsByType[.exactName]?.count ?? 0,
            similarNameMatches: groupsByType[.similarName]?.count ?? 0,
            phoneMatches: groupsByType[.samePhone]?.count ?? 0,
            emailMatches: groupsByType[.sameEmail]?.count ?? 0
        )
    }
}

// MARK: - Supporting Types

struct DuplicateAnalysis {
    let totalGroups: Int
    let totalDuplicateContacts: Int
    let highConfidenceGroups: Int
    let mediumConfidenceGroups: Int
    let lowConfidenceGroups: Int
    let exactNameMatches: Int
    let similarNameMatches: Int
    let phoneMatches: Int
    let emailMatches: Int
}
