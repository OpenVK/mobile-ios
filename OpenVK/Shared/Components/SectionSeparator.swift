//
//  SectionSeparator.swift
//  OpenVK for iOS
//

import SwiftUI

struct SectionSeparator: View {
    var height: CGFloat = 0.5
    var opacity: Double = 1.0

    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: height)
            .opacity(opacity)
    }
}

struct SectionSpacer: View {
    var height: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(Color(.systemGroupedBackground))
            .frame(height: height)
    }
}
