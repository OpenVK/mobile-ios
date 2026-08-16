//
//  TwoFactorView.swift
//  OpenVK for iOS
//

import SwiftUI

struct TwoFactorView: View {
    @StateObject private var viewModel = TwoFactorViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        TwoFactorHeaderView()
                            .padding(.top, 60)
                            .padding(.bottom, 40)

                        TwoFactorFormView(viewModel: viewModel)
                            .padding(.horizontal, 24)

                        TwoFactorActionsView(viewModel: viewModel)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)

                        Spacer(minLength: 48)

                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct TwoFactorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TwoFactorView().preferredColorScheme(.light).previewDisplayName("Light")
            TwoFactorView().preferredColorScheme(.dark).previewDisplayName("Dark")
        }
    }
}
