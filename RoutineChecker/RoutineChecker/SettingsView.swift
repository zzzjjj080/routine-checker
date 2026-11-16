import SwiftUI
import MapKit
import CoreLocation
import UserNotifications
import RoutineCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var homeMonitor: HomeMonitor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HomeSettingsView()
                            .hapticOnOpen()
                    } label: {
                        LabeledContent("家の場所") {
                            Text(model.data.home.map { "半径\(Int($0.radius))m" } ?? "未設定")
                        }
                    }
                    if model.data.home != nil {
                        LabeledContent("今", value: model.isHome ? "家にいる" : "家の外")
                    }
                } header: {
                    Text("家")
                }

                // みんなの電波と同じ作り：行全体を押せる。まだ聞いていなければ許可を聞き、
                // もう答えたあとは設定アプリのこのアプリのページを開く。
                // iOS は「常に」を一度しか聞いてくれないので、「使用中のみ」と答えたあとはアプリからは変えられない
                Section {
                    PermissionRow(icon: "location.fill", title: "位置情報", value: locationLabel,
                                  ok: homeMonitor.hasAlways,
                                  note: homeMonitor.hasAlways ? nil : locationNote) {
                        homeMonitor.requestAlways(openSettingsIfNeeded: true)   // 聞けなければ設定アプリを開く
                    }
                    .accessibilityIdentifier("locationRow")
                    PermissionRow(icon: "bell.fill", title: "通知", value: notificationLabel,
                                  ok: notificationOK,
                                  note: notificationOK ? nil : "押すと設定アプリが開きます。「通知を許可」をオンにしてください。") {
                        if notificationStatus == .notDetermined {
                            Task {
                                await model.notifier.requestAuthorizationIfNeeded()
                                notificationStatus = await model.notifier.authorizationStatus()
                            }
                        } else {
                            openSettings()
                        }
                    }
                    .accessibilityIdentifier("notificationRow")
                } header: {
                    Text("許可")
                } footer: {
                    Label("位置は家の中か外かの判定にだけ使い、端末の外に送りません。", systemImage: "lock.shield")
                }

                Section {
                    DatePicker("チェックが空になる時刻", selection: $model.data.resetTime.asDate,
                               displayedComponents: .hourAndMinute)
                    Picker("画面の明るさ", selection: $model.data.appearance) {
                        Text("自動").tag(Appearance.system)
                        Text("ライト").tag(Appearance.light)
                        Text("ダーク").tag(Appearance.dark)
                    }
                } footer: {
                    Text("夜ふかしで日付をまたいでも消えないよう、チェックは指定の時刻（はじめは午前3時）に空になります。")
                }

                Section {
                    LabeledContent("いまの判定", value: model.data.home == nil ? "家の場所が未設定" : (model.isHome ? "家の中" : "家の外"))
                    DisclosureGroup("家の出入りの記録") {
                        let lines = Trail.all
                        if lines.isEmpty { Text("まだありません").foregroundStyle(.secondary) }
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.caption.monospacedDigit()).textSelection(.enabled)
                        }
                    }
                } header: {
                    Text("家を出た知らせ")
                } footer: {
                    Text("知らせが出なかった時は、ここを見るとどこで止まったか分かります。")
                }

                Section {
                    LabeledContent("版", value: version)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { Haptics.tap(); dismiss() } } }
            .task { notificationStatus = await model.notifier.authorizationStatus() }
            // 設定アプリから戻ってきたら、変わった許可をすぐ出し直す
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                homeMonitor.refreshAuthorization()
                Task { notificationStatus = await model.notifier.authorizationStatus() }
            }
        }
    }

    private var locationLabel: String {
        switch homeMonitor.authorization {
        case .authorizedAlways: return "常に許可"
        case .authorizedWhenInUse: return "使用中のみ"
        case .denied: return "許可しない"
        case .restricted: return "制限あり"
        default: return "未設定"
        }
    }

    private var locationNote: String {
        switch homeMonitor.authorization {
        case .notDetermined: return "押すと許可を聞きます。「使用中のみ」のあとに出る画面で「常に許可」を選んでください。"
        default: return "「家にいる間」の通知には「常に」が要ります。押すと設定アプリが開くので、位置情報 →「常に」に。"
        }
    }

    private var notificationOK: Bool {
        [.authorized, .provisional, .ephemeral].contains(notificationStatus)
    }

    private var notificationLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "オン"
        case .denied: return "オフ"
        default: return "未設定"
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        // install-device.sh が入れる印（コミット数・ビルド時刻）。Xcode から直接ビルドすると空
        guard let stamp = Bundle.main.infoDictionary?["RCBuildStamp"] as? String, !stamp.isEmpty else { return "\(v) (\(b))" }
        return "\(v) (\(b)) · \(stamp)"
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// 家の場所：地図を押して決めるか、今いる場所にする。
struct HomeSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var homeMonitor: HomeMonitor
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var locating = false

    var body: some View {
        let home = model.data.home
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    if let home {
                        let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
                        MapCircle(center: center, radius: home.radius)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .foregroundStyle(Color.accentColor.opacity(0.2))
                        Marker("家", systemImage: "house.fill", coordinate: center)
                    }
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) { setHome(coordinate) }
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                Text("地図を押した場所が家になります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("範囲", selection: radiusBinding) {
                    ForEach(Home.radiusChoices, id: \.self) { Text("\(Int($0))m").tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(home == nil)

                Button {
                    Haptics.tap()
                    Task {
                        locating = true
                        homeMonitor.requestAlways()
                        if let c = await homeMonitor.currentLocation() { setHome(c, move: true) }
                        locating = false
                    }
                } label: {
                    Label(locating ? "場所を調べています…" : "今いる場所を家にする", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(locating)

                if home != nil {
                    Button("家の場所を消す", role: .destructive) { Haptics.tap(); model.data.home = nil }
                        .font(.footnote)
                }
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("家の場所")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let home {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
                    latitudinalMeters: 1200, longitudinalMeters: 1200))
            }
        }
    }

    private var radiusBinding: Binding<Double> {
        Binding(get: { model.data.home?.radius ?? 150 },
                set: { model.data.home?.radius = $0 })
    }

    private func setHome(_ c: CLLocationCoordinate2D, move: Bool = false) {
        model.data.home = Home(latitude: c.latitude, longitude: c.longitude, radius: model.data.home?.radius ?? 150)
        if !homeMonitor.hasAlways { homeMonitor.requestAlways() }
        if move {
            position = .region(MKCoordinateRegion(center: c, latitudinalMeters: 1200, longitudinalMeters: 1200))
        }
    }
}

/// 許可の1行。行のどこを押しても反応する。足りないときは橙で、下に何をすればいいかを出す。
private struct PermissionRow: View {
    let icon: String
    let title: String
    let value: String
    let ok: Bool
    let note: String?
    let action: () -> Void
    @State private var tapped = 0

    var body: some View {
        Button {
            tapped += 1
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(ok ? Color.green : Color.orange, in: RoundedRectangle(cornerRadius: 7))
                    Text(title).foregroundStyle(Color.primary)
                    Spacer()
                    Text(value).font(.subheadline.bold()).foregroundStyle(ok ? Color.green : Color.orange)
                    Image(systemName: "arrow.up.forward.app").font(.footnote).foregroundStyle(.secondary)
                }
                if let note {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: tapped) { Haptics.tap() }
    }
}
