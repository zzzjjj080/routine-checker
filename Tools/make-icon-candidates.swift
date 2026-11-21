// アイコンの案を10個描く（2026-11-15）。名前は「ルーティン」。
// 使い方: swift Tools/make-icon-candidates.swift design/icon-candidates
// 透過なし 1024×1024。角丸は iOS が付けるので四角のまま描く。
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments[1]

func col(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a)
}
func newContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func save(_ c: CGContext, _ name: String) {
    try! NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
/// 上から下へのグラデーション（y は下が0）
func gradient(_ c: CGContext, _ top: UInt32, _ bottom: UInt32) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [col(top), col(bottom)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
}
func fill(_ c: CGContext, _ h: UInt32) { c.setFillColor(col(h)); c.fill(CGRect(x: 0, y: 0, width: S, height: S)) }
/// チェック印。中心と大きさ、太さで描く
func check(_ c: CGContext, cx: CGFloat, cy: CGFloat, size: CGFloat, width: CGFloat, color: UInt32) {
    c.saveGState()
    c.setStrokeColor(col(color)); c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: CGPoint(x: cx - size * 0.5, y: cy + size * 0.02))
    c.addLine(to: CGPoint(x: cx - size * 0.15, y: cy - size * 0.33))
    c.addLine(to: CGPoint(x: cx + size * 0.5, y: cy + size * 0.35))
    c.strokePath()
    c.restoreGState()
}
func roundRect(_ c: CGContext, _ r: CGRect, _ radius: CGFloat, fill h: UInt32, alpha: CGFloat = 1) {
    c.setFillColor(col(h, alpha)); c.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.fillPath()
}
func circle(_ c: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, fill h: UInt32, alpha: CGFloat = 1) {
    c.setFillColor(col(h, alpha)); c.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}
func ring(_ c: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, width: CGFloat, color h: UInt32, alpha: CGFloat = 1,
          from: CGFloat = 0, to: CGFloat = 360) {
    c.saveGState()
    c.setStrokeColor(col(h, alpha)); c.setLineWidth(width); c.setLineCap(.round)
    // 角度は12時から時計回り
    let a0 = (90 - from) * .pi / 180, a1 = (90 - to) * .pi / 180
    c.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: a0, endAngle: a1, clockwise: true)
    c.strokePath()
    c.restoreGState()
}
let W: UInt32 = 0xFFFFFF

// 01 くり返しの矢印：毎日まわる輪の中にチェック
do {
    let c = newContext(); gradient(c, 0x2EC4B6, 0x1A8E9E)
    ring(c, 512, 512, 330, width: 70, color: W, from: 40, to: 330)
    // 矢じり（輪の終わり＝330°の位置）
    let a = (90 - 330.0) * Double.pi / 180
    let p = CGPoint(x: 512 + 330 * cos(a), y: 512 + 330 * sin(a))
    c.setFillColor(col(W))
    c.move(to: CGPoint(x: p.x - 95, y: p.y + 20)); c.addLine(to: CGPoint(x: p.x + 70, y: p.y + 85)); c.addLine(to: CGPoint(x: p.x + 40, y: p.y - 95)); c.fillPath()
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: W)
    save(c, "01-くり返しの輪")
}
// 02 朝日：地平線から昇る太陽の中にチェック
do {
    let c = newContext(); gradient(c, 0xFFD27A, 0xFF8A5B)
    circle(c, 512, 400, 300, fill: W)
    c.setFillColor(col(0xF26B4E)); c.fill(CGRect(x: 0, y: 0, width: S, height: 300))
    check(c, cx: 512, cy: 470, size: 300, width: 68, color: 0xF26B4E)
    for i in 0..<5 { let x = CGFloat(150 + i * 180); roundRect(c, CGRect(x: x, y: 190, width: 90, height: 26), 13, fill: W, alpha: 0.55) }
    save(c, "02-朝日")
}
// 03 家：家の形の中にチェック（家にいる間に知らせる）
do {
    let c = newContext(); gradient(c, 0x34477A, 0x1E2A4F)
    c.setFillColor(col(W))
    c.move(to: CGPoint(x: 512, y: 840)); c.addLine(to: CGPoint(x: 870, y: 520)); c.addLine(to: CGPoint(x: 780, y: 520))
    c.addLine(to: CGPoint(x: 780, y: 180)); c.addLine(to: CGPoint(x: 244, y: 180)); c.addLine(to: CGPoint(x: 244, y: 520))
    c.addLine(to: CGPoint(x: 154, y: 520)); c.closePath(); c.fillPath()
    check(c, cx: 512, cy: 400, size: 300, width: 70, color: 0x3DBE7A)
    save(c, "03-家")
}
// 04 1列の帯：アプリの画面そのまま。上の3本はそろった色
do {
    let c = newContext(); fill(c, 0xFFF6EC)
    let colors: [UInt32] = [0xF7A072, 0xF9C74F, 0xF28482, 0xF6BD60, 0xE5989B]
    for i in 0..<5 {
        let y = CGFloat(760 - i * 150)
        let done = i < 3
        roundRect(c, CGRect(x: 150, y: y, width: 724, height: 118), 30, fill: colors[i], alpha: done ? 1 : 0.32)
        if done { circle(c, 222, y + 59, 34, fill: W); check(c, cx: 222, cy: y + 57, size: 40, width: 13, color: colors[i]) }
        else { ring(c, 222, y + 59, 30, width: 10, color: colors[i]) }
        roundRect(c, CGRect(x: 290, y: y + 46, width: done ? 380 : 300, height: 26), 13, fill: done ? W : colors[i], alpha: done ? 0.9 : 0.7)
    }
    save(c, "04-1列の帯")
}
// 05 進み具合の輪：4分の3まで満ちた輪とチェック
do {
    let c = newContext(); gradient(c, 0x7B6CF6, 0x4B3FC8)
    ring(c, 512, 512, 320, width: 90, color: W, alpha: 0.25)
    ring(c, 512, 512, 320, width: 90, color: W, from: 0, to: 270)
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: W)
    save(c, "05-進み具合の輪")
}
// 06 日めくり：今日のページに大きなチェック
do {
    let c = newContext(); fill(c, 0xF3EFE6)
    roundRect(c, CGRect(x: 190, y: 160, width: 644, height: 680), 70, fill: W)
    c.saveGState(); c.addPath(CGPath(roundedRect: CGRect(x: 190, y: 160, width: 644, height: 680), cornerWidth: 70, cornerHeight: 70, transform: nil)); c.clip()
    c.setFillColor(col(0xE5484D)); c.fill(CGRect(x: 190, y: 650, width: 644, height: 190)); c.restoreGState()
    for x in [340.0, 684.0] { roundRect(c, CGRect(x: x - 22, y: 790, width: 44, height: 110), 22, fill: 0x444444) }
    check(c, cx: 512, cy: 400, size: 330, width: 78, color: 0xE5484D)
    save(c, "06-日めくり")
}
// 07 時計：針がチェックの形になっている
do {
    let c = newContext(); gradient(c, 0x9BE3C3, 0x3FB98A)
    circle(c, 512, 512, 360, fill: W)
    for i in 0..<12 {
        let a = Double(i) * Double.pi / 6
        let r1: Double = 315, r2: Double = i % 3 == 0 ? 265 : 290
        c.setStrokeColor(col(0x2E8B6A)); c.setLineWidth(i % 3 == 0 ? 22 : 12); c.setLineCap(.round)
        c.move(to: CGPoint(x: 512 + r1 * sin(a), y: 512 + r1 * cos(a))); c.addLine(to: CGPoint(x: 512 + r2 * sin(a), y: 512 + r2 * cos(a))); c.strokePath()
    }
    check(c, cx: 530, cy: 500, size: 330, width: 60, color: 0x2E8B6A)
    circle(c, 478, 390, 22, fill: 0x2E8B6A)
    save(c, "07-時計")
}
// 08 玄関のドア：出かける前・帰ったら
do {
    let c = newContext(); gradient(c, 0xF4E1C1, 0xE9C893)
    roundRect(c, CGRect(x: 290, y: 130, width: 444, height: 760), 40, fill: 0x8A5A3B)
    roundRect(c, CGRect(x: 340, y: 180, width: 344, height: 660), 24, fill: 0xA06B47)
    circle(c, 630, 500, 26, fill: 0xF4D06F)
    circle(c, 512, 640, 130, fill: W)
    check(c, cx: 512, cy: 635, size: 140, width: 36, color: 0x3DBE7A)
    save(c, "08-玄関のドア")
}
// 09 流れの点：済み・済み・まだ を線でつなぐ（毎日の手順）
do {
    let c = newContext(); gradient(c, 0x2B2D42, 0x14151F)
    c.setStrokeColor(col(W, 0.35)); c.setLineWidth(22)
    c.move(to: CGPoint(x: 512, y: 790)); c.addLine(to: CGPoint(x: 512, y: 234)); c.strokePath()
    let ys: [CGFloat] = [790, 512, 234]
    for (i, y) in ys.enumerated() {
        if i < 2 { circle(c, 512, y, 115, fill: 0xFFB703); check(c, cx: 512, cy: y - 4, size: 120, width: 34, color: 0x2B2D42) }
        else { circle(c, 512, y, 115, fill: 0x2B2D42); ring(c, 512, y, 100, width: 28, color: 0xFFB703) }
    }
    save(c, "09-流れの点")
}
// 10 1週間の丸：7つの丸のうち6つ塗り、最後に大きなチェック（続いている）
do {
    let c = newContext(); gradient(c, 0xFF6B9A, 0xD93D6E)
    for i in 0..<7 {
        let x = 152 + CGFloat(i) * 120
        if i < 6 { circle(c, x, 300, 44, fill: W) } else { ring(c, x, 300, 38, width: 14, color: W) }
    }
    check(c, cx: 512, cy: 640, size: 380, width: 86, color: W)
    save(c, "10-1週間の丸")
}

// 一覧（5×2）
let names = try! FileManager.default.contentsOfDirectory(atPath: out).filter { $0.hasSuffix(".png") && $0 != "一覧.png" }.sorted()
let cell: CGFloat = 300, gap: CGFloat = 40, label: CGFloat = 60
let sheetW = Int(cell * 5 + gap * 6), sheetH = Int((cell + label) * 2 + gap * 3)
let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
sheet.setFillColor(col(0xF2F2F7)); sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
for (i, n) in names.enumerated() {
    let colI = i % 5, row = i / 5
    let x = gap + CGFloat(colI) * (cell + gap)
    let y = CGFloat(sheetH) - gap - CGFloat(row + 1) * (cell + label) - CGFloat(row) * gap + label
    let img = NSImage(contentsOfFile: "\(out)/\(n)")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: cell, height: cell), cornerWidth: cell * 0.225, cornerHeight: cell * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell)); sheet.restoreGState()
    let t = NSAttributedString(string: String(n.dropLast(4)), attributes: [.font: NSFont(name: "HiraginoSans-W6", size: 26)!, .foregroundColor: NSColor.black])
    t.draw(at: CGPoint(x: x + (cell - t.size().width) / 2, y: y - 44))
}
try! NSBitmapImageRep(cgImage: sheet.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "\(out)/一覧.png"))
print("done")
