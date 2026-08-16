//
//  TwoFactorViewModel.swift
//  OpenVK for iOS
//

import Foundation
import Combine
import SwiftUI

enum TwoFactorMethod {
    case sms, email, totp

    var icon: String {
        switch self {
        case .sms:   return "message.fill"
        case .email: return "envelope.fill"
        case .totp:  return "lock.fill"
        }
    }
}

@MainActor
final class TwoFactorViewModel: ObservableObject {

    @Published var code: String = ""
    @Published var isVerifying: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String? = nil
    @Published var resendCountdown: Int = 30

    var canConfirm: Bool {
        code.count == 6 && !isVerifying
    }

    private var timerCancellable: AnyCancellable?

    func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        let i = code.index(code.startIndex, offsetBy: index)
        return String(code[i])
    }

    func handleInput(_ newValue: String) {
        let filtered = newValue.filter(\.isNumber)
        let trimmed = String(filtered.prefix(6))

        if trimmed != code {
            code = trimmed
        }

        if hasError && !trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) {
                hasError = false
                errorMessage = nil
            }
        }

        if trimmed.count == 6 {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await verify()
            }
        }
    }

    func verify() async {
        guard canConfirm else { return }

        isVerifying = true
        errorMessage = nil

        do {
            try await performVerification(code: code)
            isVerifying = false
        } catch {
            isVerifying = false
            withAnimation(.easeInOut(duration: 0.2)) {
                hasError = true
                errorMessage = L10n.TwoFactor.invalidCode
            }
            clearCode()
        }
    }
    
    private func clearCode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            code = ""
        }
    }

    private func performVerification(code: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            AuthService.shared.verifyTwoFactor(code: code) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
