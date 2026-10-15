import Foundation

public enum Metric: String, Codable, Sendable { case reps, seconds }

public struct Region: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let sort: Int
}

public struct Stage: Hashable, Sendable, Identifiable {
    public let id: String          // "<line>.<NN>"
    public let lineID: String
    public let index: Int          // 1-basiert
    public let name: String
    public let metric: Metric
    public let target: Int
    public let difficulty: Double
}

public struct SkillLine: Hashable, Sendable, Identifiable {
    public let id: String
    public let regionID: String
    public let name: String
    public let sort: Int
    public let weight: Double
    public let stages: [Stage]
}

public struct Catalog: Sendable {
    public let version: Int
    public let renamed: [String: String]
    public let regions: [Region]
    public let lines: [SkillLine]
    public let stages: [String: Stage]

    public func line(_ id: String) -> SkillLine? { lines.first { $0.id == id } }
    public func lines(in regionID: String) -> [SkillLine] {
        lines.filter { $0.regionID == regionID }.sorted { $0.sort < $1.sort }
    }
    public func region(_ id: String) -> Region? { regions.first { $0.id == id } }

    /// Neue Stage-ID für eine alte (nach Katalog-Update), sonst die ID selbst.
    public func resolve(_ stageID: String) -> String { renamed[stageID] ?? stageID }

    public static func decode(from data: Data) throws -> Catalog {
        let raw = try JSONDecoder().decode(RawCatalog.self, from: data)
        var stageMap: [String: Stage] = [:]
        let lines = raw.lines.map { l -> SkillLine in
            let stages = l.stages.enumerated().map { i, s -> Stage in
                let st = Stage(id: l.id + "." + String(format: "%02d", i + 1), lineID: l.id, index: i + 1,
                               name: s.name, metric: s.metric, target: s.target, difficulty: s.difficulty)
                stageMap[st.id] = st
                return st
            }
            return SkillLine(id: l.id, regionID: l.region, name: l.name, sort: l.sort, weight: l.weight, stages: stages)
        }
        return Catalog(version: raw.version, renamed: raw.renamed ?? [:],
                       regions: raw.regions.sorted { $0.sort < $1.sort }, lines: lines, stages: stageMap)
    }
}

private struct RawCatalog: Decodable {
    struct RawStage: Decodable { let name: String; let metric: Metric; let target: Int; let difficulty: Double }
    struct RawLine: Decodable { let id: String; let region: String; let name: String; let sort: Int; let weight: Double; let stages: [RawStage] }
    let version: Int
    let renamed: [String: String]?
    let regions: [Region]
    let lines: [RawLine]
}
