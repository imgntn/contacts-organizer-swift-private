import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct DiagnosticsView: View {
    @EnvironmentObject var diagnostics: DiagnosticsCenter
    @State private var selection: DiagnosticsCenter.Entry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Diagnostics Console")
                    .font(.title2.bold())
                Spacer()
                Button("Copy All") {
                    copyAll()
                }
                .disabled(diagnostics.entries.isEmpty)
            }

            if diagnostics.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No diagnostics logged yet.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(diagnostics.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(entry.severity.rawValue.capitalized, systemImage: entry.severity.iconName)
                                .font(.headline)
                                .foregroundStyle(entry.severity.tint)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(entry.message)
                            .font(.body)
                        if let metadata = entry.metadata {
                            Text(metadata)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
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
