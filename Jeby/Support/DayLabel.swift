//
//  DayLabel.swift
//  Jeby
//
//  A day written the way you'd say it: "Thursday, August 27th".
//

import Foundation

enum DayLabel {
    /// Formats the `day` the API returns for a feed ("2026-08-27").
    ///
    /// Returns nil if it isn't a date we can read, so the caller can fall back to
    /// today rather than render an empty subtitle.
    static func long(apiDay: String) -> String? {
        let parts = apiDay.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        // Noon rather than midnight: on a DST-shift day, midnight local can
        // resolve to the previous date and the header would be a day behind.
        components.hour = 12

        guard let date = Calendar.current.date(from: components) else { return nil }
        return long(date)
    }

    static func long(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let month = date.formatted(.dateTime.month(.wide))
        let day = Calendar.current.component(.day, from: date)
        return "\(weekday), \(month) \(day)\(ordinalSuffix(day))"
    }

    /// The English ordinal suffix. Built by hand because `Date.FormatStyle` has
    /// no ordinal day, and the usual alternative — `NumberFormatter.ordinal` —
    /// is a non-Sendable reference type we'd have to cache carefully.
    private static func ordinalSuffix(_ day: Int) -> String {
        // 11th/12th/13th break the last-digit rule.
        switch day {
        case 11, 12, 13:
            return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}
