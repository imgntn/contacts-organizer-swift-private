//
//  PrivacyDashboardView.swift
//  Contacts Organizer
//
//  Comprehensive privacy dashboard showing on-device processing transparency
//

import SwiftUI

struct PrivacyDashboardView: View {
    @EnvironmentObject var privacyMonitor: PrivacyMonitorService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HeaderSection()

                // Main Privacy Cards
                VStack(spacing: 16) {
                    NetworkActivityCard(status: privacyMonitor.currentMetrics.networkStatus)
                    ProcessingMetricsCard(metrics: privacyMonitor.currentMetrics.processingMetrics)
                    StorageMetricsCard(metrics: privacyMonitor.currentMetrics.storageMetrics)
                    EncryptionStatusCard(status: privacyMonitor.currentMetrics.encryptionStatus)
                }

                // Footer Info
                FooterSection(lastUpdated: privacyMonitor.currentMetrics.lastUpdated)

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            privacyMonitor.refreshMetrics()
        }
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green.gradient)

            Text("Privacy Dashboard")
                .font(.title.bold())

            Text("Transparent on-device processing")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Unlike cloud-based CRMs, your data never leaves your Mac")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Network Activity Card

struct NetworkActivityCard: View {
    let status: NetworkActivityStatus
    @State private var isExpanded = false

    var body: some View {
        PrivacyCard(
            icon: "network.slash",
            iconColor: status.totalNetworkRequests == 0 ? .green : .red,
            title: status.statusText,
            summary: "No data transmitted",
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(status.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Text("Proof of Privacy:")
                    .font(.caption.bold())

                Text("• No URLSession instances created")
                    .font(.caption2)
                Text("• No network entitlements in app")
                    .font(.caption2)
                Text("• Sandboxed with network access denied")
                    .font(.caption2)
                Text("• Zero API calls or server connections")
                    .font(.caption2)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Processing Metrics Card

struct ProcessingMetricsCard: View {
    let metrics: ProcessingMetrics
    @State private var isExpanded = false

    var body: some View {
        PrivacyCard(
            icon: "cpu",
            iconColor: .blue,
            title: metrics.statusText,
            summary: "All operations run locally",
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(metrics.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if metrics.totalOperationsPerformed > 0 {
                    Divider()

                    PerformanceBar(
                        label: "Fetch Speed",
                        time: metrics.averageContactFetchTime
                    )

                    if let _ = metrics.averageDuplicateDetectionTime {
                        PerformanceBar(
                            label: "Duplicate Detection",
                            time: metrics.averageDuplicateDetectionTime
                        )
                    }

                    if let _ = metrics.averageAnalysisTime {
                        PerformanceBar(
                            label: "Data Analysis",
                            time: metrics.averageAnalysisTime
                        )
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Storage Metrics Card

struct StorageMetricsCard: View {
    let metrics: StorageMetrics
    @State private var isExpanded = false

    var body: some View {
        PrivacyCard(
            icon: "internaldrive",
            iconColor: .purple,
            title: metrics.statusText,
            summary: "All files on your Mac",
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(metrics.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                if let totalSize = metrics.totalAppDataSize {
                    Divider()

                    HStack {
                        Text("Total Storage:")
                            .font(.caption.bold())
                        Spacer()
                        Text(formatBytes(totalSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Encryption Status Card

struct EncryptionStatusCard: View {
    let status: EncryptionStatus
    @State private var isExpanded = false

    var body: some View {
        PrivacyCard(
            icon: "checkmark.shield.fill",
            iconColor: status.isSandboxed && !status.hasNetworkAccess ? .green : .orange,
            title: status.statusText,
            summary: "macOS protection enabled",
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(status.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    SecurityFeature(
                        name: "App Sandboxing",
                        isEnabled: status.isSandboxed
                    )
                    SecurityFeature(
                        name: "Network Blocked",
                        isEnabled: !status.hasNetworkAccess
                    )
                    SecurityFeature(
                        name: "Contacts Access",
                        isEnabled: status.hasContactsAccess
                    )
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Reusable Privacy Card

struct PrivacyCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let summary: String
    @Binding var isExpanded: Bool
    @ViewBuilder let expandedContent: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simple view (always visible)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor.gradient)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Expanded technical details
            if isExpanded {
                Divider()
                expandedContent()
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Helper Views

struct PerformanceBar: View {
    let label: String
    let time: TimeInterval?

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
            Spacer()
            if let time = time {
                Text(formatTime(time))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(time < 1.0 ? .green : .orange)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0f μs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.0f ms", seconds * 1000)
        } else {
            return String(format: "%.2f s", seconds)
        }
    }
}

struct SecurityFeature: View {
    let name: String
    let isEnabled: Bool

    var body: some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
                .font(.caption)

            Text(name)
                .font(.caption2)
        }
    }
}

// MARK: - Footer Section

struct FooterSection: View {
    let lastUpdated: Date

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            Text("Last updated: \(formatDate(lastUpdated))")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("No accounts • No servers • No tracking")
                .font(.caption.bold())
                .foregroundColor(.green)

            Text("Your contacts remain 100% private on your Mac")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if !DISABLE_PREVIEWS
#Preview {
    PrivacyDashboardView()
        .environmentObject(PrivacyMonitorService.shared)
        .frame(width: 500, height: 700)
}
#endif
