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
            let condition = CLMonitor.CircularGeographicCondition(center: center, radius: home.radius)
            await monitor.add(condition, identifier: Self.conditionID, assuming: .unsatisfied)
            if let record = await monitor.record(for: Self.conditionID) {
                self.apply(record.lastEvent.state)
            }
            do {
                for try await event in await monitor.events where event.identifier == Self.conditionID {
                    self.apply(event.state)
                }
            } catch {
                // 見張りが止まった。次にアプリを開いた時に作り直す。
            }
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
