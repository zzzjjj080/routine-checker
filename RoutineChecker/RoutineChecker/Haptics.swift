import SwiftUI
import UIKit

/// 押した時の振動。**大きめ**にする（2026-11-15 本人指摘：微振動しかなかった）。
/// `.sensoryFeedback(.selection)` はごく弱いので使わない。強さを明示しないと弱い（引き継ぎ書 4-29）
@MainActor
enum Haptics {
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    /// ボタン・チェック・画面を開いた時
    static func tap() {
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
    }

    /// リストが全部そろった時。成功の振動のあとに強い1回を重ねる
    static func success() {
        notice.prepare()
        notice.notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            tap()
        }
    }
}

extension View {
    /// 開いた画面の側で振動させる（シート・押して開く画面）
    func hapticOnOpen() -> some View { onAppear { Haptics.tap() } }
}
