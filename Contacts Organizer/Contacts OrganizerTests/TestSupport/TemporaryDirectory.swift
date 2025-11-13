import Foundation

struct TemporaryDirectory {
    let url: URL

    init(subdirectory: String = UUID().uuidString) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("ContactsOrganizerTests", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent(subdirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func fileURL(named name: String) -> URL {
        url.appendingPathComponent(name)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
