import SwiftUI
import RoutineCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Theme {
    var accentColor: Color { Color(hex: accent) }

    /// ライト / ダークで切り替わる地の色。
    var background: Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? backgroundDark : backgroundLight
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    func tile(_ index: Int) -> Color { Color(hex: tileColor(at: index)) }
}

extension Trigger {
    var isOff: Bool {
        if case .none = self { return true }
        return false
    }
}

enum Labels {
    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]   // Calendar の 1〜7 に対応
    /// 月曜始まりで並べる。
    static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    static func weekdays(_ set: Set<Int>) -> String {
        if set == Weekdays.everyday { return "毎日" }
        if set == Weekdays.weekdays { return "平日" }
        if set == Weekdays.weekends { return "土日" }
        if set.isEmpty { return "曜日なし" }
        return weekdayOrder.filter(set.contains).map { weekdaySymbols[$0 - 1] }.joined()
    }

    static func time(_ t: TimeOfDay) -> String { String(format: "%d:%02d", t.hour, t.minute) }

    static func interval(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)時間ごと" : "\(minutes)分ごと"
    }

    static func trigger(_ trigger: Trigger) -> String {
        switch trigger {
        case .none:
            return "通知なし"
        case .times(let t):
            let times = t.times.sorted().map(time).joined(separator: "・")
            return "\(weekdays(t.weekdays)) \(times)"
        case .atHome(let h):
            return "\(weekdays(h.weekdays)) \(time(h.start))〜\(time(h.end)) 家にいる間 \(interval(h.intervalMinutes))"
        }
    }

    static func layout(_ l: RoutineLayout) -> String {
        switch l {
        case .tiles: return "マス"
        case .list: return "リスト"
        case .cards: return "カード"
        }
    }

    static func celebration(_ c: Celebration) -> String {
        switch c {
        case .glow: return "光る"
        case .confetti: return "紙吹雪"
        case .subtle: return "控えめ"
        case .none: return "なし"
        }
    }
}

/// DatePicker と TimeOfDay をつなぐ。
extension Binding where Value == TimeOfDay {
    var asDate: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: wrappedValue.hour, minute: wrappedValue.minute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                wrappedValue = TimeOfDay(c.hour ?? 0, c.minute ?? 0)
            }
        )
    }
}

/// 曜日を選ぶ7つのボタン。
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Labels.weekdayOrder, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(Labels.weekdaySymbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(on ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
