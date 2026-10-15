import Foundation

/// Parameter des Grading-Modells. Muss identisch zu tools/grading_ref.py bleiben.
public struct GradingConfig: Sendable {
    public var lineGradeThresholds: [Double] = [0.15, 0.40, 0.65, 0.85]
    public var overallGradeThresholds: [Double] = [0.05, 0.12, 0.20, 0.30, 0.42, 0.55, 0.70, 0.85]
    public var topK = 3
    public var topKFactor = 2.0
    public var balanceBase = 0.7
    public var balanceWeight = 0.3
    public var consistencyDays = 14
    public var volumeDays = 30
    public var volumeCapPerSet = 3.0
    public var wScore = 1000.0, wStages = 15.0, wConsistency = 300.0, wVolume = 120.0
    public init() {}
}

/// Ein geloggter Satz. `day` = lokaler Kalendertag beim Loggen ("YYYY-MM-DD").
public struct LogEntry: Sendable {
    public let stageID: String
    public let value: Int
    public let at: Date
    public let day: String
    public init(stageID: String, value: Int, at: Date, day: String) {
        self.stageID = stageID; self.value = value; self.at = at; self.day = day
    }
}

public struct RankSummary: Sendable, Equatable {
    public let overallGrade: Int
    public let overallScore: Double
    public let power: Int
    public let regionGrades: [String: Int]
    public let regionScores: [String: Double]
    public let weakest: String
    public let lineGrades: [String: Int]
    public let highestLogged: [String: Int]
    public let clearedStages: Int

    /// 0...1 Fortschritt bis zur nächsten Gesamtgrad-Schwelle (für PowerMeter).
    public func progressToNextGrade(_ cfg: GradingConfig = .init()) -> Double {
        let t = [0.0] + cfg.overallGradeThresholds
        guard overallGrade < t.count else { return 1 }
        let lo = t[overallGrade - 1], hi = t[overallGrade]
        return max(0, min(1, (overallScore - lo) / (hi - lo)))
    }
}

public enum Grading {
    public static func evaluate(catalog c: Catalog, logs: [LogEntry], claims: [String: Int],
                                now: Date, today: String, config cfg: GradingConfig = .init()) -> RankSummary {
        var loggedIdx = Dictionary(uniqueKeysWithValues: c.lines.map { ($0.id, 0) })
        for g in logs {
            guard let s = c.stages[c.resolve(g.stageID)] else { continue }
            if g.value >= s.target { loggedIdx[s.lineID] = max(loggedIdx[s.lineID] ?? 0, s.index) }
        }

        func lineScores(useClaims: Bool) -> [String: Double] {
            var out: [String: Double] = [:]
            for l in c.lines {
                var idx = loggedIdx[l.id] ?? 0
                if useClaims { idx = max(idx, min(claims[l.id] ?? 0, l.stages.count)) }
                out[l.id] = idx > 0 ? l.stages[idx - 1].difficulty : 0
            }
            return out
        }
        func regionScores(_ ls: [String: Double]) -> [String: Double] {
            var out: [String: Double] = [:]
            for r in c.regions {
                let rl = c.lines.filter { $0.regionID == r.id }
                    .sorted { (ls[$0.id]!, -$0.sort) > (ls[$1.id]!, -$1.sort) }
                var num = 0.0, den = 0.0
                for (rank, l) in rl.enumerated() {
                    let w = l.weight * (rank < cfg.topK ? cfg.topKFactor : 1)
                    num += w * ls[l.id]!; den += w
                }
                out[r.id] = den > 0 ? num / den : 0
            }
            return out
        }
        func overall(_ rs: [String: Double]) -> Double {
            let vals = c.regions.map { rs[$0.id]! }
            let mean = vals.reduce(0, +) / Double(vals.count)
            let balance = mean > 0 ? vals.min()! / mean : 1
            return mean * (cfg.balanceBase + cfg.balanceWeight * balance)
        }

        let lsClaim = lineScores(useClaims: true)
        let rsClaim = regionScores(lsClaim)
        let ovClaim = overall(rsClaim)
        let ovLogs = overall(regionScores(lineScores(useClaims: false)))

        let window = Set((0..<cfg.consistencyDays).map { Day.minus(today, $0) })
        let activeDays = Set(logs.map(\.day).filter(window.contains))
        let consistency = Double(activeDays.count) / Double(cfg.consistencyDays)
        let volFrom = now.addingTimeInterval(-Double(cfg.volumeDays) * 86_400)
        var volume = 0.0
        for g in logs where g.at >= volFrom {
            guard let s = c.stages[c.resolve(g.stageID)] else { continue }
            volume += min(Double(g.value) / Double(s.target), cfg.volumeCapPerSet)
        }
        let cleared = loggedIdx.values.reduce(0, +)
        let rawPower = cfg.wScore * ovLogs + cfg.wStages * Double(cleared)
            + cfg.wConsistency * consistency + cfg.wVolume * log1p(volume)
        let power = Int(rawPower.rounded(.toNearestOrEven))

        var recent = Dictionary(uniqueKeysWithValues: c.regions.map { ($0.id, 0) })
        for g in logs where window.contains(g.day) {
            if let s = c.stages[c.resolve(g.stageID)], let l = c.line(s.lineID) { recent[l.regionID, default: 0] += 1 }
        }
        let key: (Region) -> (Double, Int, Int) = { r in
            ((rsClaim[r.id]! * 1e9).rounded(.toNearestOrEven), recent[r.id]!, r.sort)
        }
        let weakest = c.regions.min { key($0) < key($1) }!.id

        func grade(_ s: Double, _ t: [Double], base: Int) -> Int { base + t.filter { s >= $0 - 1e-12 }.count }
        return RankSummary(
            overallGrade: max(1, grade(ovClaim, cfg.overallGradeThresholds, base: 1)),
            overallScore: ovClaim,
            power: power,
            regionGrades: rsClaim.mapValues { grade($0, cfg.overallGradeThresholds, base: 1) },
            regionScores: rsClaim,
            weakest: weakest,
            lineGrades: lsClaim.mapValues { grade($0, cfg.lineGradeThresholds, base: 0) },
            highestLogged: loggedIdx,
            clearedStages: cleared)
    }
}

/// Kalendertage als "YYYY-MM-DD", unabhängig von Zeitzonen gerechnet.
public enum Day {
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()
    private static func formatter(_ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz; f.dateFormat = "yyyy-MM-dd"
        return f
    }
    /// Lokaler Tag eines Zeitpunkts in der gegebenen Zeitzone (beim Loggen: TimeZone.current).
    public static func string(_ date: Date, in tz: TimeZone = .current) -> String { formatter(tz).string(from: date) }
    public static func minus(_ day: String, _ n: Int) -> String {
        let f = formatter(TimeZone(identifier: "UTC")!)
        guard let d = f.date(from: day), let r = cal.date(byAdding: .day, value: -n, to: d) else { return day }
        return f.string(from: r)
    }
}
