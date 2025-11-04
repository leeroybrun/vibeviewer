import Foundation

public extension Date {
    /// Millisecond timestamp as a string.
    var millisecondsSince1970String: String {
        String(Int(self.timeIntervalSince1970 * 1000))
    }

    /// Create a date from a millisecond timestamp string.
    static func fromMillisecondsString(_ msString: String) -> Date? {
        guard let ms = Double(msString) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }
}

public extension Calendar {
    /// Start and end of the provided date within this calendar.
    func dayRange(for date: Date) -> (start: Date, end: Date) {
        let startOfDay = self.startOfDay(for: date)
        let nextDay = self.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let endOfDay = Date(timeInterval: -0.001, since: nextDay)
        return (startOfDay, endOfDay)
    }

    /// Range from the start of yesterday to the provided moment.
    func yesterdayToNowRange(from now: Date = Date()) -> (start: Date, end: Date) {
        let startOfToday = self.startOfDay(for: now)
        let startOfYesterday = self.date(byAdding: .day, value: -1, to: startOfToday) ?? now
        return (startOfYesterday, now)
    }
}


