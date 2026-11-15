import SwiftUI
import MapKit
import CoreLocation
import UserNotifications
import RoutineCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var homeMonitor: HomeMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HomeSettingsView()
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

                Section {
                    LabeledContent("位置情報", value: locationLabel)
                    if !homeMonitor.hasAlways {
                        Button(homeMonitor.authorization == .denied ? "設定アプリで「常に」にする" : "「常に許可」にする") {
                            if homeMonitor.authorization == .denied || homeMonitor.authorization == .restricted {
                                openSettings()
                            } else {
                                homeMonitor.requestAlways()
                            }
                        }
                    }
                    LabeledContent("通知", value: notificationLabel)
                    if notificationStatus == .denied {
                        Button("設定アプリで通知をオンにする") { openSettings() }
                    }
                } header: {
                    Text("許可")
                } footer: {
                    Text("「家にいる間」の通知には、位置情報の「常に許可」が要ります。位置は家の中か外かの判定にだけ使い、端末の外に送りません。")
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
                    LabeledContent("版", value: version)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .task { notificationStatus = await model.notifier.authorizationStatus() }
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
        return "\(v) (\(b))"
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
                    Button("家の場所を消す", role: .destructive) { model.data.home = nil }
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
