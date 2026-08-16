//
//  SupporterBadgeView.swift
//  OpenVK for iOS
//
//  Бейджики тестера/донатера.
//

import SwiftUI

struct SupporterBadgeView: View {

    @ObservedObject private var supporters = SupportersService.shared

    let screenName: String?
    var size: CGFloat = 14

    var body: some View {
        if let iconURL = supporters.iconURL(screenName: screenName) {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Color.clear
                }
            }
            .frame(width: size, height: size)
        }
    }
}