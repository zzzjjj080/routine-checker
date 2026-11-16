import XCTest
@testable import RoutineCore

final class LeaveCheckTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    /// 2026-11-16 は月曜。
    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    var check: LeaveCheck { LeaveCheck(calendar: cal, resetTime: TimeOfDay(3)) }

    func morning(leave: Bool = true) -> Routine {
        Routine(name: "朝", text: "鍵\n財布", trigger: .times(TimeTrigger(times: [TimeOfDay(7)])), leaveCheck: leave)
    }

    func test最初の時刻を過ぎて残っていれば知らせる() {
        XCTAssertEqual(check.routinesToAlert([morning()], now: at(16, 8)).count, 1)
    }

    func test最初の時刻より前に出たら知らせない() {
        XCTAssertTrue(check.routinesToAlert([morning()], now: at(16, 6, 30)).isEmpty)
    }

    func testオフなら知らせない() {
        XCTAssertTrue(check.routinesToAlert([morning(leave: false)], now: at(16, 8)).isEmpty)
    }

    func test全部そろっていれば知らせない() {
        var r = morning()
        let day = cal.routineDay(of: at(16, 7, 30), resetAt: TimeOfDay(3))
        for item in r.items { r.toggle(item.id, on: day, at: at(16, 7, 30)) }
        XCTAssertTrue(check.routinesToAlert([r], now: at(16, 8)).isEmpty)
    }

    func test一部だけでも残っていれば知らせる() {
        var r = morning()
        let day = cal.routineDay(of: at(16, 7, 30), resetAt: TimeOfDay(3))
        r.toggle(r.items[0].id, on: day, at: at(16, 7, 30))
        XCTAssertEqual(check.routinesToAlert([r], now: at(16, 8)).count, 1)
    }

    func test同じ日は1回だけ_次の日はまた知らせる() {
        var r = morning()
        r.leaveAlertedDay = cal.routineDay(of: at(16, 8), resetAt: TimeOfDay(3))
        XCTAssertTrue(check.routinesToAlert([r], now: at(16, 12)).isEmpty)
        XCTAssertEqual(check.routinesToAlert([r], now: at(17, 8)).count, 1)
    }

    func test曜日が違えば知らせない() {
        // 11/15 は日曜。既定は平日だけ。
        XCTAssertTrue(check.routinesToAlert([morning()], now: at(15, 8)).isEmpty)
    }

    func test通知なしのリストはいつでも() {
        let r = Routine(name: "出かける前", text: "鍵", trigger: .none, leaveCheck: true)
        XCTAssertEqual(check.routinesToAlert([r], now: at(15, 4)).count, 1)
    }

    func test家にいる間のリストは鳴らし始めから() {
        let r = Routine(name: "帰り", text: "a", trigger: .atHome(HomeTrigger()), leaveCheck: true)
        XCTAssertTrue(check.routinesToAlert([r], now: at(16, 17)).isEmpty)
        XCTAssertEqual(check.routinesToAlert([r], now: at(16, 19)).count, 1)
    }

    func test前の版のデータを読むとオフになり_ほかは残る() throws {
        let old = """
        {"routines":[{"id":"5B762412-4593-5A17-A722-0EA0EC829AFE","name":"朝","items":[{"id":"6B762412-4593-5A17-A722-0EA0EC829AFE","title":"鍵"}],
        "trigger":{"none":{}},"style":{"layout":"list","themeID":2,"celebration":"glow"},"checked":[]}],
        "resetTime":{"hour":3,"minute":0},"appearance":"system"}
        """
        let data = try AppData.decoded(from: Data(old.utf8))
        XCTAssertEqual(data.routines.first?.name, "朝")
        XCTAssertEqual(data.routines.first?.style.themeID, 2)
        XCTAssertEqual(data.routines.first?.leaveCheck, false)
    }

    func test保存して読み直しても残る() throws {
        var d = AppData(routines: [morning()])
        d.routines[0].leaveAlertedDay = DayKey(year: 2026, month: 11, day: 16)
        let back = try AppData.decoded(from: d.encoded())
        XCTAssertEqual(back, d)
    }
}

final class BadgeTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    var badge: Badge { Badge(calendar: cal, resetTime: TimeOfDay(3)) }
    let morning = Routine(name: "朝", text: "a\nb\nc", trigger: .times(TimeTrigger(times: [TimeOfDay(7)])))
    let evening = Routine(name: "帰り", text: "x\ny", trigger: .atHome(HomeTrigger()))

    func test始まる前は0_始まったらそろっていないリストの数() {
        XCTAssertEqual(badge.count([morning, evening], at: at(16, 6)), 0)
        XCTAssertEqual(badge.count([morning, evening], at: at(16, 7)), 1)
        XCTAssertEqual(badge.count([morning, evening], at: at(16, 19)), 2)
    }

    func test一部済んでも1_全部そろえば0() {
        var r = morning
        let day = cal.routineDay(of: at(16, 7), resetAt: TimeOfDay(3))
        r.toggle(r.items[0].id, on: day, at: at(16, 7))
        XCTAssertEqual(badge.count([r], at: at(16, 8)), 1)
        for item in r.items.dropFirst() { r.toggle(item.id, on: day, at: at(16, 7)) }
        XCTAssertEqual(badge.count([r], at: at(16, 8)), 0)
    }

    func test通知なしのリストは数えない() {
        let r = Routine(name: "メモ", text: "a", trigger: .none)
        XCTAssertEqual(badge.count([r], at: at(16, 12)), 0)
    }

    func test変わる時刻_始まりと区切り() {
        let ch = badge.changes([morning, evening], after: at(16, 6), days: 1)
        XCTAssertEqual(ch.map(\.count), [1, 2, 0, 1, 2])
        XCTAssertEqual(ch.map(\.date), [at(16, 7), at(16, 18), at(17, 3), at(17, 7), at(17, 18)])
    }
}

final class LeaveVerdictTests: XCTestCase {
    func test理由が分かる() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = c.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 6))!
        let check = LeaveCheck(calendar: c)
        let r = Routine(name: "朝", text: "a", trigger: .times(TimeTrigger(times: [TimeOfDay(7)])), leaveCheck: true)
        XCTAssertEqual(check.verdict(for: r, now: now), .notStarted)
        XCTAssertEqual(check.verdict(for: Routine(name: "朝", text: "a"), now: now), .off)
    }
}
