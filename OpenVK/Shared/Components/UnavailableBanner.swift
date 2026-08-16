//
//  UnavailableBanner.swift
//  OpenVK for iOS
//

import SwiftUI

struct UnavailableBanner: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))

            Text(L10n.More.unavailable)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

// Экран-заглушка «В разработке»
struct UnderDevelopmentView: View {
    let section: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("В разработке")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Text("Раздел «\(section)» находится на стадии разработки и будет доступен в следующих версиях.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct UnavailableBanner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UnavailableBanner()
                .preferredColorScheme(.light)
                .previewDisplayName("Light")
            UnavailableBanner()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }
}
