import Foundation

/// その日のぶんが「始まった」か。家を出た知らせとアイコンの数字で同じ決まりを使う。
public struct DayStart: Sendable {
    public var calendar: Calendar
    public var resetTime: TimeOfDay

    public init(calendar: Calendar = .current, resetTime: TimeOfDay = TimeOfDay(3)) {
        self.calendar = calendar
        self.resetTime = resetTime
    }

    /// その「1日」でリストが始まる時刻。その曜日はやらない・通知なしのリストは nil。
    public func startDate(of trigger: Trigger, on day: DayKey) -> Date? {
        switch trigger {
        case .none:
            return nil
        case .times(let t):
            guard t.weekdays.contains(calendar.weekday(of: day)), let first = t.times.min() else { return nil }
            return date(of: day, at: first)
        case .atHome(let h):
            guard h.weekdays.contains(calendar.weekday(of: day)) else { return nil }
            return date(of: day, at: h.start)
        }
    }

    /// 通知なしのリストは、区切りの時刻を過ぎればいつでも始まっている扱い（家を出た知らせ用）。
    public func hasStarted(_ trigger: Trigger, on day: DayKey, now: Date) -> Bool {
        if case .none = trigger { return true }
        guard let start = startDate(of: trigger, on: day) else { return false }
        return now >= start
    }

    /// その「1日」の始まり（区切りの時刻）。
    public func dayBegin(_ day: DayKey) -> Date { calendar.date(of: day, at: resetTime) }

    /// その「1日」の中の時刻。区切りより前の時刻（2:00 など）は、暦の上では翌日になる。
    func date(of day: DayKey, at time: TimeOfDay) -> Date {
        calendar.date(of: time < resetTime ? calendar.adding(1, to: day) : day, at: time)
    }
}

/// 家を出た瞬間に「やり残し」があるリストを選ぶ。
///
/// 知らせるのは、次の全部がそろったリストだけ。
/// - 「家を出たら知らせる」がオン
/// - その日のぶんが始まっている（時刻のリストなら最初の時刻を過ぎた、家にいる間のリストなら鳴らし始めを過ぎた。
///   通知なしのリストは、区切りの時刻を過ぎていればいつでも）
/// - その日がまだそろっていない
/// - その日はまだこの知らせを出していない（家を何度出入りしても1日1回）
public struct LeaveCheck: Sendable {
    public enum Verdict: Equatable, Sendable {
        case alert
        case off
        case empty
        case complete
        case alreadyToday
        case notStarted

        /// 記録に残す言葉。
        public var label: String {
            switch self {
            case .alert: return "知らせた"
            case .off: return "オフ"
            case .empty: return "項目なし"
            case .complete: return "そろっている"
            case .alreadyToday: return "今日はもう知らせた"
            case .notStarted: return "まだ始まっていない"
            }
        }
    }

    public var calendar: Calendar
    public var resetTime: TimeOfDay

    public init(calendar: Calendar = .current, resetTime: TimeOfDay = TimeOfDay(3)) {
        self.calendar = calendar
        self.resetTime = resetTime
    }

    public func verdict(for r: Routine, now: Date) -> Verdict {
        let day = calendar.routineDay(of: now, resetAt: resetTime)
        if !r.leaveCheck { return .off }
        if r.items.isEmpty { return .empty }
        if r.isComplete(on: day) { return .complete }
        if r.leaveAlertedDay == day { return .alreadyToday }
        if !DayStart(calendar: calendar, resetTime: resetTime).hasStarted(r.trigger, on: day, now: now) { return .notStarted }
        return .alert
    }

    public func routinesToAlert(_ routines: [Routine], now: Date) -> [Routine] {
        routines.filter { verdict(for: $0, now: now) == .alert }
    }
}

/// ホーム画面のアイコンに出す数字：今日始まっていて、まだそろっていないリストの数（項目の数ではない）。
///
/// 通知なしのリストは数えない（いつ始まるか決まっていないので、ずっと数字が残ってしまう）。
/// アプリが閉じていても数字が変わるよう、変わる時刻（リストが始まる時刻・区切りの時刻）も出す。
public struct Badge: Sendable {
    public var calendar: Calendar
    public var resetTime: TimeOfDay

    public init(calendar: Calendar = .current, resetTime: TimeOfDay = TimeOfDay(3)) {
        self.calendar = calendar
        self.resetTime = resetTime
    }

    public func count(_ routines: [Routine], at now: Date) -> Int {
        let day = calendar.routineDay(of: now, resetAt: resetTime)
        let start = DayStart(calendar: calendar, resetTime: resetTime)
        return routines.reduce(0) { sum, r in
            guard let s = start.startDate(of: r.trigger, on: day), now >= s else { return sum }
            return sum + (r.items.isEmpty || r.isComplete(on: day) ? 0 : 1)
        }
    }

    /// `now` より後で数字が変わる時刻と、その時の数字。`days` 日先まで、多くて `limit` 件。
    public func changes(_ routines: [Routine], after now: Date, days: Int = 2, limit: Int = 12) -> [(date: Date, count: Int)] {
        let start = DayStart(calendar: calendar, resetTime: resetTime)
        let today = calendar.routineDay(of: now, resetAt: resetTime)
        var moments: Set<Date> = []
        for offset in 0...days {
            let day = calendar.adding(offset, to: today)
            if offset > 0 { moments.insert(start.dayBegin(day)) }
            for r in routines { if let s = start.startDate(of: r.trigger, on: day) { moments.insert(s) } }
        }
        var result: [(date: Date, count: Int)] = []
        var last = count(routines, at: now)
        for m in moments.filter({ $0 > now }).sorted() {
            let c = count(routines, at: m)
            if c != last { result.append((m, c)); last = c }
        }
        return Array(result.prefix(limit))
    }
}
