//
//  CleanupView.swift
//  Contacts Organizer
//
//  View for managing data quality issues
//

import SwiftUI

struct CleanupView: View {
    let issues: [DataQualityIssue]
    @State private var selectedSeverity: DataQualityIssue.Severity?
    @State private var selectedIssueType: DataQualityIssue.IssueType?
    @State private var excludeMissingEmail = false

    private var filteredIssues: [DataQualityIssue] {
        issues.filter { issue in
            let severityMatch = selectedSeverity == nil || issue.severity == selectedSeverity
            let typeMatch = selectedIssueType == nil || issue.issueType == selectedIssueType
            let emailExclude = !excludeMissingEmail || issue.issueType != .missingEmail
            return severityMatch && typeMatch && emailExclude
        }
    }

    private var summary: DataQualitySummary {
        DataQualityAnalyzer.shared.generateSummary(issues: issues)
    }

    var body: some View {
        Group {
            if issues.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "Excellent Data Quality",
                    message: "All your contacts have complete information. No cleanup needed!",
                    color: .green
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Data Quality")
                                    .font(.system(size: 42, weight: .bold))

                                Text("\(issues.count) issues found")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            // Health score
                            VStack(spacing: 4) {
                                Text(String(format: "%.0f%%", summary.healthScore))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(healthScoreColor)

                                Text("Health Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Summary cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            SeverityCard(
                                severity: .high,
                                count: summary.highSeverityCount,
                                isSelected: selectedSeverity == .high
                            ) {
                                toggleSeverityFilter(.high)
                            }

                            SeverityCard(
                                severity: .medium,
                                count: summary.mediumSeverityCount,
                                isSelected: selectedSeverity == .medium
                            ) {
                                toggleSeverityFilter(.medium)
                            }

                            SeverityCard(
                                severity: .low,
                                count: summary.lowSeverityCount,
                                isSelected: selectedSeverity == .low
                            ) {
                                toggleSeverityFilter(.low)
                            }
                        }

                        // Issue type filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                FilterChip(
                                    title: "All Issues",
                                    count: issues.count,
                                    isSelected: selectedIssueType == nil
                                ) {
                                    selectedIssueType = nil
                                }

                                if summary.missingNameCount > 0 {
                                    FilterChip(
                                        title: "Missing Name",
                                        count: summary.missingNameCount,
                                        isSelected: selectedIssueType == .missingName
                                    ) {
                                        toggleIssueTypeFilter(.missingName)
                                    }
                                }

                                if summary.noContactInfoCount > 0 {
                                    FilterChip(
                                        title: "No Contact Info",
                                        count: summary.noContactInfoCount,
                                        isSelected: selectedIssueType == .noContactInfo
                                    ) {
                                        toggleIssueTypeFilter(.noContactInfo)
                                    }
                                }

                                if summary.missingPhoneCount > 0 {
                                    FilterChip(
                                        title: "Missing Phone",
                                        count: summary.missingPhoneCount,
                                        isSelected: selectedIssueType == .missingPhone
                                    ) {
                                        toggleIssueTypeFilter(.missingPhone)
                                    }
                                }

                                if summary.missingEmailCount > 0 {
                                    FilterChip(
                                        title: "Missing Email",
                                        count: summary.missingEmailCount,
                                        isSelected: selectedIssueType == .missingEmail
                                    ) {
                                        toggleIssueTypeFilter(.missingEmail)
                                    }
                                }

                                // Exclude filter
                                FilterChip(
                                    title: excludeMissingEmail ? "Show Missing Email" : "Hide Missing Email",
                                    count: summary.missingEmailCount,
                                    isSelected: excludeMissingEmail
                                ) {
                                    excludeMissingEmail.toggle()
                                    // Clear specific email filter if we're excluding
                                    if excludeMissingEmail && selectedIssueType == .missingEmail {
                                        selectedIssueType = nil
                                    }
                                }
                            }
                        }

                        // Issues list
                        LazyVStack(spacing: 12) {
                            ForEach(filteredIssues) { issue in
                                IssueRowView(issue: issue)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    private var healthScoreColor: Color {
        if summary.healthScore >= 80 {
            return .green
        } else if summary.healthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private func toggleSeverityFilter(_ severity: DataQualityIssue.Severity) {
        if selectedSeverity == severity {
            selectedSeverity = nil
        } else {
            selectedSeverity = severity
        }
    }

    private func toggleIssueTypeFilter(_ type: DataQualityIssue.IssueType) {
        if selectedIssueType == type {
            selectedIssueType = nil
        } else {
            selectedIssueType = type
        }
    }
}

// MARK: - Supporting Views

struct SeverityCard: View {
    let severity: DataQualityIssue.Severity
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: severityIcon)
                    .font(.title)
                    .foregroundColor(severityColor)

                Text("\(count)")
                    .font(.system(size: 32, weight: .bold))

                Text("\(severity.description) Priority")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                ZStack {
                    (isSelected ? severityColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isHovered || isFocused) ? severityColor.opacity(0.7) : (isSelected ? severityColor : Color.clear), lineWidth: (isHovered || isFocused) ? 2 : (isSelected ? 2 : 0))
                }
            )
            .cornerRadius(12)
            .scaleEffect((isHovered || isFocused) ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered || isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
#if !os(macOS)
        .hoverEffect(.lift)
#endif
    }

    private var severityIcon: String {
        switch severity {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("(\(count))")
                    .foregroundColor(.secondary)
            }
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct IssueRowView: View {
    let issue: DataQualityIssue

    var body: some View {
        HStack(spacing: 16) {
            // Severity indicator
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .frame(width: 24)

            // Issue details
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.contactName)
                    .font(.headline)
                    .bold()

                Text(issue.description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            Button("View Contact") {
                openContactInContactsApp(contactId: issue.contactId)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var severityIcon: String {
        switch issue.severity {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }

    private func openContactInContactsApp(contactId: String) {
        if let url = URL(string: "addressbook://\(contactId)") {
            NSWorkspace.shared.open(url)
            print("📖 Opening contact in Contacts.app: \(issue.contactName) (\(contactId))")
        }
    }
}

extension DataQualityIssue.Severity: CustomStringConvertible {
    var description: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

#Preview {
    CleanupView(issues: [])
}
