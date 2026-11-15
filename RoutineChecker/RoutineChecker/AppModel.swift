import SwiftUI
import RoutineCore

/// アプリの状態。保存・通知の予約・家の見張りをまとめる。
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var data: AppData {
        didSet {
            guard data != oldValue else { return }
            save()
            if data.home != oldValue.home { homeMonitor.watch(data.home) }
            refreshNotifications()
        }
    }

    /// 最後に分かった「家にいるか」。裏で起こされた時にも使うので保存しておく。
    @Published private(set) var isHome: Bool {
        didSet {
            guard isHome != oldValue else { return }
            UserDefaults.standard.set(isHome, forKey: Self.isHomeKey)
            refreshNotifications()
        }
    }

    /// 通知から開くリスト。
    @Published var openRoutineID: UUID?
    /// 作ったばかりで、開いたらすぐ編集画面を出すリスト。
    @Published var editOnOpenID: UUID?

    let notifier = Notifier()
    let homeMonitor = HomeMonitor()

    private static let isHomeKey = "isHome"
    private var started = false

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("routines.json")
    }

    private init() {
        if let raw = try? Data(contentsOf: Self.fileURL), let loaded = try? AppData.decoded(from: raw) {
            data = loaded
        } else {
            data = .starter
        }
        isHome = UserDefaults.standard.bool(forKey: Self.isHomeKey)
    }

    func start() {
        guard !started else { return }
        started = true
        notifier.registerCategories()
        homeMonitor.onChange = { [weak self] home in self?.isHome = home }
        homeMonitor.watch(data.home)
        save()
        refreshNotifications()
    }

    func didBecomeActive() {
        start()
        // 日が変わっているかもしれないので、表示と予約を取り直す。
        objectWillChange.send()
        homeMonitor.refreshAuthorization()
        refreshNotifications()
    }

    // MARK: 日

    var today: DayKey { Calendar.current.routineDay(of: Date(), resetAt: data.resetTime) }

    // MARK: リスト

    func routine(_ id: UUID) -> Routine? { data.routines.first { $0.id == id } }

    /// - Returns: そろった瞬間なら true（祝う）。
    @discardableResult
    func toggle(item: UUID, in routineID: UUID) -> Bool {
        guard let i = data.routines.firstIndex(where: { $0.id == routineID }) else { return false }
        let completed = data.routines[i].toggle(item, on: today, at: Date())
        if completed { notifier.cancelSnooze(for: routineID) }
        return completed
    }

    func clearChecks(_ routineID: UUID) {
        guard let i = data.routines.firstIndex(where: { $0.id == routineID }) else { return }
        data.routines[i].clearChecks()
    }

    func update(_ routine: Routine) {
        guard let i = data.routines.firstIndex(where: { $0.id == routine.id }) else { return }
        data.routines[i] = routine
        if !routine.trigger.isOff { Task { await notifier.requestAuthorizationIfNeeded() } }
    }

    func updateStyle(_ routineID: UUID, _ change: (inout RoutineStyle) -> Void) {
        guard let i = data.routines.firstIndex(where: { $0.id == routineID }) else { return }
        change(&data.routines[i].style)
    }

    func addRoutine() -> UUID {
        let r = Routine(name: "新しいリスト", trigger: .times(TimeTrigger()),
                        style: RoutineStyle(themeID: data.routines.count % Theme.all.count))
        data.routines.append(r)
        editOnOpenID = r.id
        return r.id
    }

    func duplicate(_ routineID: UUID) {
        guard let i = data.routines.firstIndex(where: { $0.id == routineID }) else { return }
        let copy = data.routines[i].duplicated(name: data.routines[i].name + "のコピー")
        data.routines.insert(copy, at: i + 1)
    }

    func delete(_ routineID: UUID) {
        data.routines.removeAll { $0.id == routineID }
        notifier.cancelSnooze(for: routineID)
    }

    func move(from source: IndexSet, to destination: Int) {
        data.routines.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: 保存・通知

    private func save() {
        guard let raw = try? data.encoded() else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    func refreshNotifications() {
        let planner = Planner(calendar: .current, resetTime: data.resetTime)
        let home = data.home != nil && isHome
        let plan = planner.plan(routines: data.routines, now: Date(), isHome: home)
        let routines = data.routines
        let reset = data.resetTime
        Task { await notifier.replace(with: plan, routines: routines, resetTime: reset) }
    }
}
