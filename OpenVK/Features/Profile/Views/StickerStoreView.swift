//
//  StickerStoreView.swift
//  OpenVK for iOS
//
//  Раздел «Магазин стикеров».
//

import SwiftUI

struct StickerStoreView: View {
    enum Section: String, CaseIterable, Identifiable {
        case featured = "Главное"
        case acquired = "Приобретённые"
        var id: String { rawValue }
    }

    @State private var selectedSection: Section = .featured
    @State private var acquiredIDs: Set<Int> = [1, 4, 12, 16]

    private let popularPacks = StickerPack.popular
    private let freePacks = StickerPack.free

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел магазина", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                if selectedSection == .featured {
                    featuredContent
                } else {
                    StickerPackGrid(
                        packs: allPacks.filter { acquiredIDs.contains($0.id) },
                        acquiredIDs: acquiredIDs,
                        onPurchase: acquire
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Магазин стикеров")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var featuredContent: some View {
        VStack(spacing: 22) {
            StickerPackShelf(
                title: "Популярные",
                packs: popularPacks,
                acquiredIDs: $acquiredIDs,
                onPurchase: acquire
            )

            StickerPackShelf(
                title: "Бесплатные",
                packs: freePacks,
                acquiredIDs: $acquiredIDs,
                onPurchase: acquire
            )

            NavigationLink {
                StickerPackListView(
                    title: "Все стикерпаки",
                    packs: allPacks,
                    acquiredIDs: $acquiredIDs
                )
            } label: {
                Label("Все стикерпаки", systemImage: "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private var allPacks: [StickerPack] { popularPacks + freePacks }

    private func acquire(_ pack: StickerPack) {
        acquiredIDs.insert(pack.id)
    }
}

private struct StickerPackShelf: View {
    let title: String
    let packs: [StickerPack]
    @Binding var acquiredIDs: Set<Int>
    let onPurchase: (StickerPack) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                Spacer()
                NavigationLink {
                    StickerPackListView(title: title, packs: packs, acquiredIDs: $acquiredIDs)
                } label: {
                    Text("Показать все")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(packs) { pack in
                        StickerPackCard(
                            pack: pack,
                            isAcquired: acquiredIDs.contains(pack.id),
                            compact: true,
                            onPurchase: { onPurchase(pack) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct StickerPackListView: View {
    let title: String
    let packs: [StickerPack]
    @Binding var acquiredIDs: Set<Int>

    var body: some View {
        ScrollView {
            StickerPackGrid(packs: packs, acquiredIDs: acquiredIDs) { pack in
                acquiredIDs.insert(pack.id)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StickerPackGrid: View {
    let packs: [StickerPack]
    let acquiredIDs: Set<Int>
    let onPurchase: (StickerPack) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 185), spacing: 14)]

    var body: some View {
        if packs.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Нет приобретённых наборов")
                    .font(.headline)
                Text("Приобретённые стикерпаки появятся здесь.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
                .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(packs) { pack in
                    StickerPackCard(
                        pack: pack,
                        isAcquired: acquiredIDs.contains(pack.id),
                        compact: false,
                        onPurchase: { onPurchase(pack) }
                    )
                }
            }
        }
    }
}

private struct StickerPackCard: View {
    let pack: StickerPack
    let isAcquired: Bool
    let compact: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            StickerPackCover(pack: pack)
                .frame(height: compact ? 116 : 148)

            Text(pack.name)
                .font(compact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .lineLimit(1)

            Text(pack.priceText)
                .font(compact ? .caption : .footnote)
                .foregroundStyle(Color.appAccent)

            if !compact {
                if isAcquired {
                    Text("Приобретён")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    Button("Приобрести", action: onPurchase)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(Color.appAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: compact ? 145 : nil, alignment: .leading)
        .padding(compact ? 0 : 10)
        .background(compact ? Color.clear : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StickerPackCover: View {
    let pack: StickerPack

    var body: some View {
        ZStack {
            LinearGradient(colors: pack.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 94, height: 94)
                .offset(x: 35, y: -32)
            Text(pack.emoji)
                .font(.system(size: 58))
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct StickerPack: Identifiable {
    let id: Int
    let name: String
    let emoji: String
    let price: Int
    let colors: [Color]

    var priceText: String { price == 0 ? "Бесплатно" : "\(price) голосов" }

    static let popular: [StickerPack] = [
        StickerPack(id: 1, name: "Космики", emoji: "👾", price: 100, colors: [.purple, .indigo]),
        StickerPack(id: 2, name: "Лапки", emoji: "🐾", price: 100, colors: [.orange, .pink]),
        StickerPack(id: 3, name: "Мишки", emoji: "🧸", price: 100, colors: [.brown, .orange]),
        StickerPack(id: 4, name: "Пушистики", emoji: "🐱", price: 100, colors: [.mint, .teal]),
        StickerPack(id: 5, name: "Роботы", emoji: "🤖", price: 100, colors: [.cyan, .blue]),
        StickerPack(id: 6, name: "Облачка", emoji: "☁️", price: 100, colors: [.blue, .indigo]),
        StickerPack(id: 7, name: "Вкусно", emoji: "🍩", price: 100, colors: [.pink, .purple]),
        StickerPack(id: 8, name: "Лисички", emoji: "🦊", price: 100, colors: [.orange, .red]),
        StickerPack(id: 9, name: "Смайлы", emoji: "😎", price: 100, colors: [.yellow, .orange]),
        StickerPack(id: 10, name: "Динозавры", emoji: "🦕", price: 100, colors: [.green, .mint])
    ]

    static let free: [StickerPack] = [
        StickerPack(id: 11, name: "Первые", emoji: "👋", price: 0, colors: [.blue, .cyan]),
        StickerPack(id: 12, name: "Котята", emoji: "😸", price: 0, colors: [.pink, .orange]),
        StickerPack(id: 13, name: "Фрукты", emoji: "🍓", price: 0, colors: [.red, .pink]),
        StickerPack(id: 14, name: "Цветочки", emoji: "🌻", price: 0, colors: [.yellow, .orange]),
        StickerPack(id: 15, name: "Приветы", emoji: "🙌", price: 0, colors: [.teal, .cyan]),
        StickerPack(id: 16, name: "Собачки", emoji: "🐶", price: 0, colors: [.brown, .orange]),
        StickerPack(id: 17, name: "Сладости", emoji: "🍭", price: 0, colors: [.purple, .pink]),
        StickerPack(id: 18, name: "Звёздочки", emoji: "⭐️", price: 0, colors: [.yellow, .red]),
        StickerPack(id: 19, name: "Гейминг", emoji: "🎮", price: 0, colors: [.indigo, .purple]),
        StickerPack(id: 20, name: "Каникулы", emoji: "🏖️", price: 0, colors: [.cyan, .mint])
    ]
}


