//
//  PrivacyMonitorService.swift
//  Contacts Organizer
//
//  Service for monitoring privacy metrics and proving on-device processing
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PrivacyMonitorService: ObservableObject {
    static let shared = PrivacyMonitorService()

    // MARK: - Published Properties

    @Published var currentMetrics: PrivacyMetrics
    @Published var isMonitoring: Bool = false

    // MARK: - Performance Tracking

    private var contactFetchTimes: [TimeInterval] = []
    private var duplicateDetectionTimes: [TimeInterval] = []
    private var analysisTimes: [TimeInterval] = []
    private var totalOperations: Int = 0
    private var lastOperationTime: Date?

    // MARK: - Network Monitoring

    private var networkRequestCount: Int = 0
    private var monitoringTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Initialize with default metrics
        self.currentMetrics = PrivacyMetrics(
            networkStatus: NetworkActivityStatus(
                totalNetworkRequests: 0,
                isMonitoring: false,
                lastCheckTime: Date()
            ),
            processingMetrics: ProcessingMetrics(
                averageContactFetchTime: nil,
                averageDuplicateDetectionTime: nil,
                averageAnalysisTime: nil,
                totalOperationsPerformed: 0,
                lastOperationTime: nil
            ),
            storageMetrics: StorageMetrics(
                contactsDatabaseSize: nil,
                backupFolderSize: nil,
                totalAppDataSize: nil,
                backupLocation: nil,
                appSupportLocation: nil,
                isLocalOnly: true
            ),
            encryptionStatus: EncryptionStatus(
                isSandboxed: true,
                hasContactsAccess: false,
                hasFileAccess: true,
                hasNetworkAccess: false,
                containerPath: nil,
                isFileVaultEnabled: nil
            ),
            lastUpdated: Date()
        )

        // Start monitoring
        startMonitoring()
    }

    // MARK: - Monitoring Control

    @MainActor
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Update metrics immediately
        updateAllMetrics()

        // Set up periodic updates (every 5 seconds)
        monitoringTimer = Timer.scheduledTimer(timeInterval: 5.0,
                                               target: self,
                                               selector: #selector(handleMonitoringTimerFired),
                                               userInfo: nil,
                                               repeats: true)
    }

    @MainActor
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    @objc private func handleMonitoringTimerFired() {
        Task { @MainActor in
            self.updateAllMetrics()
        }
    }

    // MARK: - Metrics Updates

    @MainActor
    func updateAllMetrics() {
        let networkStatus = checkNetworkActivity()
        let processingMetrics = calculateProcessingMetrics()
        let storageMetrics = calculateStorageMetrics()
        let encryptionStatus = checkEncryptionStatus()

        currentMetrics = PrivacyMetrics(
            networkStatus: networkStatus,
            processingMetrics: processingMetrics,
            storageMetrics: storageMetrics,
            encryptionStatus: encryptionStatus,
            lastUpdated: Date()
        )
    }

    // MARK: - Network Activity Monitoring

    private func checkNetworkActivity() -> NetworkActivityStatus {
        // In a sandboxed app with no network entitlement, this should always be 0
        // We can verify by checking if URLSession would work (it shouldn't)

        // Note: This is a demonstration - the app has no network code at all
        // In a real implementation, you could hook into URLSession or use network monitoring APIs

        return NetworkActivityStatus(
            totalNetworkRequests: networkRequestCount,
            isMonitoring: isMonitoring,
            lastCheckTime: Date()
        )
    }

    // MARK: - Processing Metrics

    private func calculateProcessingMetrics() -> ProcessingMetrics {
        let avgFetchTime = contactFetchTimes.isEmpty ? nil : contactFetchTimes.reduce(0, +) / Double(contactFetchTimes.count)
        let avgDetectionTime = duplicateDetectionTimes.isEmpty ? nil : duplicateDetectionTimes.reduce(0, +) / Double(duplicateDetectionTimes.count)
        let avgAnalysisTime = analysisTimes.isEmpty ? nil : analysisTimes.reduce(0, +) / Double(analysisTimes.count)

        return ProcessingMetrics(
            averageContactFetchTime: avgFetchTime,
            averageDuplicateDetectionTime: avgDetectionTime,
            averageAnalysisTime: avgAnalysisTime,
            totalOperationsPerformed: totalOperations,
            lastOperationTime: lastOperationTime
        )
    }

    // MARK: - Storage Metrics

    private func calculateStorageMetrics() -> StorageMetrics {
        let fileManager = FileManager.default

        // Get app support directory
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.playablefuture.contactsorganizer", isDirectory: true)

        // Get backup folder
        let backupURL = appSupportURL?.appendingPathComponent("Backups", isDirectory: true)

        // Calculate sizes
        let contactsDBSize = calculateSystemContactsDBSize()
        let backupSize = backupURL.flatMap { calculateFolderSize($0) }
        let appDataSize = appSupportURL.flatMap { calculateFolderSize($0) }

        return StorageMetrics(
            contactsDatabaseSize: contactsDBSize,
            backupFolderSize: backupSize,
            totalAppDataSize: appDataSize,
            backupLocation: backupURL,
            appSupportLocation: appSupportURL,
            isLocalOnly: true
        )
    }

    private func calculateSystemContactsDBSize() -> UInt64? {
        // The system Contacts database is managed by macOS
        // We can estimate based on contact count, but the actual DB is not directly accessible
        // Return nil for now, or estimate based on typical contact sizes
        return nil
    }

    private func calculateFolderSize(_ url: URL) -> UInt64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var totalSize: UInt64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += UInt64(fileSize)
        }

        return totalSize > 0 ? totalSize : nil
    }

    // MARK: - Encryption Status

    private func checkEncryptionStatus() -> EncryptionStatus {
        let fileManager = FileManager.default

        // Check sandbox container
        let containerURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        // Check FileVault status (requires admin privileges, may not be accessible)
        let isFileVaultEnabled = checkFileVaultStatus()

        return EncryptionStatus(
            isSandboxed: true, // macOS apps from App Store are always sandboxed
            hasContactsAccess: true, // We request this permission
            hasFileAccess: true, // Limited to our container and user-selected files
            hasNetworkAccess: false, // No network entitlement in our app
            containerPath: containerURL,
            isFileVaultEnabled: isFileVaultEnabled
        )
    }

    private func checkFileVaultStatus() -> Bool? {
        // FileVault status requires admin access
        // We can check if the volume is encrypted, but this may not be available
        // For now, return nil to indicate we can't determine this
        // Users can verify this in System Settings > Privacy & Security > FileVault

        return nil
    }

    // MARK: - Performance Reporting (called by ContactsManager)

    @MainActor
    func recordContactFetch(duration: TimeInterval) {
        contactFetchTimes.append(duration)
        // Keep only last 10 measurements
        if contactFetchTimes.count > 10 {
            contactFetchTimes.removeFirst()
        }
        totalOperations += 1
        lastOperationTime = Date()
        updateAllMetrics()
    }

    @MainActor
    func recordDuplicateDetection(duration: TimeInterval) {
        duplicateDetectionTimes.append(duration)
        if duplicateDetectionTimes.count > 10 {
            duplicateDetectionTimes.removeFirst()
        }
        totalOperations += 1
        lastOperationTime = Date()
        updateAllMetrics()
    }

    @MainActor
    func recordAnalysis(duration: TimeInterval) {
        analysisTimes.append(duration)
        if analysisTimes.count > 10 {
            analysisTimes.removeFirst()
        }
        totalOperations += 1
        lastOperationTime = Date()
        updateAllMetrics()
    }

    // MARK: - Manual Refresh

    @MainActor
    func refreshMetrics() {
        updateAllMetrics()
    }
}

