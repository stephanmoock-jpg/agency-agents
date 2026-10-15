import XCTest
import SwiftData
import GradingKit
@testable import GradeApp

/// Logik der Service-Schicht mit In-Memory-Store. Fall-IDs: ../../test-plan.md
@MainActor
final class AppModelTests: XCTestCase {
    var model: AppModel!
    var container: ModelContainer!     // festhalten: ModelContext hält seinen Container nicht

    override func setUp() async throws {
        container = try ModelContainer(
            for: SetLog.self, AssessmentAnswer.self, RankSnapshot.self, Plan.self, PlanItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        model = AppModel(context: container.mainContext, catalog: AppModel.loadCatalog())
    }

    // F02-H1
    func testLogClearsStageAndRaisesPower() {
        let o = model.addLog(stageID: "pushup.04", value: 10)
        XCTAssertEqual(o?.clearedStage?.id, "pushup.04")
        XCTAssertGreaterThan(o?.powerDelta ?? 0, 0)
        XCTAssertEqual(model.summary.highestLogged["pushup"], 4)
    }

    // F02-N1 / BUG-001
    func testRejectsOutOfRangeValues() {
        XCTAssertNil(model.addLog(stageID: "pushup.01", value: 0))
        XCTAssertNil(model.addLog(stageID: "pushup.01", value: -5))
        XCTAssertNil(model.addLog(stageID: "pushup.01", value: 10_001))
        XCTAssertNil(model.addLog(stageID: "gibtsnicht.01", value: 5))
        XCTAssertTrue(model.activeLogs().isEmpty)
        XCTAssertEqual(model.summary.power, 0)
    }

    // F02-E4: Rückgängig stellt Rang wieder her
    func testUndoRestoresRank() throws {
        let before = model.summary
        let o = try XCTUnwrap(model.addLog(stageID: "pullup.03", value: 1))
        model.deleteLog(id: o.logID)
        XCTAssertEqual(model.summary.power, before.power)
        XCTAssertEqual(model.summary.highestLogged, before.highestLogged)
        XCTAssertNil(model.lastOutcome)
        model.undoDelete(id: o.logID)
        XCTAssertEqual(model.summary.highestLogged["pullup"], 3)
    }

    // F04-E4 / BUG-003: Rückgängig setzt erledigten Plan-Punkt zurück
    func testUndoRevertsPlanItem() throws {
        let plan = model.generatePlan()
        let item = try XCTUnwrap(plan.items.sorted { $0.sort < $1.sort }.first)
        let o = try XCTUnwrap(model.addLog(stageID: item.stageID, value: item.target))
        XCTAssertNotNil(item.doneAt)
        model.deleteLog(id: o.logID)
        XCTAssertNil(item.doneAt, "Plan-Punkt bleibt nach Rückgängig erledigt")
        XCTAssertEqual(plan.status, "active")
    }

    // F04-E5: manueller Haken bleibt nach Rückgängig eines anderen Satzes
    func testManualDoneSurvivesUndo() throws {
        let plan = model.generatePlan()
        let item = try XCTUnwrap(plan.items.first)
        model.toggleDone(item)
        let o = try XCTUnwrap(model.addLog(stageID: "squat.01", value: 15))
        model.deleteLog(id: o.logID)
        XCTAssertNotNil(item.doneAt)
    }

    // F04-H2: alle Punkte erledigt -> Plan done, sichtbar als currentPlan
    func testPlanCompletes() throws {
        let plan = model.generatePlan()
        for item in plan.items { model.addLog(stageID: item.stageID, value: item.target) }
        XCTAssertEqual(plan.status, "done")
        XCTAssertNil(model.activePlan())
        XCTAssertEqual(model.currentPlan()?.id, plan.id)
    }

    // F01-N1
    func testAssessmentGivesGradeButNoPower() {
        model.submitAssessment(["pushup": 6, "pullup": 5, "squat": 5])
        XCTAssertGreaterThan(model.summary.overallScore, 0)
        XCTAssertEqual(model.summary.power, 0)
    }

    // X-D1: ein Snapshot pro Tag und Grund
    func testSnapshotUpsert() {
        model.addLog(stageID: "squat.01", value: 15)
        model.addLog(stageID: "squat.02", value: 30)
        let logSnaps = model.history().filter { $0.reason == "log" }
        XCTAssertEqual(logSnaps.count, 1)
        XCTAssertEqual(logSnaps.first?.powerLevel, model.summary.power)
    }

    // F05-N2 / S13: alles löschen
    func testWipeAll() {
        model.submitAssessment(["pushup": 3])
        model.addLog(stageID: "squat.01", value: 15)
        model.generatePlan()
        model.wipeAll()
        XCTAssertTrue(model.activeLogs().isEmpty)
        XCTAssertTrue(model.history().isEmpty)
        XCTAssertNil(model.currentPlan())
        XCTAssertFalse(model.hasOnboarded)
        XCTAssertEqual(model.summary.overallScore, 0)
    }

    // S13: Export enthält Zeilen ohne Trennzeichen-Bruch
    func testExportCSV() throws {
        model.addLog(stageID: "squat.01", value: 15)
        let text = try String(contentsOf: model.exportCSV(), encoding: .utf8)
        let rows = text.split(separator: "\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].split(separator: ";").count, 6)
    }
}
