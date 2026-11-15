import SwiftUI
import RoutineCore

/// リストの一覧。
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [UUID] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(model.data.routines) { routine in
                    NavigationLink(value: routine.id) {
                        RoutineRow(routine: routine, today: model.today)
                    }
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
            .navigationTitle("ルーティン")
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

    var body: some View {
        let theme = Theme.theme(id: routine.style.themeID)
        let done = routine.checkedIDs(on: today).count
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.accentColor)
                .frame(width: 8, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name).font(.headline)
                Label(Labels.trigger(routine.trigger),
                      systemImage: routine.trigger.needsHome ? "house" : (routine.trigger.isOff ? "bell.slash" : "bell"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
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
        }
        .padding(.vertical, 4)
    }
}
