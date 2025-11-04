//
//  DashboardView.swift
//  Contacts Organizer
//
//  Main dashboard after successful permission grant
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var selectedTab: DashboardTab = .overview
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var dataQualityIssues: [DataQualityIssue] = []
    @State private var isAnalyzing = false
    @AppStorage("autoRefresh") private var autoRefresh = true

    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case duplicates = "Duplicates"
        case cleanup = "Cleanup"
        case groups = "Groups"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .duplicates: return "arrow.triangle.merge"
            case .cleanup: return "wrench.and.screwdriver.fill"
            case .groups: return "folder.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(DashboardTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationTitle("Contacts Organizer")
            .frame(minWidth: 200)
        } detail: {
            // Main content
            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(
                        duplicateGroups: duplicateGroups,
                        dataQualityIssues: dataQualityIssues
                    )

                case .duplicates:
                    DuplicatesView(duplicateGroups: duplicateGroups)

                case .cleanup:
                    CleanupView(issues: dataQualityIssues)

                case .groups:
                    GroupsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if contactsManager.isLoading || isAnalyzing {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        // Loading indicator card
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(width: 40, height: 40)

                            Text(loadingMessage)
                                .font(.headline)

                            if isAnalyzing {
                                Text("This may take a moment for large contact lists")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                }
            }
        }
        .onAppear {
            // Load data in background on first appearance or if auto-refresh is enabled
            if autoRefresh || (contactsManager.contacts.isEmpty && !contactsManager.isLoading) {
                Task {
                    await loadData()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await loadData() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(contactsManager.isLoading || isAnalyzing)
            }
        }
    }

    private var loadingMessage: String {
        if contactsManager.isLoading {
            return "Loading contacts..."
        } else if isAnalyzing {
            return "Analyzing duplicates and data quality..."
        } else {
            return "Loading..."
        }
    }

    private func loadData() async {
        // Phase 1: Fetch contacts (fast, ~1 second)
        await contactsManager.fetchAllContacts()

        // Phase 2: Analyze in background WITHOUT blocking UI
        await MainActor.run {
            isAnalyzing = true
        }

        // Get contacts snapshot
        let contacts = await MainActor.run {
            contactsManager.contacts
        }

        // Spawn background task that doesn't block (fire-and-forget)
        Task { @MainActor in
            // Capture singletons before entering @Sendable closure (Swift 6 requirement)
            let duplicateDetector = DuplicateDetector.shared
            let qualityAnalyzer = DataQualityAnalyzer.shared

            // Perform analysis on background thread
            let result = await Task.detached { @Sendable [duplicateDetector, qualityAnalyzer, contacts] in
                // Find duplicates (now optimized to O(n) instead of O(n²))
                let duplicates = duplicateDetector.findDuplicates(in: contacts)

                // Analyze data quality (O(n))
                let issues = qualityAnalyzer.analyzeDataQuality(contacts: contacts)

                return (duplicates, issues)
            }.value

            // Update UI on main thread when done
            self.duplicateGroups = result.0
            self.dataQualityIssues = result.1
            self.isAnalyzing = false
        }

        // Return immediately - UI can render while analysis happens in background
    }
}

// MARK: - Overview View

struct OverviewView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    let duplicateGroups: [DuplicateGroup]
    let dataQualityIssues: [DataQualityIssue]
    @State private var showBackupReminder = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.system(size: 36, weight: .bold))

                    if let stats = contactsManager.statistics {
                        Text("\(stats.totalContacts) contacts")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Safety reminder
                if showBackupReminder && (duplicateGroups.count > 0 || dataQualityIssues.count > 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title2)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create a Backup First!")
                                .font(.headline)
                                .foregroundColor(.orange)

                            Text("Before making any changes, go to Settings → General → Backup All Contacts to protect your data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            // Open Settings
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }) {
                            Text("Open Settings")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(action: {
                            showBackupReminder = false
                        }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                // Statistics Grid
                if let stats = contactsManager.statistics {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Contacts with Phone",
                            value: "\(stats.contactsWithPhone)",
                            icon: "phone.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "Contacts with Email",
                            value: "\(stats.contactsWithEmail)",
                            icon: "envelope.fill",
                            color: .green
                        )
                        StatCard(
                            title: "Complete Contacts",
                            value: "\(stats.contactsWithBoth)",
                            icon: "checkmark.circle.fill",
                            color: .purple
                        )
                        StatCard(
                            title: "With Organization",
                            value: "\(stats.contactsWithOrganization)",
                            icon: "building.2.fill",
                            color: .orange
                        )
                        StatCard(
                            title: "With Photos",
                            value: "\(stats.contactsWithPhoto)",
                            icon: "photo.fill",
                            color: .pink
                        )
                        StatCard(
                            title: "Data Quality",
                            value: String(format: "%.0f%%", stats.dataQualityScore),
                            icon: "chart.bar.fill",
                            color: .cyan
                        )
                    }
                }

                // Issues Summary
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Issues Found")
                            .font(.title2.bold())
                        Spacer()
                    }

                    HStack(spacing: 16) {
                        IssueCard(
                            count: duplicateGroups.count,
                            title: "Duplicate Groups",
                            color: .red
                        )
                        IssueCard(
                            count: dataQualityIssues.filter { $0.severity == .high }.count,
                            title: "High Priority Issues",
                            color: .orange
                        )
                        IssueCard(
                            count: dataQualityIssues.count,
                            title: "Total Issues",
                            color: .yellow
                        )
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct IssueCard: View {
    let count: Int
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
        .environmentObject(ContactsManager.shared)
        .frame(width: 1200, height: 800)
}
