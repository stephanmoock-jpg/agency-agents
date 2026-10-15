import Foundation
import Observation
import SwiftData
import GradingKit

/// Service-Schicht aus architecture.md (Catalog/Assessment/Log/Rank/Plan/Data) in einer Klasse.
/// Abweichung: @MainActor statt @ModelActor — Datenmengen sind klein, Serialisierung über den Main Actor
/// verhindert Races genauso; Neuberechnung ist immer vollständig (12–38 Linien, < 1 ms).
@MainActor @Observable
final class AppModel {
    let catalog: Catalog
    private let context: ModelContext
    private(set) var summary: RankSummary
    private(set) var lastOutcome: LogOutcome?
    var hasOnboarded: Bool

    struct LogOutcome: Identifiable, Equatable {
        let id = UUID()
        let logID: UUID
        let powerDelta: Int
        let clearedStage: Stage?
        let overallGradeUp: Int?           // neuer Gesamtgrad, falls gestiegen
        let regionGradeUp: (String, Int)?
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    }

    init(context: ModelContext, catalog: Catalog) {
        self.context = context
        self.catalog = catalog
        self.summary = Grading.evaluate(catalog: catalog, logs: [], claims: [:], now: .now, today: Day.string(.now))
        self.hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        recompute()
        ensureDailySnapshot()
    }

    static func loadCatalog() -> Catalog {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? Catalog.decode(from: data) else { fatalError("catalog.json fehlt oder ist ungültig") }
        return c
    }

    // MARK: Lesen

    var today: String { Day.string(.now) }

    func activeLogs() -> [SetLog] {
        let all = (try? context.fetch(FetchDescriptor<SetLog>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]))) ?? []
        return all.filter { $0.deletedAt == nil }
    }
    func logs(for lineID: String) -> [SetLog] {
        activeLogs().filter { catalog.stages[catalog.resolve($0.stageID)]?.lineID == lineID }
    }
    func claims() -> [String: Int] {
        let a = (try? context.fetch(FetchDescriptor<AssessmentAnswer>())) ?? []
        return Dictionary(a.map { ($0.lineID, $0.claimedIdx) }, uniquingKeysWith: max)
    }
    func history() -> [RankSnapshot] {
        (try? context.fetch(FetchDescriptor<RankSnapshot>(sortBy: [SortDescriptor(\.takenAt)]))) ?? []
    }
    func activePlan() -> Plan? {
        ((try? context.fetch(FetchDescriptor<Plan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? [])
            .first { $0.status == "active" }
    }

    /// Stufenstatus einer Linie: höchste geschaffte (Logs) bzw. eingestufte Stufe.
    func currentIndex(of line: SkillLine) -> Int {
        let logged = summary.highestLogged[line.id] ?? 0
        let claimed = min(claims()[line.id] ?? 0, line.stages.count)
        return max(logged, claimed)
    }

    // MARK: Einstufung (F01)

    func submitAssessment(_ answers: [String: Int]) {
        for (lineID, idx) in answers {
            let existing = (try? context.fetch(FetchDescriptor<AssessmentAnswer>()))?.first { $0.lineID == lineID }
            if let e = existing { e.claimedIdx = idx; e.answeredAt = .now }
            else { context.insert(AssessmentAnswer(lineID: lineID, claimedIdx: idx)) }
        }
        recompute()
        snapshot(reason: "assessment")
        save()
    }

    func finishOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
    }

    // MARK: Loggen (F02, F03)

    @discardableResult
    func addLog(stageID: String, value: Int) -> LogOutcome {
        let before = summary
        let log = SetLog(stageID: stageID, value: value)
        context.insert(log)
        recompute()
        markPlanItems(for: log)
        snapshot(reason: "log")
        save()
        let outcome = makeOutcome(before: before, after: summary, logID: log.id, stageID: stageID, value: value)
        lastOutcome = outcome
        return outcome
    }

    func editLog(_ log: SetLog, value: Int) {
        log.value = value; log.updatedAt = .now
        recompute(); snapshot(reason: "log"); save()
    }

    func deleteLog(id: UUID) {
        guard let log = activeLogs().first(where: { $0.id == id }) else { return }
        log.deletedAt = .now; log.updatedAt = .now
        recompute(); snapshot(reason: "log"); save()
        if lastOutcome?.logID == id { lastOutcome = nil }
    }

    func undoDelete(id: UUID) {
        let all = (try? context.fetch(FetchDescriptor<SetLog>())) ?? []
        guard let log = all.first(where: { $0.id == id }) else { return }
        log.deletedAt = nil; log.updatedAt = .now
        recompute(); snapshot(reason: "log"); save()
    }

    func clearOutcome() { lastOutcome = nil }

    private func makeOutcome(before: RankSummary, after: RankSummary, logID: UUID, stageID: String, value: Int) -> LogOutcome {
        var cleared: Stage?
        if let s = catalog.stages[stageID], value >= s.target,
           (before.highestLogged[s.lineID] ?? 0) < s.index { cleared = s }
        let up = after.overallGrade > before.overallGrade ? after.overallGrade : nil
        var regionUp: (String, Int)?
        for r in catalog.regions where (after.regionGrades[r.id] ?? 0) > (before.regionGrades[r.id] ?? 0) {
            regionUp = (r.id, after.regionGrades[r.id] ?? 0); break
        }
        return LogOutcome(logID: logID, powerDelta: after.power - before.power, clearedStage: cleared,
                          overallGradeUp: up, regionGradeUp: regionUp)
    }

    // MARK: Plan (F04)

    @discardableResult
    func generatePlan() -> Plan {
        activePlan()?.status = "replaced"
        let draft = Planner.draft(catalog: catalog, summary: summary)
        let plan = Plan(targetRegionID: draft.regionID)
        context.insert(plan)
        for (i, item) in draft.items.enumerated() {
            let pi = PlanItem(stageID: item.stageID, sets: item.sets, target: item.target, sort: i)
            pi.plan = plan
            context.insert(pi)
        }
        save()
        return plan
    }

    func toggleDone(_ item: PlanItem) {
        item.doneAt = item.doneAt == nil ? .now : nil
        closePlanIfDone()
        save()
    }

    private func markPlanItems(for log: SetLog) {
        guard let plan = activePlan() else { return }
        for item in plan.items where item.doneAt == nil && item.stageID == log.stageID && log.value >= item.target {
            item.doneAt = .now
        }
        closePlanIfDone()
    }

    private func closePlanIfDone() {
        if let plan = activePlan(), !plan.items.isEmpty, plan.items.allSatisfy({ $0.doneAt != nil }) { plan.status = "done" }
    }

    // MARK: Rang

    func recompute() {
        let logs = activeLogs().map { LogEntry(stageID: $0.stageID, value: $0.value, at: $0.loggedAt, day: $0.localDay) }
        summary = Grading.evaluate(catalog: catalog, logs: logs, claims: claims(), now: .now, today: today)
    }

    private func snapshot(reason: String) {
        let key = "\(today)|\(reason)"
        let existing = ((try? context.fetch(FetchDescriptor<RankSnapshot>())) ?? []).first { $0.key == key }
        if let s = existing {
            s.takenAt = .now; s.overallGrade = summary.overallGrade
            s.powerLevel = summary.power; s.regionGrades = summary.regionGrades
        } else {
            context.insert(RankSnapshot(day: today, reason: reason, summary: summary))
        }
    }

    /// Beim ersten Start eines Tages: Power sinkt über Konstanz/Volumen auch ohne Logs -> im Verlauf sichtbar.
    func ensureDailySnapshot() {
        guard hasOnboarded else { return }
        let key = "\(today)|daily"
        if !((try? context.fetch(FetchDescriptor<RankSnapshot>())) ?? []).contains(where: { $0.key == key }) {
            recompute(); snapshot(reason: "daily"); save()
        }
    }

    // MARK: Daten (S13)

    func exportCSV() throws -> URL {
        var rows = ["datum;tag;linie;stufe;wert;einheit"]
        let iso = ISO8601DateFormatter()
        for l in activeLogs().reversed() {
            let s = catalog.stages[catalog.resolve(l.stageID)]
            let line = s.flatMap { catalog.line($0.lineID) }
            let cells = [iso.string(from: l.loggedAt), l.localDay, line?.name ?? "?", s?.name ?? l.stageID,
                         String(l.value), s?.metric == .seconds ? "s" : "wdh"]
            rows.append(cells.map { $0.replacingOccurrences(of: ";", with: ",") }.joined(separator: ";"))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("training-export.csv")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Einstufung neu: nur Selbstangaben löschen, Logs bleiben.
    func wipeAssessmentOnly() {
        try? context.delete(model: AssessmentAnswer.self)
        save()
        hasOnboarded = false
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
        recompute()
    }

    func wipeAll() {
        try? context.delete(model: SetLog.self)
        try? context.delete(model: AssessmentAnswer.self)
        try? context.delete(model: RankSnapshot.self)
        try? context.delete(model: PlanItem.self)
        try? context.delete(model: Plan.self)
        save()
        hasOnboarded = false
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
        lastOutcome = nil
        recompute()
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("SwiftData save: \(error)") }
    }
}
