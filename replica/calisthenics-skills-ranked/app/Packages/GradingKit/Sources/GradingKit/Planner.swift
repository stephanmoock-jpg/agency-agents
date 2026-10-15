import Foundation

public struct PlanDraft: Sendable, Equatable {
    public struct Item: Sendable, Equatable { public let stageID: String; public let sets: Int; public let target: Int }
    public let regionID: String
    public let items: [Item]
}

public enum Planner {
    /// Nächste nicht geschaffte Stufe der schwächsten Linien der schwächsten Region.
    /// Ist dort alles geschafft, die nächstschwächere Region. Spiegelt tools/grading_ref.py `plan`.
    public static func draft(catalog c: Catalog, summary s: RankSummary, maxLines: Int = 3, sets: Int = 3) -> PlanDraft {
        let order = c.regions.sorted {
            ($0.id != s.weakest ? 1 : 0, s.regionScores[$0.id] ?? 0, $0.sort)
                < ($1.id != s.weakest ? 1 : 0, s.regionScores[$1.id] ?? 0, $1.sort)
        }
        for r in order {
            var cand: [(Double, Int, Stage)] = []
            for l in c.lines(in: r.id) {
                let next = (s.highestLogged[l.id] ?? 0) + 1
                if next <= l.stages.count { let st = l.stages[next - 1]; cand.append((st.difficulty, l.sort, st)) }
            }
            if !cand.isEmpty {
                cand.sort { ($0.0, $0.1, $0.2.id) < ($1.0, $1.1, $1.2.id) }
                return PlanDraft(regionID: r.id, items: cand.prefix(maxLines).map {
                    .init(stageID: $0.2.id, sets: sets, target: $0.2.target)
                })
            }
        }
        return PlanDraft(regionID: s.weakest, items: [])
    }
}
