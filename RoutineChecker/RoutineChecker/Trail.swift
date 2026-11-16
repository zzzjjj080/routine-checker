import Foundation

/// 家の出入りと「家を出た知らせ」の記録。知らせが出なかった時に、どこで止まったかを見るため。
/// 端末の中だけに置き、新しい40件だけ残す。設定のいちばん下で読める。
enum Trail {
    private static let key = "trail"
    private static let max = 40

    static func add(_ text: String, at date: Date = Date()) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm:ss"
        var list = all
        list.insert("\(f.string(from: date))  \(text)", at: 0)
        UserDefaults.standard.set(Array(list.prefix(max)), forKey: key)
    }

    static var all: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
}
