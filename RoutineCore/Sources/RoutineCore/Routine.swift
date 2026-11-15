import Foundation

public struct Item: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String

    public init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

/// 時刻で通知する。
public struct TimeTrigger: Codable, Hashable, Sendable {
    public var weekdays: Set<Int>
    public var times: [TimeOfDay]

    public init(weekdays: Set<Int> = Weekdays.weekdays, times: [TimeOfDay] = [TimeOfDay(7)]) {
        self.weekdays = weekdays
        self.times = times
    }
}

/// 家にいる間、決まった間隔で通知する。
public struct HomeTrigger: Codable, Hashable, Sendable {
    public static let intervalChoices = [30, 60, 120]

    public var weekdays: Set<Int>
    public var start: TimeOfDay
    /// 鳴らす最後の時刻（この時刻ちょうどは鳴る）。`start` より前なら翌日の時刻とみなす。
    public var end: TimeOfDay
    public var intervalMinutes: Int

    public init(weekdays: Set<Int> = Weekdays.weekdays,
                start: TimeOfDay = TimeOfDay(18),
                end: TimeOfDay = TimeOfDay(23),
                intervalMinutes: Int = 60) {
        self.weekdays = weekdays
        self.start = start
        self.end = end
        self.intervalMinutes = intervalMinutes
    }
}

public enum Trigger: Codable, Hashable, Sendable {
    case none
    case times(TimeTrigger)
    case atHome(HomeTrigger)

    public var needsHome: Bool {
        if case .atHome = self { return true }
        return false
    }
}

public enum RoutineLayout: String, Codable, CaseIterable, Sendable {
    case tiles   // マス
    case list    // 縦に並ぶ
    case cards   // 1つずつ大きく
}

public enum Celebration: String, Codable, CaseIterable, Sendable {
    case glow
    case confetti
    case subtle
    case none
}

public struct RoutineStyle: Codable, Hashable, Sendable {
    public var layout: RoutineLayout
    public var themeID: Int
    public var celebration: Celebration

    public init(layout: RoutineLayout = .list, themeID: Int = 0, celebration: Celebration = .glow) {
        self.layout = layout
        self.themeID = themeID
        self.celebration = celebration
    }
}

public struct Routine: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var items: [Item]
    public var trigger: Trigger
    public var style: RoutineStyle

    /// チェックはこの日のものだけ有効。日が変われば自然に空になる（消しに行かなくてよい）。
    public var checked: Set<UUID>
    public var checkedDay: DayKey?
    public var lastCompletedAt: Date?

    public init(id: UUID = UUID(), name: String, items: [Item] = [], trigger: Trigger = .none,
                style: RoutineStyle = RoutineStyle()) {
        self.id = id
        self.name = name
        self.items = items
        self.trigger = trigger
        self.style = style
        self.checked = []
        self.checkedDay = nil
        self.lastCompletedAt = nil
    }

    public init(name: String, text: String, trigger: Trigger = .none, style: RoutineStyle = RoutineStyle()) {
        self.init(name: name, trigger: trigger, style: style)
        setText(text)
    }

    // MARK: チェック

    public func checkedIDs(on day: DayKey) -> Set<UUID> {
        guard checkedDay == day else { return [] }
        return checked.intersection(items.map(\.id))
    }

    public func isChecked(_ id: UUID, on day: DayKey) -> Bool {
        checkedIDs(on: day).contains(id)
    }

    public func isComplete(on day: DayKey) -> Bool {
        !items.isEmpty && checkedIDs(on: day).count == items.count
    }

    /// 押した項目のチェックを切り替える。そろったら記録する。
    /// - Returns: この操作で「そろった」に変わったら true（祝うのはこの時だけ）。
    @discardableResult
    public mutating func toggle(_ id: UUID, on day: DayKey, at now: Date) -> Bool {
        let wasComplete = isComplete(on: day)
        if checkedDay != day {
            checked = []
            checkedDay = day
        }
        if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
        let complete = isComplete(on: day)
        if complete { lastCompletedAt = now }
        return complete && !wasComplete
    }

    public mutating func clearChecks() {
        checked = []
    }

    // MARK: テキスト

    /// 1行 = 1項目。空行は無視する。
    public var text: String { items.map(\.title).joined(separator: "\n") }

    /// 書き直したテキストを反映する。同じ名前の項目は ID とチェックを引き継ぐ。
    public mutating func setText(_ text: String) {
        var unused = items
        var next: [Item] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let title = line.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            if let i = unused.firstIndex(where: { $0.title == title }) {
                next.append(unused.remove(at: i))
            } else {
                next.append(Item(title: title))
            }
        }
        items = next
        checked.formIntersection(next.map(\.id))
    }

    /// 複製。書いた内容・きっかけ・見た目だけ写し、チェックと記録は持ち越さない。
    public func duplicated(name: String) -> Routine {
        Routine(name: name, items: items.map { Item(title: $0.title) }, trigger: trigger, style: style)
    }
}
