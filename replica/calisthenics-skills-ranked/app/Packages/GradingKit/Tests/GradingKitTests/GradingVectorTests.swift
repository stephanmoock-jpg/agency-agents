import XCTest
@testable import GradingKit

/// Vergleicht GradingKit mit der Python-Referenz (tools/grading_ref.py) über vectors.json.
final class GradingVectorTests: XCTestCase {
    struct Vector: Decodable {
        struct Log: Decodable { let stage: String; let value: Int; let ts: Double; let day: String }
        struct Expected: Decodable {
            let overall_grade: Int; let overall_score: Double; let power: Int
            let region_grades: [String: Int]; let region_scores: [String: Double]
            let weakest: String; let line_grades: [String: Int]; let highest_logged: [String: Int]
            let cleared_stages: Int
        }
        struct ExpectedPlan: Decodable {
            struct Item: Decodable { let stage: String; let sets: Int; let target: Int }
            let region: String; let items: [Item]
        }
        let name: String; let logs: [Log]; let claims: [String: Int]
        let now_ts: Double; let now_day: String
        let expected: Expected; let expected_plan: ExpectedPlan
    }

    func load<T: Decodable>(_ name: String, as: T.Type) throws -> (T, Data) {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        let data = try Data(contentsOf: url)
        return (try JSONDecoder().decode(T.self, from: data), data)
    }

    func testVectorsMatchReference() throws {
        let catalogURL = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json"))
        let catalog = try Catalog.decode(from: Data(contentsOf: catalogURL))
        let (vectors, _) = try load("vectors", as: [Vector].self)
        XCTAssertFalse(vectors.isEmpty)
        for v in vectors {
            let logs = v.logs.map { LogEntry(stageID: $0.stage, value: $0.value, at: Date(timeIntervalSince1970: $0.ts), day: $0.day) }
            let r = Grading.evaluate(catalog: catalog, logs: logs, claims: v.claims,
                                     now: Date(timeIntervalSince1970: v.now_ts), today: v.now_day)
            let e = v.expected
            XCTAssertEqual(r.overallGrade, e.overall_grade, v.name)
            XCTAssertEqual(r.overallScore, e.overall_score, accuracy: 1e-6, v.name)
            XCTAssertEqual(r.power, e.power, v.name)
            XCTAssertEqual(r.regionGrades, e.region_grades, v.name)
            for (k, want) in e.region_scores { XCTAssertEqual(r.regionScores[k]!, want, accuracy: 1e-6, "\(v.name) \(k)") }
            XCTAssertEqual(r.weakest, e.weakest, v.name)
            XCTAssertEqual(r.lineGrades, e.line_grades, v.name)
            XCTAssertEqual(r.highestLogged, e.highest_logged, v.name)
            XCTAssertEqual(r.clearedStages, e.cleared_stages, v.name)

            let p = Planner.draft(catalog: catalog, summary: r)
            XCTAssertEqual(p.regionID, v.expected_plan.region, v.name)
            XCTAssertEqual(p.items.map(\.stageID), v.expected_plan.items.map(\.stage), v.name)
        }
    }

    func testRenamedStageResolves() throws {
        let json = """
        {"version":2,"renamed":{"a.99":"a.01"},
         "regions":[{"id":"r","name":"R","sort":1}],
         "lines":[{"id":"a","region":"r","name":"A","sort":1,"weight":1,
                   "stages":[{"name":"S","metric":"reps","target":5,"difficulty":0.5}]}]}
        """
        let c = try Catalog.decode(from: Data(json.utf8))
        let r = Grading.evaluate(catalog: c, logs: [LogEntry(stageID: "a.99", value: 5, at: .now, day: "2026-10-15")],
                                 claims: [:], now: .now, today: "2026-10-15")
        XCTAssertEqual(r.highestLogged["a"], 1)
    }

    func testNonPositiveValuesIgnored() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json"))
        let c = try Catalog.decode(from: Data(contentsOf: url))
        let logs = [LogEntry(stageID: "pushup.01", value: 0, at: .now, day: "2026-10-15"),
                    LogEntry(stageID: "pushup.01", value: -5, at: .now, day: "2026-10-15")]
        XCTAssertEqual(Grading.evaluate(catalog: c, logs: logs, claims: [:], now: .now, today: "2026-10-15").power, 0)
    }

    func testDayMath() {
        XCTAssertEqual(Day.minus("2026-03-01", 1), "2026-02-28")
        XCTAssertEqual(Day.minus("2024-03-01", 1), "2024-02-29")
        XCTAssertEqual(Day.minus("2026-10-15", 13), "2026-10-02")
    }
}
