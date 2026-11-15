import Foundation

/// 1日の中の時刻（時・分）。日付は持たない。
public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    /// 0時からの分。
    public var minutes: Int { hour * 60 + minute }

    public static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { a.minutes < b.minutes }
}

/// 暦の上の1日（年・月・日）。時刻とタイムゾーンを持たない。
public struct DayKey: Codable, Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (a: DayKey, b: DayKey) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

/// 曜日は `Calendar` と同じ番号（1 = 日曜 … 7 = 土曜）。
public enum Weekdays {
    public static let everyday: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    public static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public static let weekends: Set<Int> = [1, 7]
}

extension Calendar {
    public func dayKey(of date: Date) -> DayKey {
        let c = dateComponents([.year, .month, .day], from: date)
        return DayKey(year: c.year!, month: c.month!, day: c.day!)
    }

    /// その日のその時刻。
    public func date(of day: DayKey, at time: TimeOfDay) -> Date {
        var c = DateComponents()
        c.year = day.year
        c.month = day.month
        c.day = day.day
        c.hour = time.hour
        c.minute = time.minute
        return date(from: c)!
    }

    public func adding(_ days: Int, to day: DayKey) -> DayKey {
        let noon = date(of: day, at: TimeOfDay(12))
        return dayKey(of: date(byAdding: .day, value: days, to: noon)!)
    }

    public func weekday(of day: DayKey) -> Int {
        component(.weekday, from: date(of: day, at: TimeOfDay(12)))
    }

    /// チェックが属する「1日」。区切りの時刻（既定 3:00）より前は前の日に数える。
    /// 夜ふかしで日付をまたいでも、帰りのリストが消えないようにするため。
    public func routineDay(of date: Date, resetAt reset: TimeOfDay) -> DayKey {
        dayKey(of: date.addingTimeInterval(-Double(reset.minutes) * 60))
    }
}
