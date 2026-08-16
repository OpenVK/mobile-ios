//
//  TwoFactorFormView.swift
//  OpenVK for iOS
//

import SwiftUI

struct TwoFactorFormView: View {
    @ObservedObject var viewModel: TwoFactorViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            digitRow
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isFieldFocused = true
            }
            checkClipboardAndPaste()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkClipboardAndPaste()
        }
    }

    private func checkClipboardAndPaste() {
        if let clipboardString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           clipboardString.count == 6,
           clipboardString.allSatisfy(\.isNumber) {
            viewModel.code = clipboardString
        }
    }

    private var digitRow: some View {
        ZStack {
            hiddenTextField

            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    digitCell(at: index)

                    if index < 5 {
                        Divider()
                            .frame(height: 28)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func digitCell(at index: Int) -> some View {
        ZStack {
            if viewModel.digit(at: index).isEmpty {
                if index == viewModel.code.count && !viewModel.isVerifying {
                    BlinkingCursor()
                } else {
                    // Placeholder dot
                    Circle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 6, height: 6)
                        .opacity(0.4)
                }
            } else {
                Text(viewModel.digit(at: index))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(viewModel.hasError ? .red : .primary)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            isFieldFocused = true
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.code.count)
    }

    private var hiddenTextField: some View {
        TextField("", text: $viewModel.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .focused($isFieldFocused)
            .opacity(0.001)
            .frame(width: 1, height: 1)
            .onChange(of: viewModel.code) { newValue in
                viewModel.handleInput(newValue)
            }
    }
}

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Capsule()
            .fill(Color.appAccent)
            .frame(width: 2, height: 24)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
