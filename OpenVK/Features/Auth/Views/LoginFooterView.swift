//
//  LoginFooterView.swift
//  OpenVK for iOS
//

import SwiftUI

struct LoginFooterView: View {
    var body: some View {
        VStack(spacing: 16) {
            Divider()

            Text(L10n.Auth.noAccount)
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Button(action: openRegistration) {
                Text(L10n.Auth.createAccount)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appAccent)
            }

            Text(L10n.Auth.disclaimer)
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private func openRegistration() {
        let registrationURL = AppConfig.webBaseURL.appendingPathComponent("reg")
        UIApplication.shared.open(registrationURL)
    }
}
