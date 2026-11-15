import SwiftUI
import RoutineCore

/// リストの一覧。
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [UUID] = []
    @State private var showSettings = false
    @State private var triggerRoutine: Routine?
    @State private var editRoutine: Routine?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(model.data.routines) { routine in
                    // 行を押せばリストを開く。下の札は「いつ知らせるか」「編集」の画面を直接開く
                    RoutineRow(routine: routine, today: model.today,
                               onOpen: { path.append(routine.id) },
                               onTrigger: { triggerRoutine = routine },
                               onEdit: { editRoutine = routine })
                    // リストごとに1枚の札として離す（2026-11-15 本人指摘：朝と帰りがくっついて見えた）
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .listRowBackground(RowBackground(themeID: routine.style.themeID))
                    .swipeActions(edge: .leading) {
                        Button("複製") { Haptics.tap(); model.duplicate(routine.id) }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("削除", role: .destructive) { Haptics.tap(); model.delete(routine.id) }
                    }
                }
                .onMove { model.move(from: $0, to: $1) }

                if model.data.home == nil && model.data.needsHome {
                    Section {
                        Button {
                            Haptics.tap()
                            showSettings = true
                        } label: {
                            Label("家の場所を決めると「家にいる間」の通知が使えます", systemImage: "house")
                                .font(.footnote)
                        }
                    }
                }
            }
            .listRowSpacing(14)
            .environment(\.editMode, $editMode)
            // 一番上の大きな題は出さない（2026-11-15 本人判断）。ボタンの帯だけ残す
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                RoutineView(routineID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.tap(); showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("設定")
                }
                // 行の「編集」と紛らわしいので、並べ替えだと分かる名前にする
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "完了" : "並べ替え") {
                        Haptics.tap()
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); path.append(model.addRoutine()) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("リストを足す")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView().hapticOnOpen() }
            .sheet(item: $triggerRoutine) { TriggerEditView(routine: $0).hapticOnOpen() }
            .sheet(item: $editRoutine) { EditRoutineView(routine: $0).hapticOnOpen() }
        }
        .task { await model.notifier.requestAuthorizationIfNeeded() }
        .onChange(of: model.openRoutineID) { _, id in
            guard let id else { return }
            path = [id]
            model.openRoutineID = nil
        }
    }
}

/// 1つのリストの札の地。テーマの色をうっすら敷き、左に色の帯。
private struct RowBackground: View {
    let themeID: Int
    var body: some View {
        let theme = Theme.theme(id: themeID)
        ZStack(alignment: .leading) {
            Color(.secondarySystemGroupedBackground)
            theme.accentColor.opacity(0.07)
            theme.accentColor.frame(width: 8)
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let today: DayKey
    let onOpen: () -> Void
    let onTrigger: () -> Void
    let onEdit: () -> Void
    @State private var tapped = 0

    var body: some View {
        let theme = Theme.theme(id: routine.style.themeID)
        let done = routine.checkedIDs(on: today).count
        VStack(alignment: .leading, spacing: 14) {
            // 上の段：名前と進み具合。押すとリストを開く
            Button {
                tapped += 1
                onOpen()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name)
                            .font(.title2.bold())
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        Text(routine.items.isEmpty ? "やることがまだありません"
                             : routine.items.prefix(3).map(\.title).joined(separator: "・") + (routine.items.count > 3 ? "…" : ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if routine.isComplete(on: today) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                            .accessibilityLabel("今日はそろった")
                    } else {
                        Text("\(done)/\(routine.items.count)")
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(theme.accentColor)
                    }
                    Image(systemName: "chevron.right").font(.body.bold()).foregroundStyle(.tertiary)
                }
                .padding(.leading, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 下の段：いつ知らせるか・編集。それぞれの画面を直接開く
            HStack(spacing: 10) {
                Chip(icon: routine.trigger.needsHome ? "house.fill" : (routine.trigger.isOff ? "bell.slash.fill" : "bell.fill"),
                     text: Labels.trigger(routine.trigger),
                     color: routine.trigger.isOff ? .secondary : theme.accentColor, grow: true) {
                    tapped += 1
                    onTrigger()
                }
                .accessibilityLabel("いつ知らせるか：\(Labels.trigger(routine.trigger))")
                .accessibilityIdentifier("triggerChip")
                Chip(icon: "pencil", text: "編集", color: theme.accentColor, grow: false) {
                    tapped += 1
                    onEdit()
                }
                .accessibilityLabel("リストの編集")
                .accessibilityIdentifier("editChip")
            }
            .padding(.leading, 6)
        }
        .frame(minHeight: 120)
        .onChange(of: tapped) { Haptics.tap() }
    }
}

/// 押せる小さな札。
private struct Chip: View {
    let icon: String
    let text: String
    let color: Color
    let grow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(text).lineLimit(1).minimumScaleFactor(0.8)
                if grow { Spacer(minLength: 0) }
                Image(systemName: "chevron.right").font(.caption2.bold())
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: grow ? .infinity : nil)
            .background(color.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
