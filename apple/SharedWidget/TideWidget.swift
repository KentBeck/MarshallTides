import WidgetKit
import SwiftUI

// MARK: - Timeline

struct TideEntry: TimelineEntry {
    let date: Date
    let data: FetchedData
    var model: TideModel { TideModel(data: data, now: date) }
}

/// Entries every five minutes for an hour from one fetch; then WidgetKit
/// asks again and the store refetches if its copy is an hour old.
struct TideTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        TideEntry(date: Date(), data: Sample.data(now: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (TideEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task {
            let data = await DataStore.shared.load()
            completion(TideEntry(date: Date(), data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TideEntry>) -> Void) {
        Task {
            let now = Date()
            let data = await DataStore.shared.load(now: now)
            let entries = stride(from: 0, through: 60, by: 5).map {
                TideEntry(date: now.addingTimeInterval(Double($0) * 60), data: data)
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(DataStore.maxAge))))
        }
    }
}

// MARK: - Widget

struct TideWidget: Widget {
    let kind = "MarshallTides"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TideTimelineProvider()) { entry in
            TideWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Marshall Tides")
        .description("Tide, sun, moon and wind at Marshall on Tomales Bay.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(watchOS)
        return [.accessoryInline, .accessoryRectangular, .accessoryCircular, .accessoryCorner]
        #else
        return [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular, .accessoryCircular]
        #endif
    }
}

struct TideWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TideEntry

    var body: some View {
        let m = entry.model
        switch family {
        case .accessoryInline: InlineView(m: m)
        case .accessoryRectangular: RectangularView(m: m)
        case .accessoryCircular: CircularView(m: m)
        #if os(watchOS)
        case .accessoryCorner: CornerView(m: m)
        #endif
        #if os(iOS)
        case .systemMedium: MediumView(m: m)
        case .systemLarge: LargeView(m: m)
        #endif
        default: SmallView(m: m)
        }
    }
}

// MARK: - Pieces

private struct TrendLabel: View {
    let tide: TideState
    var body: some View {
        Label(tide.rising ? "rising" : "falling", systemImage: tide.rising ? "arrow.up" : "arrow.down")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct BigHeight: View {
    let tide: TideState
    var size: CGFloat = 36
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(Fmt.feet(tide.height))
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("ft").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

private struct SkyLine: View {
    let symbol: String
    let text: String
    var color: Color = .secondary
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text)
        }
    }
}

// MARK: - Home screen (iOS)

struct SmallView: View {
    let m: TideModel
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(Station.shortName.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Palette.tide)
                Spacer()
                TrendLabel(tide: m.tide)
            }
            BigHeight(tide: m.tide)
            if let n = m.tide.next {
                Text(Fmt.nextTide(n)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            TideChart(window: m.window(past: 3 * 3600, future: 21 * 3600), extremes: m.extremes, style: .widgetSmall)
                .frame(height: 40)
            HStack(spacing: 6) {
                SkyLine(symbol: "sunrise.fill", text: Fmt.timeShort(m.sun.sunrise), color: Palette.sun)
                SkyLine(symbol: "sunset.fill", text: Fmt.timeShort(m.sun.sunset), color: Palette.sun)
                Spacer(minLength: 0)
                Text("\(Fmt.degrees(m.weather.temp)) \(Weather.compass(m.weather.direction))\(Fmt.mph(m.weather.wind))")
            }
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

#if os(iOS)
struct MediumView: View {
    let m: TideModel
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(Station.shortName.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Palette.tide)
                    Spacer()
                    TrendLabel(tide: m.tide)
                }
                BigHeight(tide: m.tide)
                if let n = m.tide.next {
                    Text(Fmt.nextTide(n)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 3) {
                    GridRow {
                        SkyLine(symbol: "sunrise.fill", text: Fmt.timeShort(m.sun.sunrise), color: Palette.sun)
                        SkyLine(symbol: "sunset.fill", text: Fmt.timeShort(m.sun.sunset), color: Palette.sun)
                    }
                    GridRow {
                        SkyLine(symbol: "moonrise.fill", text: m.moon.rise.map(Fmt.timeShort) ?? "—", color: Palette.moon)
                        SkyLine(symbol: "moonset.fill", text: m.moon.set.map(Fmt.timeShort) ?? "—", color: Palette.moon)
                    }
                    GridRow {
                        SkyLine(symbol: Weather.describe(code: m.weather.code, isDay: m.weather.isDay).symbol, text: Fmt.degrees(m.weather.temp))
                        SkyLine(symbol: "wind", text: "\(Weather.compass(m.weather.direction)) \(Fmt.mph(m.weather.wind))")
                    }
                }
                .font(.system(size: 11)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TideChart(window: m.window(past: 4 * 3600, future: 20 * 3600), extremes: m.extremes, style: .widgetMedium)
                .frame(width: 176)
        }
    }
}

struct LargeView: View {
    let m: TideModel
    var body: some View {
        let cond = Weather.describe(code: m.weather.code, isDay: m.weather.isDay)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Station.shortName.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Palette.tide)
                Spacer()
                SkyLine(symbol: cond.symbol,
                        text: "\(Fmt.degrees(m.weather.temp)) \(cond.label) · \(Weather.compass(m.weather.direction)) \(Fmt.mph(m.weather.wind)), gusts \(Fmt.mph(m.weather.gust))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    BigHeight(tide: m.tide)
                    TrendLabel(tide: m.tide)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(Array(m.tide.upcoming.prefix(3).enumerated()), id: \.offset) { _, e in
                        Text(Fmt.nextTide(e, short: true))
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            TideChart(window: m.window(past: 6 * 3600, future: 30 * 3600), extremes: m.extremes, style: .widgetMedium)
                .frame(height: 150)
            HStack(spacing: 0) {
                ForEach(Array(m.hourly.enumerated().filter { $0.offset % 3 == 0 }.prefix(8)), id: \.offset) { _, h in
                    VStack(spacing: 2) {
                        Text(Fmt.hourShort(h.time)).font(.system(size: 10)).foregroundStyle(.secondary)
                        Image(systemName: Weather.describe(code: h.code, isDay: h.isDay).symbol).font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(Fmt.degrees(h.temp)).font(.system(size: 11, weight: .semibold))
                        HStack(spacing: 2) {
                            Image(systemName: "location.north.fill").font(.system(size: 7))
                                .rotationEffect(.degrees(h.direction + 180))
                            Text(Fmt.mph(h.wind))
                        }
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                SkyLine(symbol: "sunrise.fill", text: Fmt.timeShort(m.sun.sunrise), color: Palette.sun)
                SkyLine(symbol: "sunset.fill", text: Fmt.timeShort(m.sun.sunset), color: Palette.sun)
                Spacer()
                HStack(spacing: 3) { MoonPhaseView(phase: m.moonIllumination.phase, size: 12); Text(m.moonName) }
                Spacer()
                SkyLine(symbol: "moonrise.fill", text: m.moon.rise.map(Fmt.timeShort) ?? "—", color: Palette.moon)
                SkyLine(symbol: "moonset.fill", text: m.moon.set.map(Fmt.timeShort) ?? "—", color: Palette.moon)
            }
            .font(.system(size: 11)).lineLimit(1)
        }
    }
}
#endif

// MARK: - Accessory (lock screen and watch)

struct InlineView: View {
    let m: TideModel
    var body: some View {
        Label {
            Text("\(Fmt.feet(m.tide.height)) ft · \(m.tide.next.map { Fmt.nextTide($0, short: true) } ?? "")")
        } icon: {
            Image(systemName: m.tide.rising ? "arrow.up" : "arrow.down")
        }
    }
}

struct RectangularView: View {
    let m: TideModel
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Fmt.feet(m.tide.height)) ft").font(.headline).widgetAccentable()
                Image(systemName: m.tide.rising ? "arrow.up" : "arrow.down").font(.caption2.weight(.bold))
                if let n = m.tide.next {
                    Text(Fmt.nextTide(n, short: true)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            TideChart(window: m.window(past: 2 * 3600, future: 22 * 3600), extremes: m.extremes,
                      style: .sparkline, tint: .primary)
                .widgetAccentable()
                .frame(maxWidth: .infinity)
            HStack(spacing: 3) {
                Image(systemName: "sunrise.fill"); Text(Fmt.timeShort(m.sun.sunrise))
                Image(systemName: "sunset.fill"); Text(Fmt.timeShort(m.sun.sunset))
                Text("· \(Fmt.degrees(m.weather.temp)) \(Weather.compass(m.weather.direction))\(Fmt.mph(m.weather.wind))")
            }
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

/// A ring showing where the tide sits in the day's range, plus the next event.
struct CircularView: View {
    let m: TideModel
    var body: some View {
        let nearby = m.extremes.filter { abs($0.time.timeIntervalSince(m.now)) < 15 * 3600 }
        let lo = nearby.map(\.height).min() ?? 0, hi = nearby.map(\.height).max() ?? 1
        let f = max(0, min(1, (m.tide.height - lo) / max(hi - lo, 0.1)))
        Gauge(value: f) {
            Text("ft")
        } currentValueLabel: {
            VStack(spacing: -2) {
                Text(Fmt.feet(m.tide.height)).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(m.tide.rising ? "▲" : "▼").font(.system(size: 7))
            }
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}

#if os(watchOS)
struct CornerView: View {
    let m: TideModel
    var body: some View {
        HStack(spacing: 1) {
            Text(Fmt.feet(m.tide.height)).font(.title3.weight(.semibold).monospacedDigit())
            Image(systemName: m.tide.rising ? "arrow.up" : "arrow.down").font(.caption2.weight(.bold))
        }
        .widgetAccentable()
        .widgetLabel {
            if let n = m.tide.next {
                Text("\(n.isHigh ? "H" : "L") \(Fmt.timeShort(n.time))")
            }
        }
    }
}
#endif
