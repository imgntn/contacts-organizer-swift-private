import Combine
import SwiftUI
import Contacts

protocol OverviewContactsProviding {
    var statisticsPublisher: AnyPublisher<ContactStatistics?, Never> { get }
    var recentActivitiesPublisher: AnyPublisher<[RecentActivity], Never> { get }
    var groupsPublisher: AnyPublisher<[CNGroup], Never> { get }
}

protocol OverviewAppStateProviding: AnyObject {
    var hasSeenBackupReminder: Bool { get }
    var hasSeenBackupReminderPublisher: AnyPublisher<Bool, Never> { get }
    func markBackupReminderSeen()
    func resetBackupReminder()
}

final class OverviewDashboardModel: ObservableObject {
    @Published private(set) var totalContacts: Int = 0
    @Published private(set) var duplicateCount: Int = 0
    @Published private(set) var issuesCount: Int = 0
    @Published private(set) var recentActivities: [RecentActivity] = []
    @Published private(set) var manualGroupCount: Int = 0
    @Published private(set) var showBackupReminder: Bool

    private let contactsProvider: OverviewContactsProviding
    private let appState: OverviewAppStateProviding
    private let navigator: OverviewNavigating
    private let undoManager: ContactsUndoManager
    private var cancellables = Set<AnyCancellable>()

    init(
        contactsProvider: OverviewContactsProviding,
        appState: OverviewAppStateProviding,
        navigator: OverviewNavigating,
        undoManager: ContactsUndoManager
    ) {
        self.contactsProvider = contactsProvider
        self.appState = appState
        self.navigator = navigator
        self.undoManager = undoManager
        self.showBackupReminder = !appState.hasSeenBackupReminder
        bind()
    }

    private func bind() {
        contactsProvider.statisticsPublisher
            .receive(on: DispatchQueue.main)
            .map { $0?.totalContacts ?? 0 }
            .assign(to: &$totalContacts)

        contactsProvider.recentActivitiesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$recentActivities)

        contactsProvider.groupsPublisher
            .receive(on: DispatchQueue.main)
            .map { $0.count }
            .assign(to: &$manualGroupCount)

        appState.hasSeenBackupReminderPublisher
            .receive(on: DispatchQueue.main)
            .map { !$0 }
            .assign(to: &$showBackupReminder)
    }

    func updateDuplicates(_ groups: [DuplicateGroup]) {
        duplicateCount = groups.reduce(0) { $0 + max(0, $1.contacts.count - 1) }
    }

    func updateIssues(_ issues: [DataQualityIssue]) {
        issuesCount = issues.count
    }

    func browseSmartGroups() {
        navigator.select(.smartGroups)
    }

    func browseManualGroups() {
        navigator.select(.manualGroups)
    }

    func reviewDuplicates() {
        navigator.select(.duplicates)
    }

    func reviewHealthReport() {
        navigator.select(.healthReport)
    }

    func reviewSmartGroup(named name: String) {
        navigator.reviewSmartGroup(named: name)
    }

    func dismissBackupReminder() {
        guard showBackupReminder else { return }
        appState.markBackupReminderSeen()
        undoManager.register(description: "Dismiss backup reminder") { [weak self] in
            guard let self else { return false }
            self.appState.resetBackupReminder()
            return true
        } redo: { [weak self] in
            guard let self else { return false }
            self.appState.markBackupReminderSeen()
            return true
        }
    }
}

extension ContactsManager: OverviewContactsProviding {
    var statisticsPublisher: AnyPublisher<ContactStatistics?, Never> {
        $statistics.eraseToAnyPublisher()
    }

    var recentActivitiesPublisher: AnyPublisher<[RecentActivity], Never> {
        $recentActivities.eraseToAnyPublisher()
    }

    var groupsPublisher: AnyPublisher<[CNGroup], Never> {
        $groups.eraseToAnyPublisher()
    }
}
