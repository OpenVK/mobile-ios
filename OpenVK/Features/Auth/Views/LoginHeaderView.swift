//
//  LoginHeaderView.swift
//  OpenVK for iOS
//

import SwiftUI

struct LoginHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("logo")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 6) {
                Text(L10n.Auth.welcome)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)

                Text(L10n.Auth.subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }
}
