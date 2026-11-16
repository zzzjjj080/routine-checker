import CoreLocation
import UIKit
import RoutineCore

/// 家の周りの円への出入りを見張る。
///
/// `CLMonitor` はアプリが閉じていても、再起動後でも、出入りの瞬間にアプリを起こしてくれる。
/// 起こされたら同じ名前で作り直して `events` を待てば、その出入りが届く。
@MainActor
final class HomeMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus

    /// 家にいる / いないが分かった時に呼ぶ。
    var onChange: ((Bool) -> Void)?

    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private var eventsTask: Task<Void, Never>?
    private var wantsAlways = false
    private static let conditionID = "home"

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var hasAlways: Bool { authorization == .authorizedAlways }

    func refreshAuthorization() {
        authorization = manager.authorizationStatus
    }

    /// 「常に許可」を求める。iOS では、まず「使用中のみ」を聞いてから「常に」を聞く2段になる。
    /// **iOS が「常に」を聞いてくれるのは1回だけ。** もう答えたあとに頼んでも何も出ないので、
    /// その時は設定アプリのこのアプリのページを開く（みんなの電波と同じ。押しても何も起きない、を無くす）
    /// `openSettingsIfNeeded` は、押した人が「常に」にしたくて押した行（設定の位置情報）だけ true にする。
    /// 家の場所を決めた・保存した、のついでに呼ぶところでは、急に設定アプリへ飛ばない
    func requestAlways(openSettingsIfNeeded: Bool = false) {
        switch manager.authorizationStatus {
        case .notDetermined:
            wantsAlways = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where !UserDefaults.standard.bool(forKey: Self.askedAlwaysKey):
            UserDefaults.standard.set(true, forKey: Self.askedAlwaysKey)
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        default:
            if openSettingsIfNeeded { Self.openAppSettings() }
        }
    }

    private static let askedAlwaysKey = "askedAlways"

    static func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse && self.wantsAlways {
                self.wantsAlways = false
                UserDefaults.standard.set(true, forKey: Self.askedAlwaysKey)
                self.manager.requestAlwaysAuthorization()
            }
        }
    }

    /// 家の場所を見張る。`nil` なら見張りをやめる。
    func watch(_ home: Home?) {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            guard let self else { return }
            let monitor: CLMonitor
            if let existing = self.monitor {
                monitor = existing
            } else {
                monitor = await CLMonitor("RoutineCheckerHome")
                self.monitor = monitor
            }
            guard let home else {
                await monitor.remove(Self.conditionID)
                self.onChange?(false)
                return
            }
            let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
            // 同じ円をもう見張っていれば、足し直さない。
            // 家を出てアプリが裏で起こされた時に毎回足し直すと、見張りが「不明」からやり直しになり、
            // 届くはずの「出た」が消えてしまう（家を出ても知らせが出なかった原因の候補）
            let existing = await monitor.record(for: Self.conditionID)
            let same = (existing?.condition as? CLMonitor.CircularGeographicCondition).map {
                abs($0.center.latitude - center.latitude) < 1e-7 && abs($0.center.longitude - center.longitude) < 1e-7
                    && abs($0.radius - home.radius) < 0.5
            } ?? false
            if !same {
                let condition = CLMonitor.CircularGeographicCondition(center: center, radius: home.radius)
                await monitor.add(condition, identifier: Self.conditionID, assuming: .unsatisfied)
                Trail.add("家の見張りを始めた（半径\(Int(home.radius))m）")
            }
            if let record = await monitor.record(for: Self.conditionID) {
                Trail.add("起動：いまは\(Self.label(record.lastEvent.state))")
                self.apply(record.lastEvent.state)
            }
            do {
                for try await event in await monitor.events where event.identifier == Self.conditionID {
                    Trail.add("出入り：\(Self.label(event.state))")
                    self.apply(event.state)
                }
            } catch {
                Trail.add("見張りが止まった：\(error.localizedDescription)")
                // 次にアプリを開いた時に作り直す。
            }
        }
    }

    private static func label(_ state: CLMonitor.Event.State) -> String {
        switch state {
        case .satisfied: return "家の中"
        case .unsatisfied: return "家の外"
        case .unknown: return "不明"
        case .unmonitored: return "見張っていない"
        @unknown default: return "?"
        }
    }

    private func apply(_ state: CLMonitor.Event.State) {
        switch state {
        case .satisfied: onChange?(true)
        case .unsatisfied: onChange?(false)
        default: break
        }
    }

    /// 今いる場所を1回だけ取る。
    func currentLocation() async -> CLLocationCoordinate2D? {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location, location.horizontalAccuracy >= 0,
                   location.horizontalAccuracy < 100 {
                    return location.coordinate
                }
                if update.authorizationDenied { return nil }
            }
        } catch {
            return nil
        }
        return nil
    }
}
