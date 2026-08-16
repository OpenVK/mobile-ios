//
//  AudioListView.swift
//  OpenVK for iOS
//
//  Экран аудиозаписей.
//

import SwiftUI

struct AudioListView: View {

    let tracks: [AudioTrack]
    @State private var searchQuery = ""

    private var filteredTracks: [AudioTrack] {
        if searchQuery.isEmpty {
            return tracks
        }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artist.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredTracks) { track in
                    trackRow(track)
                        .padding(.horizontal, 16)
                    SectionSeparator()
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Аудиозаписи")
        .navigationBarTitleDisplayMode(.automatic)
        .customBackButton(title: "Назад")
        .searchable(text: $searchQuery, prompt: "Поиск")
    }

    private func trackRow(_ track: AudioTrack) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(track.color)
                Image(systemName: track.systemName)
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.duration)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct AudioListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioListView(tracks: [
                AudioTrack(title: "Тестовая аудиозапись", artist: "Тестовый артист", duration: "3:00", color: .blue)
            ])
        }
    }
}
