import SwiftUI
import RoutineCore

/// リストの編集：名前とやることだけ。いつ知らせるかは `TriggerEditView` で別に変える。
struct EditRoutineView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Routine
    @State private var text: String

    init(routine: Routine) {
        _draft = State(initialValue: routine)
        _text = State(initialValue: routine.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例：朝、帰り、出かける前", text: $draft.name)
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .font(.body)
                } header: {
                    Text("やること")
                } footer: {
                    Text("1行に1つずつ書きます。いつ知らせるかは、一覧の🔔の札から変えられます。")
                }
            }
            .navigationTitle("リストの編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.bold() }
            }
        }
    }

    private func save() {
        // 保存の直前に最新を取り直し、別の画面で変えた「いつ知らせるか」を上書きしない
        var routine = model.routine(draft.id) ?? draft
        routine.name = draft.name.trimmingCharacters(in: .whitespaces).isEmpty ? "リスト" : draft.name
        routine.setText(text)
        model.update(routine)
        dismiss()
    }
}

/// いつ知らせるか：このリストの通知のきっかけだけを変える画面。
struct TriggerEditView: View {
    let routineID: UUID
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind
    @State private var timeTrigger: TimeTrigger
    @State private var homeTrigger: HomeTrigger
    @State private var showHome = false
    private let name: String

    enum Kind: String, CaseIterable, Identifiable {
        case times, home, off
        var id: String { rawValue }
        var label: String {
            switch self {
            case .times: return "時刻で"
            case .home: return "家にいる間"
            case .off: return "通知なし"
            }
        }
    }

    init(routine: Routine) {
        routineID = routine.id
        name = routine.name
        switch routine.trigger {
        case .none:
            _kind = State(initialValue: .off)
            _timeTrigger = State(initialValue: TimeTrigger())
            _homeTrigger = State(initialValue: HomeTrigger())
        case .times(let t):
            _kind = State(initialValue: .times)
            _timeTrigger = State(initialValue: t)
            _homeTrigger = State(initialValue: HomeTrigger())
        case .atHome(let h):
            _kind = State(initialValue: .home)
            _timeTrigger = State(initialValue: TimeTrigger())
            _homeTrigger = State(initialValue: h)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("通知", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(footer)
                }

                switch kind {
                case .times: Section("曜日と時刻") { timesEditor }
                case .home: Section("曜日と時間") { homeEditor }
                case .off: EmptyView()
                }
            }
            .navigationTitle("いつ知らせるか：\(name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.bold() }
            }
            .sheet(isPresented: $showHome) { NavigationStack { HomeSettingsView() } }
        }
    }

    private var footer: String {
        switch kind {
        case .times: return "その日のリストが全部そろっていれば、通知は出しません。"
        case .home: return "選んだ曜日・時間に家にいる間だけ、決まった間隔で知らせます。全部そろったら、その日はもう鳴りません。"
        case .off: return "通知は出しません。一覧から開いて使います。"
        }
    }

    @ViewBuilder private var timesEditor: some View {
        WeekdayPicker(selection: $timeTrigger.weekdays)
        ForEach(timeTrigger.times.indices, id: \.self) { i in
            HStack {
                DatePicker("時刻 \(i + 1)", selection: $timeTrigger.times[i].asDate, displayedComponents: .hourAndMinute)
                if timeTrigger.times.count > 1 {
                    Button {
                        timeTrigger.times.remove(at: i)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("この時刻を消す")
                }
            }
        }
        Button {
            timeTrigger.times.append(timeTrigger.times.last ?? TimeOfDay(7))
        } label: {
            Label("時刻を足す", systemImage: "plus")
        }
    }

    @ViewBuilder private var homeEditor: some View {
        WeekdayPicker(selection: $homeTrigger.weekdays)
        DatePicker("鳴らし始める", selection: $homeTrigger.start.asDate, displayedComponents: .hourAndMinute)
        DatePicker("鳴らし終える", selection: $homeTrigger.end.asDate, displayedComponents: .hourAndMinute)
        Picker("間隔", selection: $homeTrigger.intervalMinutes) {
            ForEach(HomeTrigger.intervalChoices, id: \.self) { Text(Labels.interval($0)).tag($0) }
        }
        Button {
            showHome = true
        } label: {
            if let home = model.data.home {
                Label("家の場所：設定済み（半径\(Int(home.radius))m）", systemImage: "house.fill")
            } else {
                Label("家の場所を決める（まだ決まっていません）", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func save() {
        guard var routine = model.routine(routineID) else { dismiss(); return }
        switch kind {
        case .times:
            timeTrigger.times = Array(Set(timeTrigger.times)).sorted()
            routine.trigger = .times(timeTrigger)
        case .home:
            routine.trigger = .atHome(homeTrigger)
            if !AppModel.shared.homeMonitor.hasAlways { AppModel.shared.homeMonitor.requestAlways() }
        case .off:
            routine.trigger = .none
        }
        model.update(routine)
        dismiss()
    }
}

/// 見た目：色・そろった時の演出。押したらすぐ反映する。
struct StyleSheet: View {
    let routineID: UUID
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let style = model.routine(routineID)?.style ?? RoutineStyle()
        NavigationStack {
            Form {
                Section("色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(Theme.all) { theme in
                            Button {
                                model.updateStyle(routineID) { $0.themeID = theme.id }
                            } label: {
                                VStack(spacing: 6) {
                                    HStack(spacing: 3) {
                                        ForEach(0..<4, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 3).fill(theme.tile(i)).frame(height: 26)
                                        }
                                    }
                                    Text(theme.name).font(.caption)
                                }
                                .padding(8)
                                .background(theme.background, in: RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(theme.accentColor, lineWidth: style.themeID == theme.id ? 3 : 0)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(style.themeID == theme.id ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("そろった時") {
                    Picker("そろった時", selection: binding(\.celebration, style.celebration)) {
                        ForEach(Celebration.allCases, id: \.self) { Text(Labels.celebration($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("見た目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }

    private func binding<T>(_ path: WritableKeyPath<RoutineStyle, T>, _ current: T) -> Binding<T> {
        Binding(get: { current }, set: { value in model.updateStyle(routineID) { $0[keyPath: path] = value } })
    }
}
