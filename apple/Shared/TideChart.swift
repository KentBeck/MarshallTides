import SwiftUI

enum Palette {
    static let tide = Color(red: 6 / 255, green: 133 / 255, blue: 160 / 255)
    static let sun = Color(red: 201 / 255, green: 125 / 255, blue: 18 / 255)
    static let moon = Color(red: 106 / 255, green: 95 / 255, blue: 196 / 255)
}

struct ChartStyle {
    var compact = false
    var rail = true
    var axes = true
    var labels = true
    var area = true
    var nowLabel = true

    static let full = ChartStyle()
    static let widgetMedium = ChartStyle(compact: true, nowLabel: false)
    static let widgetSmall = ChartStyle(compact: true, rail: false, axes: false, labels: false, nowLabel: false)
    static let sparkline = ChartStyle(compact: true, rail: false, axes: false, labels: false, area: false, nowLabel: false)
}

/// The tide curve: one scale, night shading from the sun events, a sun/moon
/// rail along the top, highs and lows labelled, the past dashed.
struct TideChart: View {
    let window: ChartWindow
    let extremes: [TideExtreme]
    var style: ChartStyle = .full
    var tint: Color = Palette.tide
    var ink: Color = .primary
    var inkSecondary: Color = .secondary

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size) }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let s = style
        let m: (top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat) = s.compact
            ? (s.rail ? 16 : 6, 6, s.axes ? 14 : 6, s.axes ? 18 : 6)
            : (s.rail ? 52 : 16, 16, s.axes ? 30 : 12, s.axes ? 40 : 12)
        let pw = size.width - m.left - m.right, ph = size.height - m.top - m.bottom
        guard pw > 0, ph > 0, window.curve.count > 1 else { return }

        let heights = window.curve.map(\.height)
        let lo = heights.min() ?? 0, hi = heights.max() ?? 1
        let yMin = floor(lo - (s.compact ? 0.4 : 0.8)), yMax = ceil(hi + (s.compact ? 0.8 : 1.2))
        let span = window.end.timeIntervalSince(window.start)
        func x(_ t: Date) -> CGFloat { m.left + CGFloat(t.timeIntervalSince(window.start) / span) * pw }
        func y(_ h: Double) -> CGFloat { m.top + CGFloat((yMax - h) / (yMax - yMin)) * ph }
        let bottom = m.top + ph
        let mono = Font.Design.monospaced

        // night
        for b in window.nights {
            ctx.fill(Path(CGRect(x: x(b.from), y: m.top, width: x(b.to) - x(b.from), height: ph)),
                     with: .color(ink.opacity(0.07)))
        }
        // grid and y labels
        let step: Double = yMax - yMin > 7 ? 2 : 1
        var v = ceil(yMin / step) * step
        while v <= yMax {
            var p = Path(); p.move(to: CGPoint(x: m.left, y: y(v))); p.addLine(to: CGPoint(x: m.left + pw, y: y(v)))
            ctx.stroke(p, with: .color(inkSecondary.opacity(0.18)), lineWidth: 1)
            if s.axes {
                ctx.draw(Text("\(Int(v))").font(.system(size: s.compact ? 8 : 11, design: mono)).foregroundStyle(inkSecondary),
                         at: CGPoint(x: m.left - 5, y: y(v)), anchor: .trailing)
            }
            v += step
        }
        // x ticks: every 6 hours from local midnight, 12 when cramped; day boundaries emphasised
        let pxPer6h = pw / CGFloat(span / 3600) * 6
        let tickHours: Double = pxPer6h < (s.compact ? 34 : 68) ? 12 : 6
        var t = Station.startOfDay(window.start)
        while t <= window.end {
            if t >= window.start {
                let midnight = Station.calendar.component(.hour, from: t) == 0
                let xx = x(t)
                if midnight {
                    var p = Path(); p.move(to: CGPoint(x: xx, y: m.top)); p.addLine(to: CGPoint(x: xx, y: bottom))
                    ctx.stroke(p, with: .color(inkSecondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                if s.axes {
                    let label = midnight ? (s.compact ? Fmt.weekday(t) : Fmt.day(t)) : Fmt.hourShort(t)
                    ctx.draw(Text(label).font(.system(size: s.compact ? 8 : 11, weight: midnight ? .semibold : .regular, design: mono))
                                .foregroundStyle(midnight ? ink : inkSecondary),
                             at: CGPoint(x: xx, y: bottom + 4), anchor: .top)
                }
            }
            t = t.addingTimeInterval(tickHours * 3600)
        }
        var base = Path(); base.move(to: CGPoint(x: m.left, y: bottom)); base.addLine(to: CGPoint(x: m.left + pw, y: bottom))
        ctx.stroke(base, with: .color(inkSecondary.opacity(0.35)), lineWidth: 1)

        // curve, past dashed, future solid with area
        let pts = window.curve.map { CGPoint(x: x($0.time), y: y($0.height)) }
        let iNow = window.curve.firstIndex { $0.time >= window.now } ?? 0
        func path(_ slice: ArraySlice<CGPoint>) -> Path {
            var p = Path()
            for (i, pt) in slice.enumerated() { if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }
            return p
        }
        let past = pts[0...max(iNow, 0)], future = pts[max(iNow, 0)...]
        let lineWidth: CGFloat = s.compact ? 1.75 : 2
        if future.count > 1 {
            if s.area, let first = future.first, let last = future.last {
                var area = path(future)
                area.addLine(to: CGPoint(x: last.x, y: bottom)); area.addLine(to: CGPoint(x: first.x, y: bottom)); area.closeSubpath()
                ctx.fill(area, with: .linearGradient(Gradient(colors: [tint.opacity(0.16), tint.opacity(0)]),
                                                     startPoint: CGPoint(x: 0, y: m.top), endPoint: CGPoint(x: 0, y: bottom)))
            }
            ctx.stroke(path(future), with: .color(tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        if past.count > 1 {
            ctx.stroke(path(past), with: .color(tint.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [3, 4]))
        }

        // highs and lows
        if s.labels {
            for e in window.extremes {
                let xx = x(e.time), yy = y(e.height)
                let anchor: UnitPoint = xx < m.left + 24 ? .leading : xx > m.left + pw - 24 ? .trailing : .center
                if s.compact {
                    ctx.draw(Text(Fmt.feet(e.height)).font(.system(size: 9, weight: .semibold, design: mono)).foregroundStyle(ink),
                             at: CGPoint(x: xx, y: e.isHigh ? yy - 5 : yy + 5), anchor: anchorFor(anchor, e.isHigh ? .bottom : .top))
                } else {
                    let pt = CGPoint(x: xx, y: e.isHigh ? yy - 9 : yy + 9)
                    let block = Text("\(Fmt.feet(e.height)) ft\n").font(.system(size: 12, weight: .semibold, design: mono)).foregroundStyle(ink)
                        + Text(Fmt.timeShort(e.time)).font(.system(size: 11, design: mono)).foregroundStyle(inkSecondary)
                    ctx.draw(block, at: pt, anchor: anchorFor(anchor, e.isHigh ? .bottom : .top))
                }
                let r: CGFloat = s.compact ? 2 : 3
                let dot = Path(ellipseIn: CGRect(x: xx - r, y: yy - r, width: 2 * r, height: 2 * r))
                ctx.fill(dot, with: .color(.clear))
                ctx.stroke(dot, with: .color(tint), lineWidth: s.compact ? 1.5 : 2)
            }
        }

        // now
        let xn = x(window.now), hn = extremes.isEmpty ? (window.curve[iNow].height) : Tides.height(at: window.now, in: extremes)
        let yn = y(hn)
        var nowLine = Path(); nowLine.move(to: CGPoint(x: xn, y: m.top)); nowLine.addLine(to: CGPoint(x: xn, y: bottom))
        ctx.stroke(nowLine, with: .color(ink.opacity(0.45)), lineWidth: 1)
        let rn: CGFloat = s.compact ? 3.5 : 5
        ctx.fill(Path(ellipseIn: CGRect(x: xn - rn, y: yn - rn, width: 2 * rn, height: 2 * rn)), with: .color(tint))
        if s.nowLabel {
            let right = xn < m.left + pw - 70
            ctx.draw(Text("\(Fmt.feet(hn)) ft now").font(.system(size: 12, weight: .semibold, design: mono)).foregroundStyle(ink),
                     at: CGPoint(x: xn + (right ? 10 : -10), y: yn), anchor: right ? .leading : .trailing)
        }

        // sun / moon rail
        if s.rail {
            let glyph: CGFloat = s.compact ? 10 : 14
            func row(_ events: [SkyEvent], _ yTop: CGFloat, _ color: Color) {
                for ev in events {
                    let xx = x(ev.time)
                    var img = ctx.resolve(Image(systemName: ev.symbol))
                    img.shading = .color(color)
                    ctx.draw(img, in: CGRect(x: xx - glyph / 2, y: yTop, width: glyph, height: glyph))
                    if !s.compact {
                        ctx.draw(Text(Fmt.timeShort(ev.time)).font(.system(size: 10, design: mono)).foregroundStyle(inkSecondary),
                                 at: CGPoint(x: xx, y: yTop + glyph + 2), anchor: .top)
                    }
                }
            }
            if s.compact { row(window.sun, 2, Palette.sun); row(window.moon, 2, Palette.moon) }
            else { row(window.sun, 0, Palette.sun); row(window.moon, 26, Palette.moon) }
        }
    }

    private func anchorFor(_ horizontal: UnitPoint, _ vertical: UnitPoint) -> UnitPoint {
        UnitPoint(x: horizontal.x, y: vertical.y)
    }
}

/// Moon disc with the lit portion for a phase (0 new ... 0.5 full ... 1 new).
struct MoonPhaseView: View {
    let phase: Double
    var size: CGFloat = 24
    var lit: Color = Palette.moon
    var dark: Color = .secondary.opacity(0.3)

    var body: some View {
        Canvas { ctx, sz in
            let r = sz.width / 2 - 1, c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(dark))
            let k = cos(2 * .pi * phase), rx = max(0.01, abs(k) * r)
            let waxing = phase < 0.5
            let bulgeToLit = phase < 0.25 || phase > 0.75
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            // lit limb: right half while waxing, left while waning
            p.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: !waxing)
            // terminator: half-ellipse back to the top
            let bulgeRight = waxing ? bulgeToLit : !bulgeToLit
            let steps = 24
            for i in 0...steps {
                let a = Double.pi / 2 - Double(i) / Double(steps) * .pi // 90° -> -90°
                let px = c.x + (bulgeRight ? 1 : -1) * rx * CGFloat(cos(a))
                let py = c.y + r * CGFloat(sin(a))
                p.addLine(to: CGPoint(x: px, y: py))
            }
            p.closeSubpath()
            ctx.fill(p, with: .color(lit))
        }
        .frame(width: size, height: size)
    }
}
