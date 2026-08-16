//
//  LoginActionsView.swift
//  OpenVK for iOS
//

import SwiftUI

struct LoginActionsView: View {

    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.handleContinue) {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(viewModel.showPasswordField ? L10n.Auth.signIn : L10n.Auth.continue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.email.isEmpty
                              ? Color.appAccent.opacity(0.4)
                              : Color.appAccent)
                )
            }
            .disabled(!viewModel.canContinue)
            .animation(.easeInOut(duration: 0.2), value: viewModel.email.isEmpty)

            Button(action: {}) {
                Text(L10n.Auth.forgot)
                    .font(.system(size: 15))
                    .foregroundColor(.appAccent)
            }
            .padding(.top, 4)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
