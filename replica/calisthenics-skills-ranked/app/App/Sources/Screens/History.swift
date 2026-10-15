import SwiftUI
import Charts

// S12
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var metric = "power"

    var body: some View {
        ProGate(title: "Verlauf", text: "PRO zeigt, wie sich Grad und Power über Wochen entwickeln.") {
            content
        }
        .navigationTitle("Verlauf")
    }

    @ViewBuilder private var content: some View {
        let _ = model.summary
        let points = dailyPoints()
        if points.count < 2 {
            EmptyStateView(symbol: "chart.xyaxis.line", title: "Noch zu wenig Daten",
                           text: "Ab zwei Trainingstagen erscheint hier dein Verlauf.")
        } else {
            VStack(alignment: .leading, spacing: DS.Space.s4) {
                Picker("Wert", selection: $metric) {
                    Text("Power").tag("power")
                    Text("Gesamtgrad").tag("grade")
                }
                .pickerStyle(.segmented)
                Chart(points, id: \.day) { p in
                    if metric == "power" {
                        LineMark(x: .value("Tag", p.date, unit: .day), y: .value("Power", p.power))
                            .foregroundStyle(DS.Palette.accent)
                    } else {
                        LineMark(x: .value("Tag", p.date, unit: .day), y: .value("Grad", p.grade))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(DS.Palette.accent)
                    }
                }
                .chartYScale(domain: metric == "grade" ? 1...9 : 0...max(100, (points.map(\.power).max() ?? 0) + 100))
                .frame(height: 240)
                Spacer()
            }
            .padding(DS.Layout.gutter)
        }
    }

    struct Point { let day: String; let date: Date; let power: Int; let grade: Int }

    /// Letzter Snapshot pro Tag.
    private func dailyPoints() -> [Point] {
        var byDay: [String: RankSnapshot] = [:]
        for s in model.history() { if (byDay[s.localDay]?.takenAt ?? .distantPast) <= s.takenAt { byDay[s.localDay] = s } }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return byDay.values.sorted { $0.localDay < $1.localDay }.compactMap { s in
            f.date(from: s.localDay).map { Point(day: s.localDay, date: $0, power: s.powerLevel, grade: s.overallGrade) }
        }
    }
}
