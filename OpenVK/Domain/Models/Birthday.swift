//
//  Birthday.swift
//  OpenVK for iOS
//
//  День рождения друга и дата его ближайшего наступления.
//

import Foundation

struct Birthday: Identifiable, Hashable {

    let id: UUID
    let user: User
    let day: Int
    let month: Int
    let year: Int?
    let nextDate: Date

    // MARK: - Proximity

    var daysUntil: Int {
        let calendar = Calendar.current
        let startToday = calendar.startOfDay(for: Date())
        let startNext = calendar.startOfDay(for: nextDate)
        return calendar.dateComponents([.day], from: startToday, to: startNext).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }
    var isTomorrow: Bool { daysUntil == 1 }

    // MARK: - Display

    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: nextDate)
    }

    var relativeText: String {
        switch daysUntil {
        case 0: return "Сегодня"
        case 1: return "Завтра"
        default: return dateText
        }
    }

    var upcomingAge: Int? {
        guard let year = year else { return nil }
        let calendar = Calendar.current
        return calendar.component(.year, from: nextDate) - year
    }

    // MARK: - Parsing

    static func parse(bdate: String?, user: User) -> Birthday? {
        guard let bdate = bdate, !bdate.isEmpty else { return nil }
        let parts = bdate.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let day = parts[0]
        let month = parts[1]
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.dateComponents([.month, .day], from: now)

        let nextDate: Date
        if today.day == day && today.month == month {
            nextDate = now
        } else {
            var components = DateComponents()
            components.month = month
            components.day = day
            nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        }

        return Birthday(
            id: UUID(),
            user: user,
            day: day,
            month: month,
            year: parts.count >= 3 ? parts[2] : nil,
            nextDate: nextDate
        )
    }
}
