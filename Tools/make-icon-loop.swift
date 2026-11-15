// 案01「くり返しの輪」の色違い・形違いを10個描く（2026-11-15）。
// 使い方: swift Tools/make-icon-loop.swift design/icon-loop
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
func gradient(_ c: CGContext, _ top: UInt32, _ bottom: UInt32) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [col(top), col(bottom)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
}
func check(_ c: CGContext, cx: CGFloat, cy: CGFloat, size: CGFloat, width: CGFloat, color: UInt32) {
    c.saveGState()
    c.setStrokeColor(col(color)); c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: CGPoint(x: cx - size * 0.5, y: cy + size * 0.02))
    c.addLine(to: CGPoint(x: cx - size * 0.15, y: cy - size * 0.33))
    c.addLine(to: CGPoint(x: cx + size * 0.5, y: cy + size * 0.35))
    c.strokePath(); c.restoreGState()
}
/// 時計の角度（12時=0、時計回り）で点を出す
func pt(_ r: CGFloat, _ deg: CGFloat, _ cx: CGFloat = 512, _ cy: CGFloat = 512) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: cx + r * sin(a), y: cy + r * cos(a))
}
/// 時計回りに from→to の弧を描き、to の位置に進む向きの矢じりを付ける
func loopArrow(_ c: CGContext, r: CGFloat, width: CGFloat, from: CGFloat, to: CGFloat, color: UInt32, head: CGFloat = 1.0,
               cx: CGFloat = 512, cy: CGFloat = 512) {
    c.saveGState()
    c.setStrokeColor(col(color)); c.setLineWidth(width); c.setLineCap(.round)
    c.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: (90 - from) * .pi / 180, endAngle: (90 - to) * .pi / 180, clockwise: true)
    c.strokePath()
    // 矢じり：輪の終わりの少し先を先端に、進む向き（接線）へ
    let a = to * .pi / 180
    let dir = CGPoint(x: cos(a), y: -sin(a))        // 時計回りの接線
    let nrm = CGPoint(x: sin(a), y: cos(a))         // 外向き
    let base = pt(r, to, cx, cy)
    let len = width * 1.9 * head, half = width * 1.25 * head
    let tip = CGPoint(x: base.x + dir.x * len, y: base.y + dir.y * len)
    c.setFillColor(col(color))
    c.move(to: tip)
    c.addLine(to: CGPoint(x: base.x + nrm.x * half, y: base.y + nrm.y * half))
    c.addLine(to: CGPoint(x: base.x - nrm.x * half, y: base.y - nrm.y * half))
    c.closePath(); c.fillPath()
    c.restoreGState()
}
let W: UInt32 = 0xFFFFFF

// 1 もとの形のまま、矢じりの向きを直したもの（青緑）
do { let c = newContext(); gradient(c, 0x2EC4B6, 0x1A8E9E)
    loopArrow(c, r: 320, width: 72, from: 30, to: 300, color: W)
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: W); save(c, "01-青緑（もとの形）") }
// 2 夕焼け
do { let c = newContext(); gradient(c, 0xFFB35C, 0xF2603D)
    loopArrow(c, r: 320, width: 72, from: 30, to: 300, color: W)
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: W); save(c, "02-夕焼け") }
// 3 紫
do { let c = newContext(); gradient(c, 0x8E7CFF, 0x5A45D6)
    loopArrow(c, r: 320, width: 72, from: 30, to: 300, color: W)
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: W); save(c, "03-紫") }
// 4 紺に黄色のチェック
do { let c = newContext(); gradient(c, 0x2B3A67, 0x162040)
    loopArrow(c, r: 320, width: 72, from: 30, to: 300, color: W)
    check(c, cx: 512, cy: 500, size: 300, width: 78, color: 0xFFC94A); save(c, "04-紺と黄") }
// 5 白地に青緑の線（明るい）
do { let c = newContext(); gradient(c, 0xFFFFFF, 0xEAF7F5)
    loopArrow(c, r: 320, width: 72, from: 30, to: 300, color: 0x1FA99B)
    check(c, cx: 512, cy: 500, size: 300, width: 72, color: 0x1FA99B); save(c, "05-白地") }
// 6 黒に金
do { let c = newContext(); gradient(c, 0x2A2A2E, 0x0F0F12)
    loopArrow(c, r: 320, width: 64, from: 30, to: 300, color: 0xE8C26A)
    check(c, cx: 512, cy: 500, size: 300, width: 66, color: 0xE8C26A); save(c, "06-黒と金") }
// 7 太い輪・真ん中に白い丸と色のチェック
do { let c = newContext(); gradient(c, 0x2EC4B6, 0x1A8E9E)
    loopArrow(c, r: 340, width: 96, from: 35, to: 300, color: W, head: 0.9)
    c.setFillColor(col(W)); c.fillEllipse(in: CGRect(x: 512 - 205, y: 512 - 205, width: 410, height: 410))
    check(c, cx: 512, cy: 500, size: 230, width: 62, color: 0x1A9E95); save(c, "07-白い丸の中") }
// 8 矢印2本で1周（くるくる回る感じ）
do { let c = newContext(); gradient(c, 0x4FC3F7, 0x1E7FCB)
    loopArrow(c, r: 320, width: 66, from: 20, to: 150, color: W)
    loopArrow(c, r: 320, width: 66, from: 200, to: 330, color: W)
    check(c, cx: 512, cy: 500, size: 290, width: 70, color: W); save(c, "08-矢印2本") }
// 9 角の丸い四角の輪
do { let c = newContext(); gradient(c, 0x5DD39E, 0x2A9D6F)
    let r = CGRect(x: 192, y: 192, width: 640, height: 640)
    c.setStrokeColor(col(W)); c.setLineWidth(70); c.setLineCap(.round); c.setLineJoin(.round)
    // 上の辺の右寄りで切れ目を作り、時計回りに一周させる
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 600, y: r.maxY))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: 170)
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: 170)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: 170)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: 170)
    p.addLine(to: CGPoint(x: 400, y: r.maxY))
    c.addPath(p); c.strokePath()
    c.setFillColor(col(W))   // 右向きの矢じり
    c.move(to: CGPoint(x: 400 + 130, y: r.maxY)); c.addLine(to: CGPoint(x: 400, y: r.maxY + 88)); c.addLine(to: CGPoint(x: 400, y: r.maxY - 88)); c.closePath(); c.fillPath()
    check(c, cx: 512, cy: 495, size: 290, width: 70, color: W); save(c, "09-四角い輪") }
// 10 細い線（すっきり）
do { let c = newContext(); gradient(c, 0x34C3A0, 0x1B8C7D)
    loopArrow(c, r: 330, width: 40, from: 30, to: 300, color: W, head: 1.3)
    check(c, cx: 512, cy: 500, size: 320, width: 44, color: W); save(c, "10-細い線") }

// 一覧（5×2）
let names = try! FileManager.default.contentsOfDirectory(atPath: out).filter { $0.hasSuffix(".png") && $0 != "一覧.png" }.sorted()
let cell: CGFloat = 300, gap: CGFloat = 40, label: CGFloat = 60
let sheetW = Int(cell * 5 + gap * 6), sheetH = Int((cell + label) * 2 + gap * 3)
let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
sheet.setFillColor(col(0xD9D9DE)); sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
for (i, n) in names.enumerated() {
    let x = gap + CGFloat(i % 5) * (cell + gap), row = i / 5
    let y = CGFloat(sheetH) - gap - CGFloat(row + 1) * (cell + label) - CGFloat(row) * gap + label
    let img = NSImage(contentsOfFile: "\(out)/\(n)")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: cell, height: cell), cornerWidth: cell * 0.225, cornerHeight: cell * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell)); sheet.restoreGState()
    let t = NSAttributedString(string: String(n.dropLast(4)), attributes: [.font: NSFont(name: "HiraginoSans-W6", size: 24)!, .foregroundColor: NSColor.black])
    t.draw(at: CGPoint(x: x + (cell - t.size().width) / 2, y: y - 44))
}
try! NSBitmapImageRep(cgImage: sheet.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "\(out)/一覧.png"))
print("done")
