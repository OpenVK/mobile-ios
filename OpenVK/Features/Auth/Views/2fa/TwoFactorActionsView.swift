//
//  TwoFactorActionsView.swift
//  OpenVK for iOS
//

import SwiftUI

struct TwoFactorActionsView: View {
    @ObservedObject var viewModel: TwoFactorViewModel

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task { await viewModel.verify() }
            }) {
                ZStack {
                    if viewModel.isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(L10n.TwoFactor.confirm)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.code.count < 6
                              ? Color.appAccent.opacity(0.4)
                              : Color.appAccent)
                )
            }
            .disabled(!viewModel.canConfirm)
            .animation(.easeInOut(duration: 0.2), value: viewModel.code.count == 6)

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }
}
