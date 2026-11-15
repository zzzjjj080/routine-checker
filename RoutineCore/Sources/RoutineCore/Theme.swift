/// 色のテーマ。色は 0xRRGGBB。
public struct Theme: Hashable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    /// 画面の地の色（ライト / ダーク）。
    public var backgroundLight: UInt32
    public var backgroundDark: UInt32
    /// 進み具合・ボタンなどの主な色。
    public var accent: UInt32
    /// 項目の色。マスや札で、上から順に繰り返して使う。
    public var tiles: [UInt32]

    public func tileColor(at index: Int) -> UInt32 {
        tiles[((index % tiles.count) + tiles.count) % tiles.count]
    }

    public static func theme(id: Int) -> Theme {
        all.first { $0.id == id } ?? all[0]
    }

    public static let all: [Theme] = [
        Theme(id: 0, name: "朝焼け", backgroundLight: 0xFFF7EF, backgroundDark: 0x2A1E1A,
              accent: 0xF0743E, tiles: [0xF7A072, 0xF9C74F, 0xF28482, 0xF6BD60, 0xE5989B]),
        Theme(id: 1, name: "若葉", backgroundLight: 0xF3F8EE, backgroundDark: 0x18241A,
              accent: 0x4F9D69, tiles: [0x90C978, 0xB5D99C, 0x6BB38A, 0xD3E4A5, 0x7FB7A4]),
        Theme(id: 2, name: "海", backgroundLight: 0xEEF6FA, backgroundDark: 0x14212B,
              accent: 0x2D7DD2, tiles: [0x7EC4E6, 0x97D8C4, 0x6C9BD2, 0xB8E0F6, 0x5FA8D3]),
        Theme(id: 3, name: "夜", backgroundLight: 0xF0EFF7, backgroundDark: 0x15152A,
              accent: 0x6C63FF, tiles: [0x8E8CD8, 0xB59FDB, 0x6A7FDB, 0xC3B8F0, 0x7D9BE0]),
        Theme(id: 4, name: "和紙", backgroundLight: 0xF7F3EA, backgroundDark: 0x24211C,
              accent: 0x9C3D2E, tiles: [0xC8553D, 0x588B8B, 0xD9A441, 0x5D6D9C, 0x8E6C8A]),
        Theme(id: 5, name: "モノ", backgroundLight: 0xF5F5F5, backgroundDark: 0x1A1A1A,
              accent: 0x333333, tiles: [0x9E9E9E, 0xBDBDBD, 0x757575, 0xD0D0D0, 0x8A8A8A]),
    ]
}
