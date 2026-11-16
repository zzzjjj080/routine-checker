import Foundation
import UserNotifications
import RoutineCore

/// 通知の予約。予約は毎回全部入れ替える（「あとで」の分だけは残す）。
@MainActor
final class Notifier {
    static let category = "routine"
    static let snoozeAction = "snooze"
    static let snoozeMinutes = 30
    private static let snoozePrefix = "snooze-"

    private let center = UNUserNotificationCenter.current()

    func registerCategories() {
        let snooze = UNNotificationAction(identifier: Self.snoozeAction,
                                          title: "\(Self.snoozeMinutes)分後にもう一度", options: [])
        let category = UNNotificationCategory(identifier: Self.category, actions: [snooze],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationIfNeeded() async {
        guard await authorizationStatus() == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func replace(with plan: [PlannedNotification], routines: [Routine], resetTime: TimeOfDay,
                 badgeNow: Int, badgeChanges: [(date: Date, count: Int)]) async {
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { !$0.hasPrefix(Self.snoozePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        // アイコンの数字：いまの数をすぐ出し、アプリが閉じていても変わるよう、変わる時刻に数字だけの通知を置く
        // （数字だけの通知は、画面にも音にも出ない）
        try? await center.setBadgeCount(badgeNow)
        let calendar = Calendar.current
        for change in badgeChanges {
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: change.count)
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: change.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "badge-\(Int(change.date.timeIntervalSince1970))",
                                                        content: content, trigger: trigger))
        }

        let badge = Badge(calendar: calendar, resetTime: resetTime)
        for p in plan {
            guard let routine = routines.first(where: { $0.id == p.routineID }) else { continue }
            let day = calendar.routineDay(of: p.date, resetAt: resetTime)
            let content = Self.content(for: routine, on: day)
            content.badge = NSNumber(value: badge.count(routines, at: p.date))
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: p.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: p.id, content: content, trigger: trigger))
        }
    }

    func snooze(_ routine: Routine, on day: DayKey) {
        let content = Self.content(for: routine, on: day)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(Self.snoozeMinutes * 60), repeats: false)
        center.add(UNNotificationRequest(identifier: Self.snoozePrefix + routine.id.uuidString,
                                         content: content, trigger: trigger))
    }

    /// やり残したまま家を出た知らせ。すぐ出す。集中モード中でも届くように「即時」にする。
    func notifyLeftHome(_ routine: Routine, on day: DayKey, after seconds: Double = 1, badge: Int) {
        let remaining = routine.items.filter { !routine.isChecked($0.id, on: day) }.map(\.title)
        let content = Self.content(for: routine, on: day)
        content.title = "\(routine.name)が残ったまま、家を出ました"
        let shown = remaining.prefix(4).joined(separator: "、")
        let more = remaining.count > 4 ? " ほか\(remaining.count - 4)つ" : ""
        content.body = "まだ：\(shown)\(more)"
        content.interruptionLevel = .timeSensitive
        content.badge = NSNumber(value: badge)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.leftPrefix + routine.id.uuidString,
                                         content: content, trigger: trigger))
    }

    private static let leftPrefix = "snooze-left-"

    func cancelSnooze(for routineID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.snoozePrefix + routineID.uuidString])
    }

    static func content(for routine: Routine, on day: DayKey) -> UNMutableNotificationContent {
        let remaining = routine.items.filter { !routine.isChecked($0.id, on: day) }.map(\.title)
        let content = UNMutableNotificationContent()
        content.title = "\(routine.name)のチェック"
        let shown = remaining.prefix(4).joined(separator: "、")
        let more = remaining.count > 4 ? " ほか\(remaining.count - 4)つ" : ""
        content.body = remaining.isEmpty ? "忘れていませんか？" : "まだ：\(shown)\(more)"
        content.sound = .default
        content.categoryIdentifier = category
        content.threadIdentifier = routine.id.uuidString
        content.userInfo = ["routineID": routine.id.uuidString]
        return content
    }
}

/// 通知を押した・「あとで」を選んだ時の受け口。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// アプリを開いている時も通知を出す。
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["routineID"] as? String
        let action = response.actionIdentifier
        Task { @MainActor in
            defer { completionHandler() }
            guard let raw, let id = UUID(uuidString: raw) else { return }
            let model = AppModel.shared
            if action == Notifier.snoozeAction {
                if let routine = model.routine(id) { model.notifier.snooze(routine, on: model.today) }
            } else if action == UNNotificationDefaultActionIdentifier {
                model.openRoutineID = id
            }
        }
    }
}
