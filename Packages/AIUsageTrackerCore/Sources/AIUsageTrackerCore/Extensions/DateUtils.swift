import Foundation

public enum DateUtils {
    public enum TimeFormat {
        case hm        // HH:mm
        case hms       // HH:mm:ss

        fileprivate var dateFormat: String {
            switch self {
            case .hm: return "HH:mm"
            case .hms: return "HH:mm:ss"
            }
        }
    }

    /// Returns the start and end of the given date in the current calendar.
    public static func dayRange(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let endOfDay = Date(timeInterval: -0.001, since: nextDay)
        return (startOfDay, endOfDay)
    }

    /// Returns the range from yesterday's start to the provided `now` moment.
    public static func yesterdayToNowRange(from now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now
        return (startOfYesterday, now)
    }
    
    /// Returns the range from seven days ago through the start of tomorrow.
    public static func sevenDaysAgoToNowRange(from now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfSevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? now
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        return (startOfSevenDaysAgo, startOfTomorrow)
    }

    /// Returns the range from `days` days ago through the start of tomorrow.
    public static func daysAgoToNowRange(days: Int, from now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfNDaysAgo = calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? now
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        return (startOfNDaysAgo, startOfTomorrow)
    }

    /// Converts a date to a millisecond timestamp string.
    public static func millisecondsString(from date: Date) -> String {
        String(Int(date.timeIntervalSince1970 * 1000))
    }

    /// Parses a millisecond timestamp string into a `Date`.
    public static func date(fromMillisecondsString msString: String) -> Date? {
        guard let ms = Double(msString) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    /// Formats a date using the provided time pattern (HH:mm:ss by default).
    public static func timeString(from date: Date,
                                  format: TimeFormat = .hms,
                                  timeZone: TimeZone = .current,
                                  locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format.dateFormat
        return formatter.string(from: date)
    }

    /// Converts a millisecond timestamp to a formatted string.
    public static func timeString(fromMilliseconds ms: Int64,
                                  format: TimeFormat = .hms,
                                  timeZone: TimeZone = .current,
                                  locale: Locale = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        return timeString(from: date, format: format, timeZone: timeZone, locale: locale)
    }

    /// Converts a second-based timestamp to a formatted string.
    public static func timeString(fromSeconds s: Int64,
                                  format: TimeFormat = .hms,
                                  timeZone: TimeZone = .current,
                                  locale: Locale = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(s))
        return timeString(from: date, format: format, timeZone: timeZone, locale: locale)
    }

    /// Converts a millisecond timestamp string to a formatted string, returning an empty
    /// string for invalid input.
    public static func timeString(fromMillisecondsString msString: String,
                                  format: TimeFormat = .hms,
                                  timeZone: TimeZone = .current,
                                  locale: Locale = .current) -> String {
        guard let ms = Int64(msString) else { return "" }
        return timeString(fromMilliseconds: ms, format: format, timeZone: timeZone, locale: locale)
    }
}


