import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct DiagnosticsView: View {
    @EnvironmentObject var diagnostics: DiagnosticsCenter
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Diagnostics Console")
                    .font(.largeTitle.bold())
                Spacer()
                HStack(spacing: 8) {
                    Button("Copy All") {
                        copyAll()
                    }
                    .disabled(diagnostics.entries.isEmpty)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .help("Close diagnostics")
                }
            }

            if diagnostics.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(.green)
                    Text("No diagnostics logged yet.")
                        .foregroundColor(.secondary)
                    Text("When the app logs warnings, errors, or slow tasks, they’ll show up here automatically.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(diagnostics.entries) { entry in
                            DiagnosticsEntryRow(entry: entry)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: diagnostics.entries.count)
            }
        }
        .padding(24)
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minWidth: 520, minHeight: 420)
    }

    private func copyAll() {
        let lines = diagnostics.entries.map { entry in
            let time = entry.timestamp.formatted(date: .numeric, time: .standard)
            let meta = entry.metadata.map { " [\($0)]" } ?? ""
            return "[\(entry.severity.rawValue.uppercased())] \(time): \(entry.message)\(meta)"
        }
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        #endif
    }
}

private struct DiagnosticsEntryRow: View {
    let entry: DiagnosticsCenter.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SeverityBadge(severity: entry.severity)
                Spacer()
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(entry.message)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let metadata = entry.metadata {
                Text(metadata)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(entry.severity.tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(entry.severity.tint.opacity(0.35), lineWidth: 1)
                )
        )
        .contextMenu {
            Button("Copy entry") {
                copyEntry()
            }
        }
    }

    private func copyEntry() {
        #if canImport(AppKit)
        let time = entry.timestamp.formatted(date: .numeric, time: .standard)
        let meta = entry.metadata.map { " [\($0)]" } ?? ""
        let text = "[\(entry.severity.rawValue.uppercased())] \(time): \(entry.message)\(meta)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct SeverityBadge: View {
    let severity: DiagnosticsCenter.Entry.Severity

    var body: some View {
        Label(severity.rawValue.capitalized, systemImage: severity.iconName)
            .font(.caption.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(severity.tint.opacity(0.2), in: Capsule())
            .foregroundStyle(severity.tint)
    }
}
