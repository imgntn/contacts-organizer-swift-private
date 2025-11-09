//
//  OnboardingView.swift
//  Contacts Organizer
//
//  Welcome and onboarding experience for new users
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

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
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page Content - macOS-compatible version
            ZStack {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
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
                        appState.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(30)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Onboarding Page

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
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
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
