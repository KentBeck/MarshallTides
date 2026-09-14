import SwiftUI
import WidgetKit

/// Two pages: the tide, then sun, moon and wind. Display every minute, data hourly.
struct WatchContentView: View {
    @State private var data: FetchedData?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let data {
                let m = TideModel(data: data, now: context.date)
                TabView {
                    tidePage(m)
                    skyPage(m)
                }
                .tabViewStyle(.verticalPage)
            } else {
                ProgressView("Fetching…")
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

    private func tidePage(_ m: TideModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Fmt.feet(m.tide.height)).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("ft").foregroundStyle(.secondary)
                Image(systemName: m.tide.rising ? "arrow.up" : "arrow.down").font(.caption.weight(.bold)).foregroundStyle(Palette.tide)
            }
            if let n = m.tide.next {
                Text("\(Fmt.nextTide(n, short: true)) · in \(Fmt.duration(n.time.timeIntervalSince(m.now)))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            TideChart(window: m.window(past: 3 * 3600, future: 21 * 3600), extremes: m.extremes, style: .widgetMedium)
                .frame(maxHeight: .infinity)
            if m.data.isSample {
                Text("Sample data").font(.caption2).foregroundStyle(Palette.sun)
            }
        }
        .navigationTitle(Station.shortName)
    }

    private func skyPage(_ m: TideModel) -> some View {
        let cond = Weather.describe(code: m.weather.code, isDay: m.weather.isDay)
        return List {
            row("sunrise.fill", Palette.sun, "Sunrise", Fmt.time(m.sun.sunrise))
            row("sunset.fill", Palette.sun, "Sunset", Fmt.time(m.sun.sunset))
            row("moonrise.fill", Palette.moon, "Moonrise", m.moon.rise.map(Fmt.time) ?? "—")
            row("moonset.fill", Palette.moon, "Moonset", m.moon.set.map(Fmt.time) ?? "—")
            HStack {
                MoonPhaseView(phase: m.moonIllumination.phase, size: 16)
                Text(m.moonName)
                Spacer()
                Text("\(Int((m.moonIllumination.fraction * 100).rounded()))%").foregroundStyle(.secondary)
            }
            row(cond.symbol, .secondary, cond.label, Fmt.degrees(m.weather.temp))
            row("wind", .secondary, "Wind \(Weather.compass(m.weather.direction))", "\(Fmt.mph(m.weather.wind)) mph")
            if let today = m.daily.first {
                row("thermometer.medium", .secondary, "High / Low", "\(Fmt.degrees(today.high)) / \(Fmt.degrees(today.low))")
            }
        }
        .font(.footnote)
    }

    private func row(_ symbol: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
