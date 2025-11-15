//
//  DashboardView.swift
//  Contacts Organizer
//
//  Main dashboard after successful permission grant
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var undoManager: ContactsUndoManager
    @EnvironmentObject var diagnosticsCenter: DiagnosticsCenter
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DashboardTab? = .overview
    @State private var navigationHistory: [DashboardTab] = []
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var dataQualityIssues: [DataQualityIssue] = []
    @State private var isAnalyzing = false
    @State private var targetSmartGroupName: String?
    @State private var refreshMachine = RefreshStateMachine()
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("sidebarOrder") private var sidebarOrderStorageRaw: String = ""

    private func getSidebarOrder() -> [String] {
        guard let data = sidebarOrderStorageRaw.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    @MainActor
    private func setSidebarOrder(_ newValue: [String]) {
        if let data = try? JSONEncoder().encode(newValue),
           let string = String(data: data, encoding: .utf8) {
            sidebarOrderStorageRaw = string
        } else {
            sidebarOrderStorageRaw = ""
        }
    }

    @State private var sidebarItems: [DashboardTab] = DashboardTab.allCases
    @State private var isReordering: Bool = false
    @State private var showErrorBanner = false
    @State private var isShowingDiagnosticsSheet = false

    enum DashboardTab: String, CaseIterable, Hashable {
        case overview = "Overview"
        case recentActivity = "Recent Activity"
        case smartGroups = "Smart Groups"
        case manualGroups = "Manual Groups"
        case duplicates = "Duplicates"
        case healthReport = "Health Report"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .recentActivity: return "clock.arrow.circlepath"
            case .duplicates: return "arrow.triangle.merge"
            case .healthReport: return "wrench.and.screwdriver.fill"
            case .smartGroups: return "sparkles"
            case .manualGroups: return "folder.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button(action: toggleReordering) {
                            Label(isReordering ? "Finish Reordering" : "Rearrange Sidebar", systemImage: "arrow.up.arrow.down.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(isReordering ? "Finish reordering" : "Reorder sidebar items")
                        Spacer()
                    }

                    if isReordering {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text("Drag to reorder sidebar items")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 12)

                List(selection: $selectedTab) {
                    ForEach(sidebarItems, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                            .padding(.vertical, 4)
                    }
                    .onMove { indices, newOffset in
                        sidebarItems.move(fromOffsets: indices, toOffset: newOffset)
                        // Persist new order
                        setSidebarOrder(sidebarItems.map { $0.rawValue })
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .moveDisabled(!isReordering)
            }
            .navigationTitle("Contacts Organizer")
            .frame(minWidth: 200)
        } detail: {
            ZStack(alignment: .top) {
                detailContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if contactsManager.isLoading || isAnalyzing {
                            ZStack {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()

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

                if showErrorBanner, let errorMessage = contactsManager.errorMessage {
                    DashboardErrorBanner(
                        message: errorMessage,
                        isRetryDisabled: contactsManager.isLoading || isAnalyzing,
                        onRetry: { Task { await loadData() } },
                        onDiagnostics: { isShowingDiagnosticsSheet = true },
                        onDismiss: dismissErrorMessage
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showErrorBanner)
        }
        .onAppear {
            // Restore sidebar order if previously saved
            if !getSidebarOrder().isEmpty {
                var mapped: [DashboardTab] = []
                for str in getSidebarOrder() {
                    if str == "Groups" {
                        // Migrate old single Groups item into two new entries in-place
                        mapped.append(.smartGroups)
                        mapped.append(.manualGroups)
                    } else if let tab = DashboardTab(rawValue: str) {
                        mapped.append(tab)
                    }
                }
                // Ensure we include any new tabs that may have been added in updates
                let missing = DashboardTab.allCases.filter { !mapped.contains($0) }
                sidebarItems = mapped + missing
            }

            // Load data in background on first appearance or if auto-refresh is enabled
            if autoRefresh || (contactsManager.contacts.isEmpty && !contactsManager.isLoading) {
                Task {
                    await loadData()
                }
            }

            showErrorBanner = contactsManager.errorMessage != nil
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Push previous tab into history if it exists and isn't the same as new
            if let oldValue, let newValue, oldValue != newValue {
                navigationHistory.append(oldValue)
            }
        }
        .onChange(of: contactsManager.refreshTrigger) { _, trigger in
            handleRefreshTrigger(trigger)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    if let last = navigationHistory.popLast() {
                        selectedTab = last
                    } else {
                        // If no history, try to dismiss any presented view
                        dismiss()
                    }
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(navigationHistory.isEmpty && (selectedTab ?? .overview) == .overview)
                .help("Go back")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await loadData() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(contactsManager.isLoading || isAnalyzing)
            }
        }
        .onChange(of: contactsManager.errorMessage) { _, newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showErrorBanner = newValue != nil
            }
        }
        .sheet(isPresented: $isShowingDiagnosticsSheet) {
            DiagnosticsView()
                .environmentObject(diagnosticsCenter)
                .frame(minWidth: 520, minHeight: 420)
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

    private func handleRefreshTrigger(_ trigger: ContactsManager.RefreshTrigger) {
        guard autoRefresh else { return }
        if refreshMachine.handleTrigger(autoRefreshEnabled: autoRefresh, isLoading: contactsManager.isLoading, isAnalyzing: isAnalyzing) {
            Task {
                await loadData(triggerReason: trigger.reason)
            }
        }
    }

    private func loadData(triggerReason: ContactsManager.RefreshReason? = nil) async {
        guard refreshMachine.prepareForLoad(isLoading: contactsManager.isLoading, isAnalyzing: isAnalyzing) else { return }

        // Phase 1: Fetch contacts (fast, ~1 second)
        await contactsManager.fetchAllContacts()

        // Phase 2: Analyze in background WITHOUT blocking UI
        await MainActor.run {
            isAnalyzing = true
        }

        // Get contacts snapshot on the main actor
        let contacts = await MainActor.run { contactsManager.contacts }

        // Capture singletons on the main actor to respect actor isolation in Swift 6
        let duplicateDetector = await MainActor.run { DuplicateDetector.shared }
        let qualityAnalyzer = await MainActor.run { DataQualityAnalyzer.shared }

        // Perform analysis off the main actor
        let result = await Task.detached { @Sendable in
            // Use captured instances to avoid touching main-actor isolated singletons here
            let duplicates = duplicateDetector.findDuplicates(in: contacts)
            let issues = qualityAnalyzer.analyzeDataQuality(contacts: contacts)
            return (duplicates, issues)
        }.value

        // Update UI and statistics on the main actor
        await MainActor.run {
            duplicateGroups = result.0
            dataQualityIssues = result.1
            isAnalyzing = false
            contactsManager.updateStatisticsWithIssues(result.1)
        }

        // Return immediately - UI can render while analysis happens in background

        if refreshMachine.consumePendingRefresh() {
            Task {
                await loadData(triggerReason: triggerReason)
            }
        }
    }

    private func toggleReordering() {
        withAnimation(.default) {
            isReordering.toggle()
        }
        if !isReordering {
            setSidebarOrder(sidebarItems.map { $0.rawValue })
        }
    }

    private func dismissErrorMessage() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showErrorBanner = false
        }
        contactsManager.errorMessage = nil
    }
}

extension DashboardView {
    fileprivate func handleActivityTap(_ activity: RecentActivity) {
        switch activity.kind {
        case .smartGroupCreated:
            targetSmartGroupName = activity.detail
            selectedTab = .smartGroups
        case .manualGroupCreated:
            selectedTab = .manualGroups
        case .duplicatesCleaned:
            selectedTab = .duplicates
        case .healthAction, .export:
            selectedTab = .recentActivity
        }
    }

    @ViewBuilder
    fileprivate func detailContent() -> some View {
        switch selectedTab ?? .overview {
        case .overview:
            OverviewView(
                duplicateGroups: duplicateGroups,
                dataQualityIssues: dataQualityIssues,
                selectedTab: $selectedTab,
                targetSmartGroupName: $targetSmartGroupName,
                contactsManager: contactsManager,
                appState: appState,
                undoManager: undoManager,
                onActivityTap: self.handleActivityTap
            )
        case .recentActivity:
            RecentActivityListView(onActivityTap: { activity in
                handleActivityTap(activity)
            })
        case .duplicates:
            DuplicatesView(duplicateGroups: duplicateGroups)
        case .healthReport:
            HealthReportView(issues: dataQualityIssues)
        case .smartGroups:
            GroupsView(initialTab: .smart, targetSmartGroupName: $targetSmartGroupName)
        case .manualGroups:
            GroupsView(initialTab: .manual, targetSmartGroupName: $targetSmartGroupName)
        }
    }
}

// MARK: - Overview View

struct OverviewView: View {
    @Environment(\.openSettings) private var openSettings
    var duplicateGroups: [DuplicateGroup]
    var dataQualityIssues: [DataQualityIssue]
    @Binding var selectedTab: DashboardView.DashboardTab?
    @Binding var targetSmartGroupName: String?
    @StateObject private var viewModel: OverviewDashboardModel
    let onActivityTap: (RecentActivity) -> Void

    init(
        duplicateGroups: [DuplicateGroup],
        dataQualityIssues: [DataQualityIssue],
        selectedTab: Binding<DashboardView.DashboardTab?>,
        targetSmartGroupName: Binding<String?>,
        contactsManager: OverviewContactsProviding,
        appState: OverviewAppStateProviding,
        undoManager: ContactsUndoManager,
        onActivityTap: @escaping (RecentActivity) -> Void = { _ in }
    ) {
        self.duplicateGroups = duplicateGroups
        self.dataQualityIssues = dataQualityIssues
        _selectedTab = selectedTab
        _targetSmartGroupName = targetSmartGroupName
        self.onActivityTap = onActivityTap
        let navigator = OverviewNavigator(selectedTab: selectedTab, targetSmartGroupName: targetSmartGroupName)
        _viewModel = StateObject(wrappedValue: OverviewDashboardModel(
            contactsProvider: contactsManager,
            appState: appState,
            navigator: navigator,
            undoManager: undoManager
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .responsiveFont(36, weight: .bold)

                    Text("\(viewModel.totalContacts) contacts")
                        .responsiveFont(20)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Safety reminder (required)
                if viewModel.showBackupReminder {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Create a Backup First!", systemImage: "exclamationmark.shield.fill")
                                .responsiveFont(16, weight: .semibold)
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Required")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Text("Before making any changes, go to Settings → General → Backup All Contacts to protect your data.")
                            .platformBodyFont()
                            .foregroundColor(.secondary)

                        Button(action: openGeneralSettings) {
                            Label("Open App Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("Open Settings or press ⌘,")

                        Button("Dismiss Reminder") {
                            viewModel.dismissBackupReminder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                if viewModel.totalContacts > 0 {
                    contactActivitySection
                }

                if !viewModel.recentActivities.isEmpty {
                    recentActivitySection
                }

                LazyVGrid(columns: overviewColumns, spacing: 16) {
                    featureCard(
                        title: "Smart Groups",
                        icon: "sparkles",
                        color: .purple,
                        description: "Auto-generated collections surface contacts missing info or matching useful recipes.",
                        status: "\(ContactsManager.defaultSmartGroups.count)+ recipes available",
                        highlights: [
                            ("sparkles", "Dive into curated segments instantly"),
                            ("plus.app", "Create a group in Contacts with one tap")
                        ],
                        primaryButtonTitle: "Browse Smart Groups",
                        primaryButtonIcon: "sparkles",
                        primaryAction: {
                            viewModel.browseSmartGroups()
                        },
                        secondary: (
                            title: "Review Missing Info",
                            icon: "exclamationmark.circle",
                            action: {
                                viewModel.reviewSmartGroup(named: "Missing Email")
                            }
                        )
                    )

                    featureCard(
                        title: "Manual Groups",
                        icon: "folder.fill.badge.plus",
                        color: .blue,
                        description: "Build your own folders for projects, events, or VIP lists with full control.",
                        status: "\(viewModel.manualGroupCount) groups in Contacts",
                        highlights: [
                            ("plus.circle", "Spin up a fresh manual group"),
                            ("trash", "Clean up duplicate folders safely")
                        ],
                        primaryButtonTitle: "Open Manual Groups",
                        primaryButtonIcon: "folder.fill",
                        primaryAction: {
                            viewModel.browseManualGroups()
                        },
                        secondary: (
                            title: "Create New Group",
                            icon: "plus.circle",
                            action: {
                                viewModel.browseManualGroups()
                            }
                        )
                    )

                    featureCard(
                        title: "Duplicates",
                        icon: "arrow.triangle.merge",
                        color: .green,
                        description: "Review contacts that look identical so you can merge, link, or ignore them.",
                        status: "\(viewModel.duplicateCount) groups detected",
                        highlights: [
                            ("eye", "Compare conflicting values side-by-side"),
                            ("arrow.down", "Apply quick merges with confidence")
                        ],
                        primaryButtonTitle: "Review Duplicates",
                        primaryButtonIcon: "arrow.triangle.merge",
                        primaryAction: {
                            viewModel.reviewDuplicates()
                        }
                    )

                    featureCard(
                        title: "Health Report",
                        icon: "heart.text.square",
                        color: .pink,
                        description: "Spot missing phone numbers, emails, birthdays, and other gaps in your address book.",
                        status: "\(viewModel.issuesCount) issues flagged",
                        highlights: [
                            ("stethoscope", "Prioritize high-severity fixes first"),
                            ("bolt", "Jump straight into auto-fix suggestions")
                        ],
                        primaryButtonTitle: "Open Health Report",
                        primaryButtonIcon: "heart.text.square",
                        primaryAction: {
                            viewModel.reviewHealthReport()
                        }
                    )
                }
            }
            .padding(24)
        }
        .onAppear {
            viewModel.updateDuplicates(duplicateGroups)
            viewModel.updateIssues(dataQualityIssues)
        }
        .onChange(of: duplicateGroups.map(\.id)) { _, _ in
            viewModel.updateDuplicates(duplicateGroups)
        }
        .onChange(of: dataQualityIssues.map(\.id)) { _, _ in
            viewModel.updateIssues(dataQualityIssues)
        }
    }

    private var overviewColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let recencyRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var contactActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Contact Activity", systemImage: "calendar.badge.clock")
                    .responsiveFont(16, weight: .semibold)
                Spacer()
            }

            HStack(alignment: .top, spacing: 16) {
                recencyTile(
                    title: "Added in the last 30 days",
                    value: viewModel.recentlyAddedCount,
                    detail: recencyDetail(
                        for: viewModel.mostRecentAddition,
                        fallback: "No additions tracked yet",
                        verb: "Last added"
                    ),
                    icon: "person.badge.plus",
                    tint: .accentColor
                )

                recencyTile(
                    title: "Updated in the last 14 days",
                    value: viewModel.recentlyUpdatedCount,
                    detail: recencyDetail(
                        for: viewModel.mostRecentUpdate,
                        fallback: "No edits detected yet",
                        verb: "Last updated"
                    ),
                    icon: "square.and.pencil",
                    tint: .pink
                )
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                    .responsiveFont(16, weight: .semibold)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recentActivities) { activity in
                        Button(action: { onActivityTap(activity) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: activity.icon)
                                        .foregroundColor(.accentColor)
                                    Text(activity.title)
                                        .responsiveFont(13, weight: .semibold)
                                }
                                Text(activity.detail)
                                    .platformBodyFont()
                                Text(relativeTimeDescription(for: activity.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .frame(minWidth: 180, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    private func relativeTimeDescription(for date: Date) -> String {
        OverviewView.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func recencyDetail(for date: Date?, fallback: String, verb: String) -> String {
        guard let date else { return fallback }
        let relative = OverviewView.recencyRelativeFormatter.localizedString(for: date, relativeTo: Date())
        return "\(verb) \(relative)"
    }

    private func recencyTile(
        title: String,
        value: Int,
        detail: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(tint)
                        .imageScale(.medium)
                }
                Text(title)
                    .responsiveFont(16, weight: .semibold)
            }

            Text(formattedContactCount(value))
                .responsiveFont(30, weight: .bold)

            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func formattedContactCount(_ count: Int) -> String {
        count == 1 ? "1 contact" : "\(count) contacts"
    }

    private func openGeneralSettings() {
        UserDefaults.standard.set("general", forKey: SettingsPreferences.selectedTabKey)
        openSettings()
    }

    @ViewBuilder
    private func featureCard(
        title: String,
        icon: String,
        color: Color,
        description: String,
        status: String? = nil,
        highlights: [(String, String)] = [],
        primaryButtonTitle: String,
        primaryButtonIcon: String,
        primaryAction: @escaping () -> Void,
        secondary: (title: String, icon: String, action: () -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(title)
                    .responsiveFont(20, weight: .semibold)
                Spacer()
            }

            Text(description)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status {
                Label(status, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { highlight in
                        Label(highlight.element.1, systemImage: highlight.element.0)
                    }
                }
            }

            HStack {
                Button(action: primaryAction) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                }
                .buttonStyle(.borderedProminent)

                if let secondary {
                    Button(action: secondary.action) {
                        Label(secondary.title, systemImage: secondary.icon)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Dashboard Error Banner

private struct DashboardErrorBanner: View {
    let message: String
    let isRetryDisabled: Bool
    let onRetry: () -> Void
    let onDiagnostics: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("We couldn’t refresh your contacts")
                    .font(.headline)
                Spacer(minLength: 12)
                Button(role: .cancel, action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(message)
                .font(.callout)
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetryDisabled)

                Button(action: onDiagnostics) {
                    Label("View Diagnostics", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Recent Activity View

struct RecentActivityListView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    var onActivityTap: ((RecentActivity) -> Void)?

    init(onActivityTap: ((RecentActivity) -> Void)? = nil) {
        self.onActivityTap = onActivityTap
    }

    private var groupedActivities: [(Date, [RecentActivity])] {
        RecentActivitySections.groupedByDay(contactsManager.recentActivities)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Recent Activity")
                    .responsiveFont(34, weight: .bold)

                if contactsManager.recentActivities.isEmpty {
                    recentActivityEmptyState
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedActivities, id: \.0) { date, entries in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(Self.sectionFormatter.string(from: date))
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.secondary)

                                VStack(spacing: 12) {
                                    ForEach(entries) { activity in
                                        RecentActivityRow(
                                            activity: activity,
                                            onTap: { onActivityTap?(activity) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var recentActivityEmptyState: some View {
        if #available(macOS 13.0, *) {
            ContentUnavailableView(
                "No Recent Activity",
                systemImage: "clock.arrow.circlepath",
                description: Text("Complete a health report action, create a group, or clean duplicates to populate your history.")
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No Recent Activity")
                    .font(.title2.bold())
                Text("Your future actions in Smart Groups, Manual Groups, Duplicates, and Health Report will appear here.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    private static let sectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

private struct RecentActivityRow: View {
    let activity: RecentActivity
    let onTap: () -> Void
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(activity: RecentActivity, onTap: @escaping () -> Void = {}) {
        self.activity = activity
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                Text(activity.detail)
                    .foregroundColor(.secondary)
                Text(Self.relativeFormatter.localizedString(for: activity.timestamp, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            onTap()
        }
    }
}

struct RefreshStateMachine {
    private(set) var pendingAutoRefresh = false

    mutating func handleTrigger(autoRefreshEnabled: Bool, isLoading: Bool, isAnalyzing: Bool) -> Bool {
        guard autoRefreshEnabled else { return false }
        if isLoading || isAnalyzing {
            pendingAutoRefresh = true
            return false
        }
        return true
    }

    mutating func prepareForLoad(isLoading: Bool, isAnalyzing: Bool) -> Bool {
        if isLoading || isAnalyzing {
            pendingAutoRefresh = true
            return false
        }
        return true
    }

    mutating func consumePendingRefresh() -> Bool {
        if pendingAutoRefresh {
            pendingAutoRefresh = false
            return true
        }
        return false
    }
}


#if !DISABLE_PREVIEWS
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(ContactsManager.shared)
        .environmentObject(ContactsUndoManager())
        .frame(width: 1200, height: 800)
}
#endif
