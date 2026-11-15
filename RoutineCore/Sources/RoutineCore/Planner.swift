import Foundation

/// 予約する通知1件。
public struct PlannedNotification: Hashable, Sendable {
    public var id: String
    public var routineID: UUID
    public var date: Date

    public init(routineID: UUID, date: Date) {
        self.routineID = routineID
        self.date = date
        self.id = "\(routineID.uuidString)-\(Int(date.timeIntervalSince1970))"
    }
}

/// 「今の状態から、どの通知をいつ予約するか」を決める。
///
/// iOS ではアプリを決まった間隔で起こして位置を確かめることは保証されない。
/// そこで家の出入り・アプリを開いた時・チェックした時などにこれを呼び、
/// 予約を全部入れ替える。家を出たら `isHome: false` で呼べば、家の通知は全部消える。
public struct Planner: Sendable {
    public var calendar: Calendar
    public var resetTime: TimeOfDay
    /// 何日先まで予約するか。
    public var horizonDays: Int
    /// iOS が覚えておける通知は64件まで。「あとで」の分を残す。
    public var limit: Int

    public init(calendar: Calendar = .current, resetTime: TimeOfDay = TimeOfDay(3),
                horizonDays: Int = 7, limit: Int = 60) {
        self.calendar = calendar
        self.resetTime = resetTime
        self.horizonDays = horizonDays
        self.limit = limit
    }

    public func plan(routines: [Routine], now: Date, isHome: Bool) -> [PlannedNotification] {
        var all: [PlannedNotification] = []
        for routine in routines where !routine.items.isEmpty {
            for date in occurrences(of: routine.trigger, now: now, isHome: isHome) {
                // そろった日の分は鳴らさない。
                if routine.isComplete(on: calendar.routineDay(of: date, resetAt: resetTime)) { continue }
                all.append(PlannedNotification(routineID: routine.id, date: date))
            }
        }
        return Array(all.sorted { $0.date < $1.date }.prefix(limit))
    }

    /// きっかけが鳴る時刻（`now` より後）。完了かどうかは見ない。
    func occurrences(of trigger: Trigger, now: Date, isHome: Bool) -> [Date] {
        let today = calendar.dayKey(of: now)
        var dates: [Date] = []

        switch trigger {
        case .none:
            break

        case .times(let t):
            for offset in 0...horizonDays {
                let day = calendar.adding(offset, to: today)
                guard t.weekdays.contains(calendar.weekday(of: day)) else { continue }
                for time in t.times {
                    let date = calendar.date(of: day, at: time)
                    if date > now { dates.append(date) }
                }
            }

        case .atHome(let h):
            guard isHome, h.intervalMinutes > 0 else { break }
            // 前の日から始まって日付をまたぐ枠（22:00〜1:00 など）があるので、昨日から見る。
            for offset in -1...horizonDays {
                let day = calendar.adding(offset, to: today)
                guard h.weekdays.contains(calendar.weekday(of: day)) else { continue }
                let start = calendar.date(of: day, at: h.start)
                let endDay = h.end < h.start ? calendar.adding(1, to: day) : day
                let end = calendar.date(of: endDay, at: h.end)
                var date = start
                while date <= end {
                    if date > now { dates.append(date) }
                    date = date.addingTimeInterval(Double(h.intervalMinutes) * 60)
                }
            }
        }
        return dates
    }
}
