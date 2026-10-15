import Foundation
import SwiftData
import GradingKit

// SwiftData-Abbild von ../../schema.sql. Katalog liegt nicht in SwiftData (catalog.json, read-only).

@Model final class SetLog {
    @Attribute(.unique) var id: UUID
    var stageID: String
    var value: Int
    var loggedAt: Date
    var localDay: String          // "YYYY-MM-DD" in TimeZone.current beim Loggen
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(stageID: String, value: Int, at: Date = .now, timeZone: TimeZone = .current) {
        id = UUID(); self.stageID = stageID; self.value = value
        loggedAt = at; localDay = Day.string(at, in: timeZone)
        createdAt = at; updatedAt = at
    }
}

@Model final class AssessmentAnswer {
    @Attribute(.unique) var lineID: String
    var claimedIdx: Int
    var answeredAt: Date
    init(lineID: String, claimedIdx: Int) { self.lineID = lineID; self.claimedIdx = claimedIdx; answeredAt = .now }
}

@Model final class RankSnapshot {
    @Attribute(.unique) var key: String     // "<localDay>|<reason>" -> upsert pro Tag und Grund
    var takenAt: Date
    var localDay: String
    var overallGrade: Int
    var powerLevel: Int
    var regionGrades: [String: Int]
    var reason: String                      // assessment | log | daily | recompute

    init(day: String, reason: String, summary: RankSummary) {
        key = "\(day)|\(reason)"; takenAt = .now; localDay = day; self.reason = reason
        overallGrade = summary.overallGrade; powerLevel = summary.power; regionGrades = summary.regionGrades
    }
}

@Model final class Plan {
    @Attribute(.unique) var id: UUID
    var targetRegionID: String
    var createdAt: Date
    var status: String                      // active | done | replaced
    @Relationship(deleteRule: .cascade, inverse: \PlanItem.plan) var items: [PlanItem] = []
    init(targetRegionID: String) { id = UUID(); self.targetRegionID = targetRegionID; createdAt = .now; status = "active" }
}

@Model final class PlanItem {
    var stageID: String
    var sets: Int
    var target: Int
    var sort: Int
    var doneAt: Date?
    var doneManually = false               // per Haken gesetzt; sonst aus Logs abgeleitet (BUG-003)
    var plan: Plan?
    init(stageID: String, sets: Int, target: Int, sort: Int) {
        self.stageID = stageID; self.sets = sets; self.target = target; self.sort = sort
    }
}

