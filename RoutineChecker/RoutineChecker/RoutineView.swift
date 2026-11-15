import SwiftUI
import RoutineCore

/// 1つのリストを開いた画面。
struct RoutineView: View {
    let routineID: UUID
    @EnvironmentObject private var model: AppModel
    @State private var showEdit = false
    @State private var showStyle = false
    @State private var confirmClear = false
    @State private var celebrate = 0
    @State private var tapped = 0

    var body: some View {
        if let routine = model.routine(routineID) {
            content(routine)
        } else {
            ContentUnavailableView("リストがありません", systemImage: "list.bullet")
        }
    }

    private func content(_ routine: Routine) -> some View {
        let theme = Theme.theme(id: routine.style.themeID)
        let today = model.today
        let checked = routine.checkedIDs(on: today)
        let complete = routine.isComplete(on: today)

        return VStack(spacing: 0) {
            ProgressBand(done: checked.count, total: routine.items.count, complete: complete, theme: theme)
                .padding(.horizontal)
                .padding(.top, 8)

            Group {
                if routine.items.isEmpty {
                    ContentUnavailableView {
                        Label("項目がありません", systemImage: "square.and.pencil")
                    } description: {
                        Text("「編集」から、やることを1行に1つずつ書いてください。")
                    }
                } else {
                    switch routine.style.layout {
                    case .tiles: TilesLayout(routine: routine, checked: checked, theme: theme, onTap: toggle)
                    case .list: ListLayout(routine: routine, checked: checked, theme: theme, onTap: toggle)
                    case .cards: CardsLayout(routine: routine, checked: checked, theme: theme, onTap: toggle)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button {
                    if complete || checked.isEmpty { model.clearChecks(routineID) } else { confirmClear = true }
                } label: {
                    Label("全部外す", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(checked.isEmpty)
                Button {
                    showStyle = true
                } label: {
                    Label("見た目", systemImage: "paintpalette")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(theme.accentColor)
            .controlSize(.large)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) { EditRoutineView(routine: routine) }
        .sheet(isPresented: $showStyle) {
            StyleSheet(routineID: routineID)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("\(checked.count)個のチェックを外しますか？", isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("全部外す", role: .destructive) { model.clearChecks(routineID) }
        }
        .overlay {
            CelebrationOverlay(kind: routine.style.celebration, trigger: celebrate)
                .allowsHitTesting(false)
        }
        .sensoryFeedback(.selection, trigger: tapped)
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear {
            if model.editOnOpenID == routineID {
                model.editOnOpenID = nil
                showEdit = true
            }
        }
    }

    private func toggle(_ itemID: UUID) {
        tapped += 1
        if model.toggle(item: itemID, in: routineID) { celebrate += 1 }
    }
}

/// 進み具合の帯。そろうと緑になる。
private struct ProgressBand: View {
    let done: Int
    let total: Int
    let complete: Bool
    let theme: Theme

    var body: some View {
        let ratio = total == 0 ? 0 : Double(done) / Double(total)
        let fill = complete ? Color.green : theme.accentColor
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12).fill(fill.opacity(0.18))
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 12)
                    .fill(fill)
                    .frame(width: geo.size.width * ratio)
                    .animation(.spring(duration: 0.35), value: ratio)
            }
            HStack {
                Text(complete ? "全部そろいました" : "あと\(total - done)つ")
                    .font(.headline)
                Spacer()
                Text("\(done) / \(total)").font(.headline.monospacedDigit())
            }
            .padding(.horizontal, 14)
            .foregroundStyle(ratio > 0.5 ? Color.white : Color.primary)
        }
        .frame(height: 46)
        .accessibilityElement(children: .combine)
    }
}
