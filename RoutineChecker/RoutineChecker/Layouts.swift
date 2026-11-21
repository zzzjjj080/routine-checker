import SwiftUI
import RoutineCore

/// やることの一覧。1行に1つ、1列で、全部がいつも見えている。
/// 行の高さは画面を項目の数で割って決めるので、10個くらいまではスクロールせずに1画面に収まる。
/// 入りきらない数になった時だけスクロールする。
struct ChecklistLayout: View {
    let routine: Routine
    let checked: Set<UUID>
    let theme: Theme
    let onTap: (UUID) -> Void

    private let spacing: CGFloat = 8
    private let minRow: CGFloat = 48
    private let maxRow: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let n = CGFloat(max(routine.items.count, 1))
            let available = geo.size.height - 16 * 2 - spacing * (n - 1)
            let row = min(maxRow, max(minRow, available / n))
            let fits = row * n + spacing * (n - 1) + 32 <= geo.size.height + 0.5
            let rows = VStack(spacing: spacing) {
                ForEach(Array(routine.items.enumerated()), id: \.element.id) { index, item in
                    ChecklistRow(title: item.title, on: checked.contains(item.id),
                                 color: theme.tile(index), height: row) { onTap(item.id) }
                }
            }
            .padding(16)

            if fits {
                rows.frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView { rows }
            }
        }
    }
}

private struct ChecklistRow: View {
    let title: String
    let on: Bool
    let color: Color
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        // 行が高いほど字も大きく（48pt で 17、96pt で 26 くらい）
        let size = min(26, max(17, height * 0.27))
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: size + 6, weight: .semibold))
                    .foregroundStyle(on ? Color.white : color)
                Text(title)
                    .font(.system(size: size, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .strikethrough(on)
                    .foregroundStyle(on ? Color.white : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color.opacity(on ? 1 : 0.22), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .animation(.spring(duration: 0.25), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? "済み" : "まだ")
    }
}
