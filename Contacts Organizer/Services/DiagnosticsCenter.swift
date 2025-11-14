import Foundation
import SwiftUI
import Combine

struct DiagnosticsThresholds {
    nonisolated(unsafe) static var duplicateDetection: TimeInterval = 0.75
    nonisolated(unsafe) static var smartGroupGeneration: TimeInterval = 0.5
    nonisolated(unsafe) static var changeHistoryRefresh: TimeInterval = 1.0
}

@MainActor
final class DiagnosticsCenter: ObservableObject {
    static let shared = DiagnosticsCenter()

    struct Entry: Identifiable, Equatable {
        enum Severity: String {
            case info
            case warning
            case error

            var iconName: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.octagon"
                }
            }

            var tint: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                }
            }
        }

        let id = UUID()
        let timestamp: Date
        let severity: Severity
        let message: String
        let metadata: String?
    }

    @Published private(set) var entries: [Entry] = []
    private let maxEntries = 200

    func record(_ message: String, severity: Entry.Severity = .info, metadata: String? = nil) {
        let entry = Entry(timestamp: Date(), severity: severity, message: message, metadata: metadata)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func recordPerformance(operation: String, duration: TimeInterval, threshold: TimeInterval) {
        guard duration >= threshold else { return }
        let formatted = String(format: "%.2fs", duration)
        record(
            "\(operation) completed in \(formatted)",
            severity: .warning,
            metadata: "Threshold \(threshold)s"
        )
    }

    func resetForTesting() {
        entries.removeAll()
    }
}

extension DiagnosticsCenter {
    nonisolated static func log(_ message: String, severity: Entry.Severity = .info, metadata: String? = nil) {
        Task { @MainActor in
            DiagnosticsCenter.shared.record(message, severity: severity, metadata: metadata)
        }
    }

    nonisolated static func logPerformance(operation: String, duration: TimeInterval, threshold: TimeInterval) {
        Task { @MainActor in
            DiagnosticsCenter.shared.recordPerformance(operation: operation, duration: duration, threshold: threshold)
        }
    }
}
