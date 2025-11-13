import Foundation

struct GroupMessageComposer {
    static func makeBody(for contacts: [ContactSummary], groupName: String, maxEntries: Int = 25) -> String {
        var lines: [String] = []
        lines.append("Contacts from \(groupName) (\(contacts.count)):\n")

        for contact in contacts.prefix(maxEntries) {
            var parts: [String] = [contact.fullName]
            if let org = contact.organization, !org.isEmpty {
                parts.append("(\(org))")
            }
            if let phone = contact.phoneNumbers.first, !phone.isEmpty {
                parts.append("☎︎ \(phone)")
            }
            if let email = contact.emailAddresses.first, !email.isEmpty {
                parts.append("✉︎ \(email)")
            }
            lines.append("• \(parts.joined(separator: " "))")
        }

        if contacts.count > maxEntries {
            lines.append("…and \(contacts.count - maxEntries) more")
        }

        return lines.joined(separator: "\n")
    }
}
