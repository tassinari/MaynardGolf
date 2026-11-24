//
//  OutsideScoreRules.swift
//  MaynardGolf
//

import Foundation

/// Why an outside course or score was refused (DM-OC-02…05, DM-OS-02, 04). Screens map each case to a message.
enum OutsideScoreError: Error, Equatable, Sendable {
    /// The name is empty or longer than 60 characters after trimming.
    case invalidCourseName
    /// Another course already has this name, ignoring case and surrounding spaces.
    case duplicateCourseName
    /// Not 50.0 … 85.0, or more than one decimal.
    case ratingOutOfRange
    /// Not 55 … 155.
    case slopeOutOfRange
    /// Outside the range for the hole count.
    case grossOutOfRange(Int)
    /// The day played is after today.
    case futureDate
}

/// The rules for outside courses and scores (12-data-model §3.4, §3.5, #252), pure so the repository and the
/// Add score / Add course screens (#253) agree.
enum OutsideScoreRules {
    /// The longest course name, after trimming (DM-OC-02).
    static let maximumNameLength = 60
    /// A real 18-hole course rating, with margin (DM-OC-04).
    static let ratingRange: ClosedRange<Double> = 50.0...85.0
    /// The WHS slope range (DM-OC-05).
    static let slopeRange: ClosedRange<Int> = 55...155
    /// The slope of a course of standard difficulty; the defaults use it.
    static let standardSlope = 113

    /// The gross totals accepted for a hole count (DM-OS-02).
    static func grossRange(for holeCount: HoleCount) -> ClosedRange<Int> {
        holeCount == .nine ? 20...100 : 40...200
    }

    /// The name trimmed, or `invalidCourseName` when it's empty or too long.
    static func courseName(_ name: String) throws(OutsideScoreError) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...maximumNameLength).contains(trimmed.count) else { throw .invalidCourseName }
        return trimmed
    }

    /// Whether two names are the same course name: trimmed, ignoring case (DM-OC-03).
    static func sameName(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(b.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// The rating rounded to exactly one decimal, or `ratingOutOfRange`.
    static func courseRating(_ rating: Double) throws(OutsideScoreError) -> Double {
        let tenths = (rating * 10).rounded()
        guard rating.isFinite, abs(rating * 10 - tenths) < 1e-6, ratingRange.contains(tenths / 10) else { throw .ratingOutOfRange }
        return tenths / 10
    }

    /// The slope, or `slopeOutOfRange`.
    static func slope(_ slope: Int) throws(OutsideScoreError) -> Int {
        guard slopeRange.contains(slope) else { throw .slopeOutOfRange }
        return slope
    }

    /// The gross, or `grossOutOfRange` for the hole count.
    static func gross(_ gross: Int, holeCount: HoleCount) throws(OutsideScoreError) -> Int {
        guard grossRange(for: holeCount).contains(gross) else { throw .grossOutOfRange(gross) }
        return gross
    }

    /// The day played as stored, or `futureDate` when that day is after today's (DM-OS-04). Both days are
    /// read in `calendar`, the user's.
    static func playedOn(_ date: Date, now: Date, calendar: Calendar) throws(OutsideScoreError) -> Date {
        let day = storedDay(date, calendar: calendar)
        guard day <= storedDay(now, calendar: calendar) else { throw .futureDate }
        return day
    }

    /// A calendar day as stored (DM-OS-04): 12:00 UTC on the date `calendar` shows for `date`. A day is not an
    /// instant, so it isn't kept as local midnight, which reads as the day before anywhere west of where it
    /// was saved (another device through iCloud, or the same one after travel). Read it back with
    /// `dayCalendar(from:)`, never in a local time zone.
    static func storedDay(_ date: Date, calendar: Calendar) -> Date {
        // Local midnight moved by the zone's offset there is UTC midnight on the same date; then noon.
        let midnight = calendar.startOfDay(for: date)
        return midnight.addingTimeInterval(TimeInterval(calendar.timeZone.secondsFromGMT(for: midnight)) + 12 * 3600)
    }

    /// The calendar a stored day is read and shown in: the user's calendar system in UTC, so the date is the
    /// one that was picked in every time zone (DM-OS-04).
    static func dayCalendar(from calendar: Calendar) -> Calendar {
        var utc = calendar
        utc.timeZone = .gmt
        return utc
    }
}
