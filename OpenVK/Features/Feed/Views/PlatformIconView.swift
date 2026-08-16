//
//  PlatformIconView.swift
//  OpenVK for iOS
//
//  Иконка платформы.
//

import SwiftUI

struct PlatformIconView: View {
    let platform: String
    var size: CGFloat = 10
    var color: Color = Color(.tertiaryLabel)

    var body: some View {
        if let platformType = PostPlatform(rawValue: platform) {
            if let assetName = platformType.assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: size + 2)
                    .foregroundColor(color)
            } else {
                Image(systemName: platformType.iconName)
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        } else {
            Image(systemName: "globe")
                .font(.system(size: size))
                .foregroundColor(color)
        }
    }
}
