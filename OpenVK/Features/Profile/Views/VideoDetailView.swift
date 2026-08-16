//
//  VideoDetailView.swift
//  OpenVK for iOS
//
//  Экран видеозаписи.
//

import SwiftUI

struct VideoDetailView: View {

    let video: Video

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(video.color)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Color.white.opacity(0.92))
                }
                .aspectRatio(16/9, contentMode: .fill)
                .clipped()

                Text(video.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(video.duration)
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton(title: "Назад")
    }
}

struct VideoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VideoDetailView(video: Video(title: "Тестовое видео", duration: "10:00", color: .blue))
        }
    }
}
