import SwiftUI
import GradingKit

// S05
struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreService.self) private var store
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var logStage: Stage?

    var body: some View {
        let s = model.summary
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.s6) {
                HStack(spacing: DS.Space.s4) {
                    GradeBadge(grade: s.overallGrade, size: .md)
                    VStack(alignment: .leading) {
                        Text(GradeNames.overall(s.overallGrade)).font(DS.Typo.title)
                        Text("von 9").font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                    }
                }
                PowerMeter(value: s.power, delta: 0, progress: s.progressToNextGrade())

                VStack(alignment: .leading, spacing: DS.Space.s3) {
                    Text("Regionen").font(DS.Typo.headline)
                    if store.isPro {
                        ForEach(model.catalog.regions) { r in
                            NavigationLink(value: r) {
                                RegionBars(regions: [score(r)], weakestID: s.weakest)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            RegionBars(regions: model.catalog.regions.map(score), locked: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Öffnet PRO")
                        Text("Bremst dich gerade: \(model.catalog.region(s.weakest)?.name ?? "")")
                            .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.s2) {
                    Text("Nächster Schritt").font(DS.Typo.headline)
                    if let next = nextStep() {
                        NavigationLink(value: next.line) { LineRow(line: next.line) }.buttonStyle(.plain)
                        PrimaryButton(title: "\(next.stage.name) loggen", size: .sm) { logStage = next.stage }
                    } else {
                        Text("Alle Stufen in dieser Region geschafft.").foregroundStyle(DS.Palette.textMuted)
                    }
                }

                if model.activeLogs().isEmpty {
                    EmptyStateView(symbol: "figure.strengthtraining.functional", title: "Noch kein Satz",
                                   text: "Logge deinen ersten Satz. Erst echte Sätze bewegen dein Power Level.")
                }
            }
            .padding(DS.Layout.gutter)
        }
        .background(DS.Palette.bg)
        .navigationTitle("Rang")
        .navigationDestination(for: Region.self) { RegionDetailView(region: $0) }
        .navigationDestination(for: SkillLine.self) { LineDetailView(line: $0) }
        .toolbar {
            Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Einstellungen")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .sheet(item: $logStage) { LogSheet(stage: $0) }
    }

    private func score(_ r: Region) -> RegionScore {
        RegionScore(id: r.id, name: r.name, grade: model.summary.regionGrades[r.id] ?? 1,
                    score: model.summary.regionScores[r.id] ?? 0)
    }

    /// Schwächste Linie der schwächsten Region, deren nächste Stufe offen ist.
    private func nextStep() -> (line: SkillLine, stage: Stage)? {
        let lines = model.catalog.lines(in: model.summary.weakest)
            .filter { model.currentIndex(of: $0) < $0.stages.count }
            .sorted { (model.summary.lineGrades[$0.id] ?? 0, $0.sort) < (model.summary.lineGrades[$1.id] ?? 0, $1.sort) }
        guard let l = lines.first else { return nil }
        return (l, l.stages[model.currentIndex(of: l)])
    }
}

// S11
struct RegionDetailView: View {
    @Environment(AppModel.self) private var model
    let region: Region

    var body: some View {
        let g = model.summary.regionGrades[region.id] ?? 1
        List {
            Section {
                HStack(spacing: DS.Space.s4) {
                    GradeBadge(grade: g, kind: .region(region.name), size: .md)
                    VStack(alignment: .leading) {
                        Text("Grad \(g) von 9").font(DS.Typo.headline)
                        if model.summary.weakest == region.id {
                            Text("Schwächste Region").font(DS.Typo.footnote).foregroundStyle(DS.Palette.accent)
                        }
                    }
                }
            }
            Section("Linien") {
                ForEach(model.catalog.lines(in: region.id)) { l in
                    NavigationLink(value: l) { LineRow(line: l, compact: true) }
                }
            }
        }
        .navigationTitle(region.name)
    }
}
