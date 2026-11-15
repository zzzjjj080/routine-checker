import XCTest
@testable import RoutineCore

final class RoutineTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    func day(_ date: Date) -> DayKey { cal.routineDay(of: date, resetAt: TimeOfDay(3)) }

    func test区切りの3時まではチェックが残る() {
        var r = Routine(name: "帰り", text: "a\nb")
        r.toggle(r.items[0].id, on: day(at(16, 23, 30)), at: at(16, 23, 30))
        XCTAssertTrue(r.isChecked(r.items[0].id, on: day(at(17, 1))))
        XCTAssertFalse(r.isChecked(r.items[0].id, on: day(at(17, 4))))
    }

    func test新しい日に押すと前の日のチェックは消える() {
        var r = Routine(name: "朝", text: "a\nb")
        r.toggle(r.items[0].id, on: day(at(16, 7)), at: at(16, 7))
        r.toggle(r.items[1].id, on: day(at(17, 7)), at: at(17, 7))
        XCTAssertEqual(r.checkedIDs(on: day(at(17, 7))), [r.items[1].id])
    }

    func testそろった瞬間だけtrue() {
        var r = Routine(name: "朝", text: "a\nb")
        let d = day(at(16, 7))
        XCTAssertFalse(r.toggle(r.items[0].id, on: d, at: at(16, 7)))
        XCTAssertTrue(r.toggle(r.items[1].id, on: d, at: at(16, 7, 5)))
        XCTAssertEqual(r.lastCompletedAt, at(16, 7, 5))
        XCTAssertFalse(r.toggle(r.items[1].id, on: d, at: at(16, 7, 6)))
        XCTAssertFalse(r.isComplete(on: d))
    }

    func test書き直しても同じ名前はチェックを引き継ぐ() {
        var r = Routine(name: "朝", text: "薬\n顔\n歯")
        let d = day(at(16, 7))
        let kusuri = r.items[0].id
        let ha = r.items[2].id
        r.toggle(kusuri, on: d, at: at(16, 7))
        r.toggle(ha, on: d, at: at(16, 7))
        r.setText("  薬 \n\n水\n顔")
        XCTAssertEqual(r.items.map(\.title), ["薬", "水", "顔"])
        XCTAssertEqual(r.items[0].id, kusuri)
        XCTAssertEqual(r.checkedIDs(on: d), [kusuri])
    }

    func test複製はチェックを持ち越さない() {
        var r = Routine(name: "朝", text: "a")
        r.toggle(r.items[0].id, on: day(at(16, 7)), at: at(16, 7))
        let copy = r.duplicated(name: "休日の朝")
        XCTAssertNotEqual(copy.id, r.id)
        XCTAssertEqual(copy.text, "a")
        XCTAssertNil(copy.lastCompletedAt)
        XCTAssertTrue(copy.checkedIDs(on: day(at(16, 7))).isEmpty)
    }

    func test保存して読み戻せる() throws {
        var data = AppData.starter
        data.home = Home(latitude: 38.26, longitude: 140.87)
        let r = data.routines[0]
        data.routines[0].toggle(r.items[0].id, on: day(at(16, 7)), at: at(16, 7))
        XCTAssertEqual(try AppData.decoded(from: data.encoded()), data)
        XCTAssertTrue(data.needsHome)
    }

    func testテーマの色は繰り返す() {
        let t = Theme.theme(id: 2)
        XCTAssertEqual(t.tileColor(at: t.tiles.count), t.tiles[0])
        XCTAssertEqual(Theme.theme(id: 999).id, 0)
    }
}
