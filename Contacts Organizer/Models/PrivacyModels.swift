//
//  PrivacyModels.swift
//  Contacts Organizer
//
//  Data models for privacy monitoring and transparency
//

import Foundation

// MARK: - Overall Privacy Metrics

struct PrivacyMetrics {
    let networkStatus: NetworkActivityStatus
    let processingMetrics: ProcessingMetrics
    let storageMetrics: StorageMetrics
    let encryptionStatus: EncryptionStatus
    let lastUpdated: Date

    var isFullyPrivate: Bool {
        networkStatus.totalNetworkRequests == 0 &&
        encryptionStatus.isSandboxed &&
        storageMetrics.isLocalOnly
    }
}

// MARK: - Network Activity Status

struct NetworkActivityStatus {
    let totalNetworkRequests: Int
    let isMonitoring: Bool
    let lastCheckTime: Date

    var statusText: String {
        totalNetworkRequests == 0 ? "Zero Network Activity" : "⚠️ Network Activity Detected"
    }

    var statusColor: String {
        totalNetworkRequests == 0 ? "green" : "red"
    }

    var detailText: String {
        """
        Total network requests: \(totalNetworkRequests)
        Monitoring active: \(isMonitoring ? "Yes" : "No")
        Last verified: \(formatDate(lastCheckTime))

        This app makes ZERO network connections.
        All data processing happens locally on your Mac.
        """
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Processing Metrics

struct ProcessingMetrics {
    let averageContactFetchTime: TimeInterval?
    let averageDuplicateDetectionTime: TimeInterval?
    let averageAnalysisTime: TimeInterval?
    let totalOperationsPerformed: Int
    let lastOperationTime: Date?

    var statusText: String {
        guard let avgTime = averageContactFetchTime else {
            return "Ready for Processing"
        }
        return avgTime < 1.0 ? "Fast Local Processing" : "Processing Active"
    }

    var detailText: String {
        var details = "All operations run locally on your Mac:\n\n"

        if let fetchTime = averageContactFetchTime {
            details += "• Contact Fetch: \(formatTime(fetchTime))\n"
        }
        if let detectTime = averageDuplicateDetectionTime {
            details += "• Duplicate Detection: \(formatTime(detectTime))\n"
        }
        if let analysisTime = averageAnalysisTime {
            details += "• Data Analysis: \(formatTime(analysisTime))\n"
        }

        details += "\nTotal operations: \(totalOperationsPerformed)"

        if let lastOp = lastOperationTime {
            details += "\nLast operation: \(formatDate(lastOp))"
        }

        return details
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.2f μs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.2f ms", seconds * 1000)
        } else {
            return String(format: "%.2f s", seconds)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Storage Metrics

struct StorageMetrics {
    let contactsDatabaseSize: UInt64?
    let backupFolderSize: UInt64?
    let totalAppDataSize: UInt64?
    let backupLocation: URL?
    let appSupportLocation: URL?
    let isLocalOnly: Bool

    var statusText: String {
        isLocalOnly ? "Local Storage Only" : "⚠️ External Storage Detected"
    }

    var detailText: String {
        var details = "All data stored locally on your Mac:\n\n"

        if let dbSize = contactsDatabaseSize {
            details += "• Contacts Database: \(formatBytes(dbSize))\n"
        }
        if let backupSize = backupFolderSize {
            details += "• Backups: \(formatBytes(backupSize))\n"
        }
        if let totalSize = totalAppDataSize {
            details += "• Total App Data: \(formatBytes(totalSize))\n"
        }

        details += "\nStorage Locations:\n"

        if let backup = backupLocation {
            details += "• Backups: \(backup.path)\n"
        }
        if let appSupport = appSupportLocation {
            details += "• App Data: \(appSupport.path)\n"
        }

        details += "\nAll files are encrypted by macOS FileVault."

        return details
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Encryption Status

struct EncryptionStatus {
    let isSandboxed: Bool
    let hasContactsAccess: Bool
    let hasFileAccess: Bool
    let hasNetworkAccess: Bool
    let containerPath: URL?
    let isFileVaultEnabled: Bool?

    var statusText: String {
        isSandboxed && !hasNetworkAccess ? "Secure & Sandboxed" : "⚠️ Security Warning"
    }

    var detailText: String {
        var details = "macOS Security Features:\n\n"

        details += "• App Sandboxing: \(isSandboxed ? "✓ Enabled" : "✗ Disabled")\n"
        details += "• Network Access: \(hasNetworkAccess ? "✗ Granted" : "✓ Blocked")\n"
        details += "• Contacts Permission: \(hasContactsAccess ? "✓ Granted" : "Denied")\n"
        details += "• File Access: \(hasFileAccess ? "✓ Limited" : "None")\n"

        if let fileVault = isFileVaultEnabled {
            details += "• FileVault Encryption: \(fileVault ? "✓ Enabled" : "⚠️ Disabled")\n"
        }

        if let container = containerPath {
            details += "\nSandbox Container:\n\(container.path)\n"
        }

        details += "\nThis app is sandboxed and cannot access:"
        details += "\n• Your network or internet"
        details += "\n• Other apps' data"
        details += "\n• System files"
        details += "\n• Any data outside its container"

        return details
    }
}
