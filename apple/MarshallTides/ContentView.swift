import SwiftUI
import WidgetKit

/// The same page as the web layout: the display keeps step with the clock
/// every minute; the data is refetched every hour (and shared with the widgets).
struct ContentView: View {
    @State private var data: FetchedData?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                if let data {
                    let m = TideModel(data: data, now: context.date)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header(m)
                            NowStrip(m: m)
                            section("Tide, sun and moon", "Six hours back, thirty ahead · feet above MLLW · night shaded") {
                                TideChart(window: m.window(past: 6 * 3600, future: 30 * 3600), extremes: m.extremes)
                                    .frame(height: 300)
                                    .padding(.vertical, 8)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            section("Next 24 hours", "Temperature and wind, arrows point where the wind blows") {
                                HourlyStrip(hours: m.hourly)
                                DailyRow(days: m.daily)
                            }
                            section("Tide table", "Highs and lows in the chart window") {
                                TideTable(m: m)
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Fetching tides…")
                }
            }
            .navigationTitle("Marshall Tides")
            .toolbar {
                Button { Task { await refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { await refresh(force: false); await hourlyLoop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh(force: false) } }
        }
    }

    private func refresh(force: Bool) async {
        let fresh = await DataStore.shared.load(force: force)
        if fresh != data {
            data = fresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func hourlyLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(DataStore.maxAge))
            await refresh(force: false)
        }
    }

    private func header(_ m: TideModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tomales Bay · NOAA \(Station.id)").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            Text(Fmt.longDate(m.now)).font(.subheadline)
            Text(m.data.isSample ? "Sample data · services unreachable" : "Data \(Fmt.time(m.data.fetchedAt)) · shown \(Fmt.time(m.now))")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((m.data.isSample ? Palette.sun : Palette.tide).opacity(0.15), in: Capsule())
                .foregroundStyle(m.data.isSample ? Palette.sun : Palette.tide)
        }
    }

    private func section<Content: View>(_ title: String, _ sub: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold))
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
    }
}

private struct NowStrip: View {
    let m: TideModel
    var body: some View {
        let cond = Weather.describe(code: m.weather.code, isDay: m.weather.isDay)
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 18) {
            Readout("Tide") {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.feet(m.tide.height)).font(.system(size: 34, weight: .medium, design: .monospaced))
                    Text("ft").foregroundStyle(.secondary)
                    Label(m.tide.rising ? "rising" : "falling", systemImage: m.tide.rising ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.medium)).foregroundStyle(Palette.tide)
                }
                if let n = m.tide.next {
                    Text("\(Text(Fmt.nextTide(n)).bold()) in \(Fmt.duration(n.time.timeIntervalSince(m.now)))")
                }
                if m.tide.upcoming.count > 1 {
                    let a = m.tide.upcoming[1]
                    Text("then \(a.label.lowercased()) \(Fmt.feet(a.height)) ft at \(Fmt.time(a.time))").foregroundStyle(.secondary)
                }
            }
            Readout("Sun") {
                let next = m.isDaytime ? m.sun.sunset : (m.nextSunEvent?.time ?? m.sun.sunrise)
                HStack(spacing: 6) {
                    Image(systemName: m.isDaytime ? "sunset.fill" : "sunrise.fill").foregroundStyle(Palette.sun)
                    Text(Fmt.time(next)).font(.system(size: 28, weight: .medium, design: .monospaced))
                }
                Text("\(Text(m.isDaytime ? "Sunset" : "Sunrise").bold()) in \(Fmt.duration(next.timeIntervalSince(m.now)))")
                Text("Rise \(Fmt.time(m.sun.sunrise)) · Set \(Fmt.time(m.sun.sunset)) · \(Fmt.duration(m.sun.daylight)) of daylight")
                    .foregroundStyle(.secondary)
            }
            Readout("Moon") {
                HStack(spacing: 8) {
                    MoonPhaseView(phase: m.moonIllumination.phase, size: 28)
                    Text("\(Int((m.moonIllumination.fraction * 100).rounded()))%").font(.system(size: 28, weight: .medium, design: .monospaced))
                }
                Text(m.moonName).bold()
                Text("Rise \(m.moon.rise.map(Fmt.time) ?? "—") · Set \(m.moon.set.map(Fmt.time) ?? "—")").foregroundStyle(.secondary)
            }
            Readout("Weather") {
                HStack(spacing: 6) {
                    Image(systemName: cond.symbol).foregroundStyle(.secondary)
                    Text(Fmt.degrees(m.weather.temp)).font(.system(size: 28, weight: .medium, design: .monospaced))
                }
                Text("\(Text(cond.label).bold()) · wind \(Weather.compass(m.weather.direction)) \(Fmt.mph(m.weather.wind)) mph, gusts \(Fmt.mph(m.weather.gust))")
                if let today = m.daily.first {
                    Text("High \(Fmt.degrees(today.high)) · Low \(Fmt.degrees(today.low)) · feels like \(Fmt.degrees(m.weather.feelsLike))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.footnote)
    }
}

private struct Readout<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            content
        }
    }
}

private struct HourlyStrip: View {
    let hours: [Forecast.Hour]
    var body: some View {
        let temps = hours.map(\.temp)
        let lo = temps.min() ?? 0, hi = temps.max() ?? 1
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.offset) { _, h in
                    let cond = Weather.describe(code: h.code, isDay: h.isDay)
                    VStack(spacing: 4) {
                        Text(Fmt.hourShort(h.time)).font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: cond.symbol).font(.body).foregroundStyle(.secondary).frame(height: 20)
                        Capsule().fill(Palette.tide.opacity(0.85))
                            .frame(width: 6, height: 6 + 18 * CGFloat((h.temp - lo) / max(hi - lo, 1)))
                        Text(Fmt.degrees(h.temp)).font(.caption.weight(.semibold).monospacedDigit())
                        HStack(spacing: 2) {
                            Image(systemName: "location.north.fill").font(.system(size: 8))
                                .rotationEffect(.degrees(h.direction + 180))
                            Text(Fmt.mph(h.wind))
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 52)
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DailyRow: View {
    let days: [Forecast.Day]
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                let cond = Weather.describe(code: d.code)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i == 0 ? "Today" : Fmt.weekday(d.date)).font(.caption.weight(.semibold)).textCase(.uppercase)
                    HStack(spacing: 4) {
                        Image(systemName: cond.symbol).foregroundStyle(.secondary)
                        Text(cond.label).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    Text("\(Fmt.degrees(d.high)) / \(Fmt.degrees(d.low))").font(.subheadline.monospacedDigit())
                    Text("wind to \(Fmt.mph(d.windMax)) mph").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TideTable: View {
    let m: TideModel
    var body: some View {
        let rows = m.extremes.filter { $0.time > m.now.addingTimeInterval(-6 * 3600) && $0.time < m.now.addingTimeInterval(30 * 3600) }
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(rows, id: \.time) { e in
                GridRow {
                    Text(Fmt.weekday(e.time))
                    Text(Fmt.time(e.time)).monospacedDigit()
                    Text(e.label)
                    Text("\(Fmt.feet(e.height)) ft").monospacedDigit().gridColumnAlignment(.trailing)
                }
                .foregroundStyle(e.time < m.now ? .secondary : .primary)
                Divider()
            }
        }
        .font(.subheadline)
    }
}
