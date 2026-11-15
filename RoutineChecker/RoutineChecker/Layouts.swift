import SwiftUI
import RoutineCore

/// マス：色の付いたマスをタップで埋めていく。
struct TilesLayout: View {
    let routine: Routine
    let checked: Set<UUID>
    let theme: Theme
    let onTap: (UUID) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Array(routine.items.enumerated()), id: \.element.id) { index, item in
                    let on = checked.contains(item.id)
                    Button { onTap(item.id) } label: {
                        ZStack(alignment: .topTrailing) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                                .padding(8)
                                .frame(maxWidth: .infinity, minHeight: 84)
                            if on {
                                Image(systemName: "checkmark.circle.fill")
                                    .padding(6)
                            }
                        }
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(theme.tile(index).opacity(on ? 1 : 0.28),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .scaleEffect(on ? 0.97 : 1)
                        .animation(.spring(duration: 0.25), value: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(on ? "済み" : "まだ")
                }
            }
            .padding()
        }
    }
}

/// リスト：縦に並ぶ一般的なチェックリスト。
struct ListLayout: View {
    let routine: Routine
    let checked: Set<UUID>
    let theme: Theme
    let onTap: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(routine.items.enumerated()), id: \.element.id) { index, item in
                    let on = checked.contains(item.id)
                    Button { onTap(item.id) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(on ? theme.tile(index) : Color.secondary)
                            Text(item.title)
                                .font(.body)
                                .strikethrough(on)
                                .foregroundStyle(on ? Color.secondary : Color.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.85),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(on ? "済み" : "まだ")
                }
            }
            .padding()
        }
    }
}

/// カード：まだの物を1つずつ大きく出す。寝ぼけた朝でも迷わない。
struct CardsLayout: View {
    let routine: Routine
    let checked: Set<UUID>
    let theme: Theme
    let onTap: (UUID) -> Void
    /// 「あとで」で飛ばした物。今のカードを選ぶ時に後ろへ回す。
    @State private var skipped: [UUID] = []

    private var remaining: [Item] {
        let rest = routine.items.filter { !checked.contains($0.id) }
        let fresh = rest.filter { !skipped.contains($0.id) }
        let later = skipped.compactMap { id in rest.first { $0.id == id } }
        return fresh + later
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            if let current = remaining.first {
                let index = routine.items.firstIndex { $0.id == current.id } ?? 0
                VStack(spacing: 24) {
                    Text(current.title)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                    Text("タップでできた")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .background(theme.tile(index), in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                .padding(.horizontal, 24)
                .id(current.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .onTapGesture { withAnimation(.spring(duration: 0.35)) { onTap(current.id) } }
                .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > 60 else { return }
                    withAnimation(.spring(duration: 0.35)) {
                        if value.translation.width > 0 {
                            onTap(current.id)
                        } else {
                            skipped.removeAll { $0 == current.id }
                            skipped.append(current.id)
                        }
                    }
                })
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("ダブルタップで済みにする")

                HStack(spacing: 16) {
                    Button("あとで") {
                        withAnimation(.spring(duration: 0.35)) {
                            skipped.removeAll { $0 == current.id }
                            skipped.append(current.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(remaining.count < 2)
                    Button("できた") { withAnimation(.spring(duration: 0.35)) { onTap(current.id) } }
                        .buttonStyle(.borderedProminent)
                }
                .tint(theme.accentColor)
                .controlSize(.large)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text("全部そろいました").font(.title2.bold())
                }
            }
            Spacer(minLength: 0)

            // 全体の様子。押せば直接切り替えられる。
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(routine.items.enumerated()), id: \.element.id) { index, item in
                        let on = checked.contains(item.id)
                        Button { onTap(item.id) } label: {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(theme.tile(index).opacity(on ? 1 : 0.25), in: Capsule())
                                .foregroundStyle(on ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(on ? "済み" : "まだ")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
