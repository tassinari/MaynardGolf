//
//  DisplayFormatting.swift
//  MaynardUI
//

import Foundation

/// Display text for containers and rows (00-design-system §7.4). Pure and locale-aware, so it's
/// unit-tested at 100 % with the rest of `Formatting/`.
public enum DisplayFormatting {
    /// A handicap index as golfers write it: "12.4", "0.0", plus handicaps (stored negative) as "+2.1",
    /// and an em dash when there's no index (DM-PL-06).
    /// The value is rounded to one decimal before its sign is read, so −0.04 is "0.0", not "+0.0".
    public static func handicapIndex(_ index: Double?, locale: Locale = .current) -> String {
        guard let index else { return "—" }
        let rounded = (index * 10).rounded() / 10
        let magnitude = abs(rounded).formatted(.number.precision(.fractionLength(1)).locale(locale))
        return rounded < 0 ? "+\(magnitude)" : magnitude
    }

    /// "· 2 of 4" after a section title (DS-CN-02).
    public static func countSubtitle(_ count: Int, of total: Int) -> String {
        String(localized: "· \(count) of \(total)", bundle: Bundle.maynardUI, comment: "Count after a section title, e.g. PLAYERS · 2 OF 4. Shown in caps.")
    }

    /// The date block on a round row (DS-CN-04): a caps label over the day number.
    public enum DateBlockStyle: Sendable {
        /// Month over day ("NOV" / "15"), on Home.
        case month
        /// Weekday over day ("SAT" / "15"), in All rounds and the Player card.
        case weekday
    }

    /// The label (month or weekday, abbreviated) and day of the month for a round's date.
    public static func dateBlock(_ date: Date, style: DateBlockStyle, calendar: Calendar = .current,
                                 locale: Locale = .current) -> (label: String, day: String) {
        var format = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).locale(locale)
        format = style == .month ? format.month(.abbreviated) : format.weekday(.abbreviated)
        let day = calendar.component(.day, from: date)
        return (date.formatted(format), "\(day)")
    }

    /// "Last played Nov 15" for a player card, or "No rounds yet" (HOME-PC-02).
    public static func lastPlayed(_ date: Date?, locale: Locale = .current) -> String {
        guard let date else {
            return String(localized: "No rounds yet", bundle: Bundle.maynardUI, comment: "Player card subtitle when the player has no completed rounds.")
        }
        let day = date.formatted(Date.FormatStyle().month(.abbreviated).day().locale(locale))
        return String(localized: "Last played \(day)", bundle: Bundle.maynardUI, comment: "Player card subtitle: the date of the player's last round.")
    }
}
