import SwiftUI
import RoutineCore

/// リストの一覧。
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [UUID] = []
    @State private var showSettings = false
    @State private var triggerRoutine: Routine?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(model.data.routines) { routine in
                    // 行を押せばリストを開く。下の🔔の札だけは、いつ知らせるかの画面を直接開く
                    RoutineRow(routine: routine, today: model.today,
                               onOpen: { path.append(routine.id) },
                               onTrigger: { triggerRoutine = routine })
                    .swipeActions(edge: .leading) {
                        Button("複製") { model.duplicate(routine.id) }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("削除", role: .destructive) { model.delete(routine.id) }
                    }
                }
                .onMove { model.move(from: $0, to: $1) }

                if model.data.home == nil && model.data.needsHome {
                    Section {
                        Button {
                            showSettings = true
                        } label: {
                            Label("家の場所を決めると「家にいる間」の通知が使えます", systemImage: "house")
                                .font(.footnote)
                        }
                    }
                }
            }
            // 一番上の大きな題は出さない（2026-11-15 本人判断）。ボタンの帯だけ残す
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                RoutineView(routineID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("設定")
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(model.addRoutine()) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("リストを足す")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $triggerRoutine) { TriggerEditView(routine: $0) }
        }
        .task { await model.notifier.requestAuthorizationIfNeeded() }
        .onChange(of: model.openRoutineID) { _, id in
            guard let id else { return }
            path = [id]
            model.openRoutineID = nil
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let today: DayKey
    let onOpen: () -> Void
    let onTrigger: () -> Void
    @State private var tapped = 0

    var body: some View {
        let theme = Theme.theme(id: routine.style.themeID)
        let done = routine.checkedIDs(on: today).count
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.accentColor)
                .frame(width: 8, height: 52)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    tapped += 1
                    onOpen()
                } label: {
                    HStack {
                        Text(routine.name).font(.headline).foregroundStyle(Color.primary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // いつ知らせるか。押すとその設定だけの画面が開く
                Button {
                    tapped += 1
                    onTrigger()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: routine.trigger.needsHome ? "house.fill" : (routine.trigger.isOff ? "bell.slash.fill" : "bell.fill"))
                        Text(Labels.trigger(routine.trigger)).lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption2.bold())
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(routine.trigger.isOff ? Color.secondary : theme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((routine.trigger.isOff ? Color.secondary : theme.accentColor).opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("いつ知らせるか：\(Labels.trigger(routine.trigger))")
                .accessibilityIdentifier("triggerChip")
            }
            Button {
                tapped += 1
                onOpen()
            } label: {
                HStack(spacing: 8) {
                    if routine.isComplete(on: today) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                            .accessibilityLabel("今日はそろった")
                    } else {
                        Text("\(done)/\(routine.items.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(.tertiary)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: tapped)
    }
}
