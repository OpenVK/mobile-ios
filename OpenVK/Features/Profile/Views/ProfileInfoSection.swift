//
//  ProfileInfoSection.swift
//  OpenVK for iOS
//

import SwiftUI

struct ProfileInfoSection: View {

    let user: User
    var onTapDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if user.isGroup == true {
                if let about = user.about, !about.isEmpty {
                    ProfileInfoRow(icon: "doc.text", text: about)
                    Divider().padding(.leading, 44)
                }
                if let site = user.site, !site.isEmpty {
                    Button(action: {
                        if let url = URL(string: site) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        ProfileInfoRow(icon: "globe", text: site, isLink: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Divider().padding(.leading, 44)
                }
            } else {
                if let city = user.city {
                    ProfileInfoRow(icon: "house", text: "\(L10n.Profile.cityPrefix) \(city)")
                    Divider().padding(.leading, 44)
                }
            }
            Button(action: onTapDetails) {
                ProfileInfoRow(icon: "info.circle",
                               text: L10n.Profile.details,
                               isLink: true)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(Color(.systemBackground))
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let text: String
    var isPlaceholder: Bool = false
    var isLink: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(.secondaryLabel))
                .frame(width: 20)
                .padding(.leading, 16)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(isPlaceholder || isLink ? .appAccent : .primary)

            Spacer()

            if isLink {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 44)
    }
}
