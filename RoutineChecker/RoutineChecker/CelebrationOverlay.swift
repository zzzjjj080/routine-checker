import SwiftUI
import RoutineCore

/// そろった瞬間だけ出す演出。`trigger` が増えた時に1回だけ動く。
struct CelebrationOverlay: View {
    let kind: Celebration
    let trigger: Int

    @State private var active = false
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch kind {
                case .glow:
                    Color.green.opacity(active ? 0.28 : 0).ignoresSafeArea()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(.white, .green)
                        .shadow(color: .green.opacity(0.6), radius: 30)
                        .scaleEffect(active ? 1 : 0.3)
                        .opacity(active ? 1 : 0)
                case .confetti:
                    ForEach(pieces) { p in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(p.color)
                            .frame(width: p.size, height: p.size * 1.6)
                            .rotationEffect(.degrees(active ? p.spin : 0))
                            .position(x: p.x * geo.size.width, y: active ? geo.size.height + 40 : -40)
                            .animation(.easeIn(duration: 1.6).delay(p.delay), value: active)
                    }
                case .subtle:
                    Text("そろいました")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .opacity(active ? 1 : 0)
                        .offset(y: active ? 0 : 20)
                case .none:
                    EmptyView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: trigger) { _, _ in play() }
    }

    private func play() {
        guard kind != Celebration.none else { return }
        if kind == .confetti {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            pieces = (0..<60).map { _ in
                Piece(x: .random(in: 0...1), delay: .random(in: 0...0.4), color: colors.randomElement()!,
                      size: .random(in: 6...12), spin: .random(in: 180...720))
            }
            active = false
            DispatchQueue.main.async { active = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { active = false; pieces = [] }
            return
        }
        withAnimation(.spring(duration: 0.3)) { active = true }
        let hold = kind == .glow ? 0.6 : 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
            withAnimation(.easeOut(duration: 0.4)) { active = false }
        }
    }
}
