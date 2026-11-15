import Foundation

/// 家を出た瞬間に「やり残し」があるリストを選ぶ。
///
/// 知らせるのは、次の全部がそろったリストだけ。
/// - 「家を出たら知らせる」がオン
/// - その日のぶんが始まっている（時刻のリストなら最初の時刻を過ぎた、家にいる間のリストなら鳴らし始めを過ぎた。
///   通知なしのリストは、区切りの時刻を過ぎていればいつでも）
/// - その日がまだそろっていない
/// - その日はまだこの知らせを出していない（家を何度出入りしても1日1回）
public struct LeaveCheck: Sendable {
    public var calendar: Calendar
    public var resetTime: TimeOfDay

    public init(calendar: Calendar = .current, resetTime: TimeOfDay = TimeOfDay(3)) {
        self.calendar = calendar
        self.resetTime = resetTime
    }

    public func routinesToAlert(_ routines: [Routine], now: Date) -> [Routine] {
        let day = calendar.routineDay(of: now, resetAt: resetTime)
        return routines.filter { r in
            r.leaveCheck && !r.items.isEmpty && !r.isComplete(on: day) && r.leaveAlertedDay != day
                && hasStarted(r.trigger, day: day, now: now)
        }
    }

    func hasStarted(_ trigger: Trigger, day: DayKey, now: Date) -> Bool {
        switch trigger {
        case .none:
            return true
        case .times(let t):
            guard t.weekdays.contains(calendar.weekday(of: day)), let first = t.times.min() else { return false }
            return now >= date(of: day, at: first)
        case .atHome(let h):
            guard h.weekdays.contains(calendar.weekday(of: day)) else { return false }
            return now >= date(of: day, at: h.start)
        }
    }

    /// その「1日」の中の時刻。区切りより前の時刻（2:00 など）は、暦の上では翌日になる。
    private func date(of day: DayKey, at time: TimeOfDay) -> Date {
        calendar.date(of: time < resetTime ? calendar.adding(1, to: day) : day, at: time)
    }
}
