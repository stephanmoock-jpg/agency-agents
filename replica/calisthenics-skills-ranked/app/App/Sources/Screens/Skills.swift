import SwiftUI
import GradingKit

// S06
struct SkillsView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = "all"

    var body: some View {
        List {
            Picker("Region", selection: $filter) {
                Text("Alle").tag("all")
                ForEach(model.catalog.regions) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            ForEach(model.catalog.regions.filter { filter == "all" || $0.id == filter }) { r in
                Section(r.name) {
                    ForEach(model.catalog.lines(in: r.id)) { l in
                        NavigationLink(value: l) { LineRow(line: l) }
                    }
                }
            }
        }
        .navigationTitle("Skills")
        .navigationDestination(for: SkillLine.self) { LineDetailView(line: $0) }
    }
}

// S07
struct LineDetailView: View {
    @Environment(AppModel.self) private var model
    let line: SkillLine
    @State private var logStage: Stage?
    @State private var editing: SetLog?

    var body: some View {
        let current = model.currentIndex(of: line)
        let logged = model.summary.highestLogged[line.id] ?? 0
        let grade = model.summary.lineGrades[line.id] ?? 0
        List {
            Section {
                HStack(spacing: DS.Space.s3) {
                    if grade > 0 { GradeBadge(grade: grade, kind: .line, size: .md) }
                    VStack(alignment: .leading) {
                        Text(GradeNames.line(grade)).font(DS.Typo.headline)
                        Text(model.catalog.region(line.regionID)?.name ?? "").font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textMuted)
                    }
                }
                if current > logged {
                    Text("Stufen bis \(current) stammen aus deiner Einstufung. Logge sie, damit sie ins Power Level zählen.")
                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                }
            }
            Section("Stufen") {
                StageChain(stages: line.stages.map { s in
                    StageItem(id: s.id, index: s.index, name: s.name, criterion: s.criterion,
                              status: s.index <= current ? .cleared : (s.index == current + 1 ? .current : .locked))
                }) { item in logStage = model.catalog.stages[item.id] }
                Menu("Andere Stufe loggen") {
                    ForEach(line.stages) { s in Button("\(s.index). \(s.name)") { logStage = s } }
                }
            }
            Section("Letzte Sätze") {
                let logs = model.logs(for: line.id).prefix(20)
                if logs.isEmpty {
                    Text("Noch keine Sätze in dieser Linie.").foregroundStyle(DS.Palette.textMuted)
                }
                ForEach(Array(logs)) { log in
                    let s = model.catalog.stages[model.catalog.resolve(log.stageID)]
                    HStack {
                        VStack(alignment: .leading) {
                            Text(s?.name ?? log.stageID).font(DS.Typo.body)
                            Text(log.loggedAt, format: .dateTime.day().month().hour().minute())
                                .font(DS.Typo.caption).foregroundStyle(DS.Palette.textMuted)
                        }
                        Spacer()
                        Text(s?.metric == .seconds ? "\(log.value) s" : "\(log.value) Wdh.").font(DS.Typo.headline)
                    }
                    .swipeActions {
                        Button("Löschen", role: .destructive) { model.deleteLog(id: log.id) }
                        Button("Ändern") { editing = log }
                    }
                }
            }
        }
        .navigationTitle(line.name)
        .sheet(item: $logStage) { LogSheet(stage: $0) }
        .sheet(item: $editing) { log in
            if let s = model.catalog.stages[model.catalog.resolve(log.stageID)] { LogSheet(stage: s, editing: log) }
        }
    }
}

// S08
struct LogSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let stage: Stage
    var editing: SetLog?
    @State private var value: Int
    @State private var saving = false
    @State private var timerStart: Date?

    init(stage: Stage, editing: SetLog? = nil) {
        self.stage = stage
        self.editing = editing
        _value = State(initialValue: editing?.value ?? stage.target)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Space.s5) {
                VStack(spacing: DS.Space.s1) {
                    Text(stage.name).font(DS.Typo.title).multilineTextAlignment(.center)
                    Text("Ziel: \(stage.criterion)").font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                }
                NumberStepper(value: $value, metric: stage.metric == .seconds ? .seconds : .reps)
                if stage.metric == .seconds { holdTimer }
                Text(value >= stage.target ? "Erfüllt das Ziel dieser Stufe." : "Unter dem Ziel – zählt trotzdem für Konstanz und Volumen.")
                    .font(DS.Typo.footnote)
                    .foregroundStyle(value >= stage.target ? DS.Palette.success : DS.Palette.textMuted)
                Spacer()
                if !AppModel.valueRange.contains(value) {
                    Text("Bitte einen Wert zwischen 1 und 10 000 eingeben.")
                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.danger)
                }
                PrimaryButton(title: editing == nil ? "Speichern" : "Änderung speichern", isLoading: saving) {
                    guard !saving, AppModel.valueRange.contains(value) else { return }
                    saving = true
                    if let editing { model.editLog(editing, value: value) }
                    else { model.addLog(stageID: stage.id, value: value) }
                    dismiss()
                }
            }
            .padding(DS.Layout.gutter)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    /// HoldTimer (components.md): Start/Stopp übernimmt Sekunden in den Stepper.
    private var holdTimer: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let elapsed = timerStart.map { Int(ctx.date.timeIntervalSince($0)) } ?? 0
            Button {
                if let start = timerStart {
                    value = max(1, Int(Date.now.timeIntervalSince(start)))
                    timerStart = nil
                } else { timerStart = .now }
            } label: {
                Label(timerStart == nil ? "Halte-Timer starten" : "Stopp bei \(elapsed) s",
                      systemImage: timerStart == nil ? "timer" : "stop.fill")
                    .font(DS.Typo.headline)
                    .frame(maxWidth: .infinity, minHeight: DS.Layout.minTap)
            }
            .buttonStyle(.bordered)
        }
    }
}
