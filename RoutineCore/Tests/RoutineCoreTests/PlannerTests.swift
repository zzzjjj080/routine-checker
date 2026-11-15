import XCTest
@testable import RoutineCore

/// 2026-11-16 は月曜、2026-11-21 は土曜。
final class PlannerTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    var planner: Planner { Planner(calendar: cal) }

    func homeRoutine(_ h: HomeTrigger = HomeTrigger()) -> Routine {
        Routine(name: "帰り", text: "手を洗う\n充電", trigger: .atHome(h))
    }

    // MARK: 家にいる間

    func test帰る前に家にいれば18時から1時間ごと() {
        let plan = planner.plan(routines: [homeRoutine()], now: at(16, 17), isHome: true)
        XCTAssertEqual(Array(plan.prefix(6)).map(\.date),
                       [at(16, 18), at(16, 19), at(16, 20), at(16, 21), at(16, 22), at(16, 23)])
        XCTAssertEqual(plan[6].date, at(17, 18))
    }

    func test途中で帰ったら次の区切りから() {
        let plan = planner.plan(routines: [homeRoutine()], now: at(16, 18, 20), isHome: true)
        XCTAssertEqual(plan.first?.date, at(16, 19))
    }

    func test家にいなければ鳴らさない() {
        XCTAssertTrue(planner.plan(routines: [homeRoutine()], now: at(16, 17), isHome: false).isEmpty)
    }

    func testそろった日は鳴らさない() {
        var r = homeRoutine()
        let today = cal.routineDay(of: at(16, 18, 30), resetAt: TimeOfDay(3))
        for item in r.items { r.toggle(item.id, on: today, at: at(16, 18, 30)) }
        let plan = planner.plan(routines: [r], now: at(16, 18, 30), isHome: true)
        XCTAssertEqual(plan.first?.date, at(17, 18))
    }

    func test週末は鳴らさない() {
        let plan = planner.plan(routines: [homeRoutine()], now: at(21, 17), isHome: true)
        XCTAssertEqual(plan.first?.date, at(23, 18))
    }

    func test日付をまたぐ枠() {
        let h = HomeTrigger(start: TimeOfDay(22), end: TimeOfDay(1))
        let plan = planner.plan(routines: [homeRoutine(h)], now: at(16, 23, 30), isHome: true)
        XCTAssertEqual(Array(plan.prefix(2)).map(\.date), [at(17, 0), at(17, 1)])
    }

    func test間隔30分() {
        let h = HomeTrigger(start: TimeOfDay(18), end: TimeOfDay(19), intervalMinutes: 30)
        let plan = planner.plan(routines: [homeRoutine(h)], now: at(16, 17), isHome: true)
        XCTAssertEqual(Array(plan.prefix(3)).map(\.date), [at(16, 18), at(16, 18, 30), at(16, 19)])
    }

    // MARK: 時刻

    func test朝7時() {
        let r = Routine(name: "朝", text: "薬", trigger: .times(TimeTrigger()))
        XCTAssertEqual(planner.plan(routines: [r], now: at(16, 6), isHome: false).first?.date, at(16, 7))
        XCTAssertEqual(planner.plan(routines: [r], now: at(16, 8), isHome: false).first?.date, at(17, 7))
        // 金曜の朝を過ぎたら次は月曜
        XCTAssertEqual(planner.plan(routines: [r], now: at(20, 8), isHome: false).first?.date, at(23, 7))
    }

    func test空のリストは鳴らさない() {
        let r = Routine(name: "空", trigger: .times(TimeTrigger()))
        XCTAssertTrue(planner.plan(routines: [r], now: at(16, 6), isHome: false).isEmpty)
    }

    func test上限() {
        let h = HomeTrigger(weekdays: Weekdays.everyday, start: TimeOfDay(0), end: TimeOfDay(23, 30),
                            intervalMinutes: 30)
        let plan = Planner(calendar: cal, limit: 10).plan(routines: [homeRoutine(h)], now: at(16, 0, 10), isHome: true)
        XCTAssertEqual(plan.count, 10)
        XCTAssertEqual(plan.first?.date, at(16, 0, 30))
    }

    func testIDは同じ時刻なら同じ() {
        let r = homeRoutine()
        let a = planner.plan(routines: [r], now: at(16, 17), isHome: true)
        let b = planner.plan(routines: [r], now: at(16, 17, 30), isHome: true)
        XCTAssertEqual(a.first?.id, b.first?.id)
    }
}
