//
//  SupportersListView.swift
//  OpenVK for iOS
//
//  Список тестеров и донатеров из раздела «Другие».
//

import SwiftUI

struct SupportersListView: View {

    @ObservedObject private var supporters = SupportersService.shared

    var body: some View {
        List {
            Section(header: Text("Тестеры")) {
                if supporters.testers.isEmpty {
                    loadingRow
                } else {
                    ForEach(supporters.testers) { supporter in
                        supporterRow(supporter)
                    }
                }
            }

            Section(header: Text("Донатеры")) {
                if supporters.donors.isEmpty {
                    loadingRow
                } else {
                    ForEach(supporters.donors) { supporter in
                        supporterRow(supporter)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Другие")
        .onAppear {
            SupportersService.shared.refreshIfNeeded()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func supporterRow(_ supporter: Supporter) -> some View {
        HStack(alignment: .top, spacing: 12) {
            supporterIcon(supporter)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(supporter.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    if let nick = supporter.nick, !nick.isEmpty, nick != supporter.name {
                        Text("@\(nick)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                if let amount = supporter.amount, !amount.isEmpty {
                    Text(amount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appAccent)
                }

                if let message = supporter.message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let profiles = supporter.profiles, !profiles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(profiles, id: \.self) { profile in
                            if let url = URL(string: profile) {
                                Link(destination: url) {
                                    Text(profile
                                        .replacingOccurrences(of: "https://", with: "")
                                        .replacingOccurrences(of: "http://", with: ""))
                                        .font(.system(size: 12))
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func supporterIcon(_ supporter: Supporter) -> some View {
        Group {
            if let icon = supporter.icon, !icon.isEmpty, let url = URL(string: icon) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.secondaryLabel))
            )
    }
}