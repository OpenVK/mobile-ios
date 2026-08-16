//
//  OpenVKDateFormatter.swift
//  OpenVK for iOS
//
//  Форматирование дат и времени
//

import Foundation

enum OpenVKDateFormatter {

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "HH:mm"
        return df
    }()

    private static let currentYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMM"
        return df
    }()

    private static let otherYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    /// Форматируем дату публикации поста, комментария, видео и др.
    ///
    /// - "только что" (< 1 мин)
    /// - "ровно 5 минут назад"
    /// - "3 минуты назад"
    /// - "сегодня в 14:32"
    /// - "вчера в 23:10"
    /// - "13 авг в 20:15"
    /// - "15 мая 2021 в 16:30"
    static func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // (< 0)
        if interval < 0 {
            let timeStr = timeFormatter.string(from: date)
            if calendar.isDateInToday(date) {
                return "сегодня в \(timeStr)"
            }
            let dateStr = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? currentYearFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
                : otherYearFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
            return "\(dateStr) в \(timeStr)"
        }

        let minutesAgo = Int(interval / 60)

        // в пределах сегодняшнего дня
        if calendar.isDateInToday(date) {
            if minutesAgo < 1 {
                return "только что"
            } else if minutesAgo == 5 {
                return "ровно 5 минут назад"
            } else if minutesAgo < 60 {
                return formatMinutesAgo(minutesAgo)
            } else {
                return "сегодня в \(timeFormatter.string(from: date))"
            }
        }

        // Вчера
        if calendar.isDateInYesterday(date) {
            return "вчера в \(timeFormatter.string(from: date))"
        }

        let timeStr = timeFormatter.string(from: date)

        // В этом году
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let dateStr = currentYearFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
            return "\(dateStr) в \(timeStr)"
        } else {
            // В прошлых годах
            let dateStr = otherYearFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
            return "\(dateStr) в \(timeStr)"
        }
    }

    /// Форматирует время последнего онлайна с учетом пола пользователя
    /// (например: "был сегодня в 14:32", "была вчера в 18:00", "был 12 апр в 20:00")
    static func formatLastSeen(_ date: Date, sex: Int? = nil) -> String {
        let prefix: String
        switch sex {
        case 1: // female
            prefix = "была "
        case 2: // male
            prefix = "был "
        default:
            prefix = "был(а) "
        }

        let relative = formatRelative(date)
        return prefix + relative
    }

    private static func formatMinutesAgo(_ minutes: Int) -> String {
        let mod10 = minutes % 10
        let mod100 = minutes % 100
        let word: String
        if mod100 >= 11 && mod100 <= 19 {
            word = "минут"
        } else if mod10 == 1 {
            word = "минуту"
        } else if mod10 >= 2 && mod10 <= 4 {
            word = "минуты"
        } else {
            word = "минут"
        }
        return "\(minutes) \(word) назад"
    }
}

extension Date {
    func openvkFormatted() -> String {
        OpenVKDateFormatter.formatRelative(self)
    }

    func openvkLastSeen(sex: Int? = nil) -> String {
        OpenVKDateFormatter.formatLastSeen(self, sex: sex)
    }
}
