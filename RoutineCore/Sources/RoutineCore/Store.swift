import Foundation

/// 家の場所。位置は「家の中か外か」の判定にだけ使い、履歴は残さない。
public struct Home: Codable, Hashable, Sendable {
    public static let radiusChoices: [Double] = [100, 150, 300]

    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    public init(latitude: Double, longitude: Double, radius: Double = 150) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

public enum Appearance: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}

/// 保存するもの全部。端末の中だけに置く。
public struct AppData: Codable, Hashable, Sendable {
    public var routines: [Routine]
    public var resetTime: TimeOfDay
    public var home: Home?
    public var appearance: Appearance

    public init(routines: [Routine] = [], resetTime: TimeOfDay = TimeOfDay(3), home: Home? = nil,
                appearance: Appearance = .system) {
        self.routines = routines
        self.resetTime = resetTime
        self.home = home
        self.appearance = appearance
    }

    /// 初めて開いた時のリスト。
    public static var starter: AppData {
        AppData(routines: [
            Routine(name: "朝",
                    text: "薬を飲む\n顔を洗う\n歯をみがく\n水を飲む\n天気を見る",
                    trigger: .times(TimeTrigger()),
                    style: Style(layout: .cards, themeID: 0)),
            Routine(name: "帰り",
                    text: "手を洗う\n弁当箱を出す\nスマホを充電\n明日の準備",
                    trigger: .atHome(HomeTrigger()),
                    style: Style(layout: .tiles, themeID: 3)),
        ])
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> AppData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppData.self, from: data)
    }

    /// 家の判定が要るリストがあるか（なければ位置の見張りをしない）。
    public var needsHome: Bool { routines.contains { $0.trigger.needsHome } }
}
