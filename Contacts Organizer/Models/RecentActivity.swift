//
//  RecentActivity.swift
//  Contacts Organizer
//
//  Lightweight log entries for surfacing user actions in the dashboard.
//

import Foundation

struct RecentActivity: Identifiable, Codable {
    enum Kind: String, Codable {
        case smartGroupCreated
        case manualGroupCreated
        case duplicatesCleaned
        case healthAction
    }

    let id: UUID
    let kind: Kind
    let title: String
    let detail: String
    let icon: String
    let timestamp: Date

    init(id: UUID = UUID(), kind: Kind, title: String, detail: String, icon: String, timestamp: Date = Date()) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.icon = icon
        self.timestamp = timestamp
    }
}
