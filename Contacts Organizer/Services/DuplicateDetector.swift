//
//  DuplicateDetector.swift
//  Contacts Organizer
//
//  Service for detecting duplicate contacts using various matching algorithms
//

import Foundation

class DuplicateDetector: @unchecked Sendable {
    static let shared = DuplicateDetector()

    private init() {}

    // MARK: - Main Detection Method

    nonisolated func findDuplicates(in contacts: [ContactSummary]) -> [DuplicateGroup] {
        let startTime = Date()
        var duplicateGroups: [DuplicateGroup] = []
        var processedIds: Set<String> = []

        // OPTIMIZATION: Build hash maps for O(n) lookups instead of O(n²)

        // 1. Group by exact name (case-insensitive)
        var nameMap: [String: [ContactSummary]] = [:]
        for contact in contacts {
            let key = contact.fullName.lowercased()
            nameMap[key, default: []].append(contact)
        }

        // 2. Group by phone numbers
        var phoneMap: [String: [ContactSummary]] = [:]
        for contact in contacts {
            for phone in contact.phoneNumbers {
                phoneMap[phone, default: []].append(contact)
            }
        }

        // 3. Group by email addresses
        var emailMap: [String: [ContactSummary]] = [:]
        for contact in contacts {
            for email in contact.emailAddresses {
                emailMap[email, default: []].append(contact)
            }
        }

        // 4. First, find contacts that match on MULTIPLE criteria
        // This takes priority over single-criterion matches
        for (_, contactsGroup) in nameMap where contactsGroup.count > 1 {
            let unprocessed = contactsGroup.filter { !processedIds.contains($0.id) }
            if unprocessed.count > 1 {
                // Check if these contacts ALSO match on phone or email
                let hasPhoneMatch = unprocessed.allSatisfy { contact in
                    !contact.phoneNumbers.isEmpty && Set(unprocessed[0].phoneNumbers).intersection(Set(contact.phoneNumbers)).count > 0
                }
                let hasEmailMatch = unprocessed.allSatisfy { contact in
                    !contact.emailAddresses.isEmpty && Set(unprocessed[0].emailAddresses).intersection(Set(contact.emailAddresses)).count > 0
                }

                if hasPhoneMatch || hasEmailMatch {
                    // Multiple match criteria detected
                    unprocessed.forEach { processedIds.insert($0.id) }
                    duplicateGroups.append(
                        DuplicateGroup(
                            contacts: unprocessed,
                            matchType: .multipleMatches,
                            confidence: 1.0
                        )
                    )
                }
            }
        }

        // 5. Find exact name matches (only for unprocessed contacts)
        for (_, contactsGroup) in nameMap where contactsGroup.count > 1 {
            let unprocessed = contactsGroup.filter { !processedIds.contains($0.id) }
            if unprocessed.count > 1 {
                unprocessed.forEach { processedIds.insert($0.id) }
                duplicateGroups.append(
                    DuplicateGroup(
                        contacts: unprocessed,
                        matchType: .exactName,
                        confidence: 1.0
                    )
                )
            }
        }

        // 6. Find phone matches
        for (_, contactsGroup) in phoneMap where contactsGroup.count > 1 {
            let unprocessed = contactsGroup.filter { !processedIds.contains($0.id) }
            if unprocessed.count > 1 {
                unprocessed.forEach { processedIds.insert($0.id) }
                duplicateGroups.append(
                    DuplicateGroup(
                        contacts: unprocessed,
                        matchType: .samePhone,
                        confidence: 0.95
                    )
                )
            }
        }

        // 7. Find email matches
        for (_, contactsGroup) in emailMap where contactsGroup.count > 1 {
            let unprocessed = contactsGroup.filter { !processedIds.contains($0.id) }
            if unprocessed.count > 1 {
                unprocessed.forEach { processedIds.insert($0.id) }
                duplicateGroups.append(
                    DuplicateGroup(
                        contacts: unprocessed,
                        matchType: .sameEmail,
                        confidence: 0.95
                    )
                )
            }
        }

        // 8. Find similar names (only for remaining unprocessed contacts)
        // OPTIMIZATION: Group by first 2 characters to reduce comparisons
        let remainingContacts = contacts.filter { !processedIds.contains($0.id) }

        // Skip similar name matching if there are too many contacts (performance optimization)
        // Similar name matching is O(n²) and can be very slow for large datasets
        guard remainingContacts.count < 500 else {
            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                PrivacyMonitorService.shared.recordDuplicateDetection(duration: duration)
            }
            return duplicateGroups.sorted { $0.confidence > $1.confidence }
        }

        // For small datasets, just compare all pairs (no prefix grouping needed)
        if remainingContacts.count < 20 {
            var localProcessed: Set<String> = []

            for contact in remainingContacts {
                if localProcessed.contains(contact.id) { continue }

                var matches: [ContactSummary] = [contact]
                var maxConfidence: Double = 0.0

                for other in remainingContacts where other.id != contact.id && !localProcessed.contains(other.id) {
                    // Quick length check before expensive Levenshtein calculation
                    let lengthDiff = abs(contact.fullName.count - other.fullName.count)
                    if lengthDiff > 3 { continue }

                    let similarity = calculateNameSimilarity(contact.fullName, other.fullName)

                    if similarity > 0.85 {
                        let hasSharedOrg = contact.organization != nil &&
                                          other.organization != nil &&
                                          contact.organization == other.organization

                        if hasSharedOrg || similarity >= 0.90 {
                            matches.append(other)
                            localProcessed.insert(other.id)
                            maxConfidence = max(maxConfidence, similarity)
                        }
                    }
                }

                if matches.count > 1 {
                    localProcessed.insert(contact.id)
                    processedIds.formUnion(matches.map { $0.id })
                    duplicateGroups.append(
                        DuplicateGroup(
                            contacts: matches,
                            matchType: .similarName,
                            confidence: maxConfidence
                        )
                    )
                }
            }

            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                PrivacyMonitorService.shared.recordDuplicateDetection(duration: duration)
            }
            return duplicateGroups.sorted { $0.confidence > $1.confidence }
        }

        // For larger datasets, use prefix grouping optimization
        var prefixMap: [String: [ContactSummary]] = [:]
        for contact in remainingContacts {
            let name = contact.fullName.lowercased()
            let prefix = String(name.prefix(min(2, name.count)))
            prefixMap[prefix, default: []].append(contact)
        }

        // Only compare contacts with same prefix (massive reduction from O(n²))
        for (_, contactsGroup) in prefixMap where contactsGroup.count > 1 && contactsGroup.count < 100 {
            var localProcessed: Set<String> = []

            for contact in contactsGroup {
                if localProcessed.contains(contact.id) { continue }

                var matches: [ContactSummary] = [contact]
                var maxConfidence: Double = 0.0

                for other in contactsGroup where other.id != contact.id && !localProcessed.contains(other.id) {
                    // Quick length check before expensive Levenshtein calculation
                    let lengthDiff = abs(contact.fullName.count - other.fullName.count)
                    if lengthDiff > 3 { continue } // Skip if names differ too much in length

                    let similarity = calculateNameSimilarity(contact.fullName, other.fullName)

                    if similarity > 0.85 {
                        let hasSharedOrg = contact.organization != nil &&
                                          other.organization != nil &&
                                          contact.organization == other.organization

                        if hasSharedOrg || similarity >= 0.90 {
                            matches.append(other)
                            localProcessed.insert(other.id)
                            maxConfidence = max(maxConfidence, similarity)
                        }
                    }
                }

                if matches.count > 1 {
                    localProcessed.insert(contact.id)
                    processedIds.formUnion(matches.map { $0.id })
                    duplicateGroups.append(
                        DuplicateGroup(
                            contacts: matches,
                            matchType: .similarName,
                            confidence: maxConfidence
                        )
                    )
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        Task { @MainActor in
            PrivacyMonitorService.shared.recordDuplicateDetection(duration: duration)
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

    nonisolated private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
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

    nonisolated private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
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
