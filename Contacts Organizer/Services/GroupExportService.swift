//
//  GroupExportService.swift
//  Contacts Organizer
//
//  Service for exporting Smart Groups to various formats and integrating with system apps
//

import Foundation
import AppKit
import Contacts

class GroupExportService {
    static let shared = GroupExportService()
    #if DEBUG
    static var testDownloadsDirectory: URL?
    #endif

    private init() {}

    // MARK: - CSV Export

    /// Exports a group of contacts to CSV format
    func exportToCSV(contacts: [ContactSummary], groupName: String) -> URL? {
        let csvString = generateCSVString(contacts: contacts)

        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(groupName.replacingOccurrences(of: " ", with: "_"))_\(timestamp).csv"

        // Get Downloads folder
        #if DEBUG
        let downloadsURL = GroupExportService.testDownloadsDirectory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        #else
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        #endif

        guard let downloadsURL else {
            return nil
        }

        let fileURL = downloadsURL.appendingPathComponent(filename)

        // Write to file
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }

    func generateCSVString(contacts: [ContactSummary]) -> String {
        var csv = "Full Name,Organization,Phone Numbers,Email Addresses,Has Photo\n"

        for contact in contacts {
            let name = escapeCSVField(contact.fullName)
            let org = escapeCSVField(contact.organization ?? "")
            let phones = escapeCSVField(contact.phoneNumbers.joined(separator: "; "))
            let emails = escapeCSVField(contact.emailAddresses.joined(separator: "; "))
            let hasPhoto = contact.hasProfileImage ? "Yes" : "No"

            csv += "\(name),\(org),\(phones),\(emails),\(hasPhoto)\n"
        }

        return csv
    }

    private func escapeCSVField(_ field: String) -> String {
        // Wrap in quotes if contains comma, newline, or quote
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            // Escape quotes by doubling them
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Mail Integration

    /// Opens Mail.app with a new message addressed to all contacts in the group
    func openInMail(contacts: [ContactSummary], groupName: String) -> Bool {
        // Collect all email addresses
        let allEmails = contacts.flatMap { $0.emailAddresses }

        guard !allEmails.isEmpty else {
            print("No email addresses found in group")
            return false
        }

        // Create mailto URL
        // Use BCC to protect privacy (recipients can't see each other)
        let emailList = allEmails.joined(separator: ",")
        let subject = "Message from \(groupName)"

        // URL encode the components
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEmails = emailList.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        // Use BCC for privacy
        let mailtoString = "mailto:?bcc=\(encodedEmails)&subject=\(encodedSubject)"

        guard let mailtoURL = URL(string: mailtoString) else {
            return false
        }

        // Open in Mail.app
        NSWorkspace.shared.open(mailtoURL)
        return true
    }

    /// Creates a vCard file and opens it in Mail as an attachment
    func sendAsVCard(contacts: [ContactSummary], groupName: String) -> Bool {
        // This requires CNContact objects, not just summaries
        // We'll use a different approach: create a .vcf file and let user attach it

        let vCardPath = createVCardFile(contacts: contacts, groupName: groupName)

        guard let path = vCardPath else {
            return false
        }

        // Open the file - macOS will ask if user wants to add to Contacts or share
        NSWorkspace.shared.open(path)
        return true
    }

    func createVCardFile(contacts: [ContactSummary], groupName: String) -> URL? {
        // Create a simple vCard 3.0 format
        var vCardString = ""

        for contact in contacts {
            vCardString += "BEGIN:VCARD\n"
            vCardString += "VERSION:3.0\n"
            vCardString += "FN:\(contact.fullName)\n"

            if let org = contact.organization {
                vCardString += "ORG:\(org)\n"
            }

            for (index, email) in contact.emailAddresses.enumerated() {
                let type = index == 0 ? "WORK" : "HOME"
                vCardString += "EMAIL;TYPE=\(type):\(email)\n"
            }

            for (index, phone) in contact.phoneNumbers.enumerated() {
                let type = index == 0 ? "WORK" : "HOME"
                vCardString += "TEL;TYPE=\(type):\(phone)\n"
            }

            vCardString += "END:VCARD\n"
        }

        // Save to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(groupName.replacingOccurrences(of: " ", with: "_")).vcf"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try vCardString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error creating vCard: \(error)")
            return nil
        }
    }

    func generateVCardString(contacts: [ContactSummary]) -> String {
        var vCardString = ""

        for contact in contacts {
            vCardString += "BEGIN:VCARD\n"
            vCardString += "VERSION:3.0\n"
            vCardString += "FN:\(contact.fullName)\n"

            if let org = contact.organization {
                vCardString += "ORG:\(org)\n"
            }

            for (index, email) in contact.emailAddresses.enumerated() {
                let type = index == 0 ? "WORK" : "HOME"
                vCardString += "EMAIL;TYPE=\(type):\(email)\n"
            }

            for (index, phone) in contact.phoneNumbers.enumerated() {
                let type = index == 0 ? "WORK" : "HOME"
                vCardString += "TEL;TYPE=\(type):\(phone)\n"
            }

            vCardString += "END:VCARD\n"
        }

        return vCardString
    }

    // MARK: - Messages Integration

    /// Opens Messages.app to create a group chat with all contacts who have phone numbers
    func openInMessages(contacts: [ContactSummary], groupName: String) -> Bool {
        // Collect all phone numbers
        let allPhones = contacts.flatMap { $0.phoneNumbers }

        guard !allPhones.isEmpty else {
            print("No phone numbers found in group")
            return false
        }

        // Messages URL scheme
        // Format: sms:phone1,phone2,phone3&body=message
        let phoneList = allPhones.prefix(10).joined(separator: ",") // Limit to 10 for practicality

        let message = "Group message from \(groupName)"
        guard let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPhones = phoneList.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        let smsString = "sms:\(encodedPhones)&body=\(encodedMessage)"

        guard let smsURL = URL(string: smsString) else {
            return false
        }

        // Open in Messages.app
        NSWorkspace.shared.open(smsURL)
        return true
    }

    // MARK: - iMessage Group (Advanced)

    /// Opens Messages.app with a pre-populated group using iMessage handles
    func createiMessageGroup(contacts: [ContactSummary], groupName: String) -> Bool {
        // Prefer email addresses for iMessage (works better than phone numbers)
        let handles = contacts.flatMap { contact -> [String] in
            // Prefer emails for iMessage, fallback to phone numbers
            if !contact.emailAddresses.isEmpty {
                return contact.emailAddresses
            } else {
                return contact.phoneNumbers
            }
        }

        guard !handles.isEmpty else {
            print("No contact information found")
            return false
        }

        // Use the first 10 handles for practicality
        let limitedHandles = handles.prefix(10).joined(separator: ",")

        guard let encodedHandles = limitedHandles.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        // Messages URL scheme for iMessage
        let imessageString = "imessage:\(encodedHandles)"

        guard let imessageURL = URL(string: imessageString) else {
            return false
        }

        NSWorkspace.shared.open(imessageURL)
        return true
    }

    // MARK: - Export Summary

    struct ExportResult {
        let success: Bool
        let fileURL: URL?
        let message: String
    }

    func performExport(type: ExportType, contacts: [ContactSummary], groupName: String) -> ExportResult {
        switch type {
        case .csv:
            if let url = exportToCSV(contacts: contacts, groupName: groupName) {
                return ExportResult(success: true, fileURL: url, message: "Exported \(contacts.count) contacts to CSV")
            } else {
                return ExportResult(success: false, fileURL: nil, message: "Failed to export CSV")
            }

        case .mail:
            let success = openInMail(contacts: contacts, groupName: groupName)
            return ExportResult(
                success: success,
                fileURL: nil,
                message: success ? "Opened Mail with \(contacts.count) recipients" : "No email addresses found"
            )

        case .messages:
            let success = openInMessages(contacts: contacts, groupName: groupName)
            return ExportResult(
                success: success,
                fileURL: nil,
                message: success ? "Opened Messages with \(contacts.count) contacts" : "No phone numbers found"
            )

        case .imessage:
            let success = createiMessageGroup(contacts: contacts, groupName: groupName)
            return ExportResult(
                success: success,
                fileURL: nil,
                message: success ? "Opened iMessage group chat" : "No contact information found"
            )
        }
    }

    enum ExportType: String, CaseIterable {
        case csv = "CSV File"
        case mail = "Mail (BCC)"
        case messages = "Messages"
        case imessage = "iMessage Group"

        var icon: String {
            switch self {
            case .csv: return "doc.text"
            case .mail: return "envelope"
            case .messages: return "message"
            case .imessage: return "message.fill"
            }
        }

        var description: String {
            switch self {
            case .csv: return "Export to CSV file"
            case .mail: return "Send email to all (BCC)"
            case .messages: return "Create SMS group"
            case .imessage: return "Create iMessage group"
            }
        }
    }
}
