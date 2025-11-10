//
//  OnboardingView.swift
//  Contacts Organizer
//
//  Welcome and onboarding experience for new users
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var currentPage = 0
    @State private var hasLoggedBackupReminder = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "person.2.fill",
            title: "Welcome to Contacts Organizer",
            description: "Keep your contacts clean, organized, and up-to-date with intelligent automation.",
            color: .blue
        ),
        OnboardingPage(
            icon: "arrow.triangle.merge",
            title: "Find & Merge Duplicates",
            description: "Automatically detect and merge duplicate contacts using smart matching algorithms.",
            color: .green
        ),
        OnboardingPage(
            icon: "folder.fill",
            title: "Smart Organization",
            description: "Organize contacts into groups by location, company, or custom categories.",
            color: .orange
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "Data Quality",
            description: "Identify incomplete or problematic contacts and get suggestions for improvement.",
            color: .purple
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Privacy First",
            description: "All processing happens locally on your Mac. Your contact data never leaves your device.",
            color: .red
        ),
        OnboardingPage(
            icon: "externaldrive.fill.badge.timemachine",
            title: "Create a Backup First",
            description: "Before cleaning up large contact lists, export them or run a Time Machine backup so you can roll back changes.",
            color: .orange,
            isBackupReminder: true
        )
    ]

    private var backupPageIndex: Int? {
        pages.firstIndex(where: { $0.isBackupReminder })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page Content - macOS-compatible version
            ZStack {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        openSettingsAction: pages[index].isBackupReminder ? { openSettings() } : nil
                    )
                    .opacity(currentPage == index ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .frame(maxHeight: .infinity)

            // Page Indicators (manual dots for macOS)
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Navigation
            HStack(spacing: 20) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        appState.markBackupReminderSeen()
                        appState.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(30)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            handleBackupReminderIfNeeded(for: currentPage)
        }
        .onChange(of: currentPage) { _, newValue in
            handleBackupReminderIfNeeded(for: newValue)
        }
    }

    private func handleBackupReminderIfNeeded(for pageIndex: Int) {
        guard let backupPageIndex else { return }
        guard pageIndex == backupPageIndex else { return }
        guard !hasLoggedBackupReminder else { return }
        hasLoggedBackupReminder = true
        appState.markBackupReminderSeen()
    }
}

// MARK: - Onboarding Page

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isBackupReminder: Bool

    init(icon: String, title: String, description: String, color: Color, isBackupReminder: Bool = false) {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
        self.isBackupReminder = isBackupReminder
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let openSettingsAction: (() -> Void)?

    var body: some View {
        if page.isBackupReminder {
            backupReminderView
        } else {
            standardView
        }
    }

    private var standardView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: page.icon)
                .responsiveFont(80)
                .foregroundStyle(page.color.gradient)

            VStack(spacing: 16) {
                Text(page.title)
                    .responsiveFont(32, weight: .bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            Spacer()
        }
        .padding(40)
    }

    private var backupReminderView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .responsiveFont(64)
                .foregroundStyle(page.color.gradient)

            VStack(spacing: 12) {
                Text(page.title)
                    .responsiveFont(32, weight: .bold)
                    .multilineTextAlignment(.center)
                Text(page.description)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 520)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Open Settings → General → Backup All Contacts.", systemImage: "gearshape.fill")
                    .font(.headline)
                Text("A recent backup gives you room to experiment without worrying about mistakes.")
                    .foregroundColor(.secondary)

                if let openSettingsAction {
                    Button(action: openSettingsAction) {
                        Label("Open Settings to Back Up", systemImage: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )

            Spacer()
        }
        .padding(40)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
