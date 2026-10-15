import SwiftUI
import GradingKit

extension Stage {
    var criterion: String { metric == .seconds ? "\(target) s halten" : "\(target) Wdh." }
}

/// Eigene Gradnamen (brand.md). Bewusst kein Berg-/Himmel-Thema.
enum GradeNames {
    static let names = ["Anwärter", "Lehrling", "Geselle", "Altgeselle", "Meister",
                        "Obermeister", "Großmeister", "Ehrenmeister", "Legende"]
    static func overall(_ g: Int) -> String { names[max(1, min(9, g)) - 1] }
    static func line(_ g: Int) -> String { g == 0 ? "Noch kein Liniengrad" : "Liniengrad \(["I", "II", "III", "IV"][min(3, g - 1)])" }
}

struct LineRow: View {
    @Environment(AppModel.self) private var model
    let line: SkillLine
    var compact = false

    var body: some View {
        let idx = model.currentIndex(of: line)
        let grade = model.summary.lineGrades[line.id] ?? 0
        HStack(spacing: DS.Space.s3) {
            if grade > 0 { GradeBadge(grade: grade, kind: .line, size: .sm) }
            else { Circle().strokeBorder(DS.Palette.borderInput, lineWidth: 1).frame(width: 28, height: 28) }
            VStack(alignment: .leading, spacing: DS.Space.s1) {
                Text(line.name).font(DS.Typo.headline).foregroundStyle(DS.Palette.text)
                if !compact {
                    Text(idx < line.stages.count ? "Nächste: \(line.stages[idx].name)" : "Alle Stufen geschafft")
                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted).lineLimit(2)
                }
                ProgressView(value: Double(idx), total: Double(line.stages.count)).tint(DS.Palette.accent)
            }
            Text("\(idx)/\(line.stages.count)").font(DS.Typo.footnote.monospacedDigit()).foregroundStyle(DS.Palette.textMuted)
        }
        .padding(.vertical, DS.Space.s2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.name), Stufe \(idx) von \(line.stages.count), \(GradeNames.line(grade))")
        .accessibilityAddTraits(.isButton)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let text: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: DS.Space.s3) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(DS.Palette.textMuted)
                .accessibilityHidden(true)
            Text(title).font(DS.Typo.headline).foregroundStyle(DS.Palette.text).multilineTextAlignment(.center)
            Text(text).font(DS.Typo.body).foregroundStyle(DS.Palette.textMuted).multilineTextAlignment(.center)
            if let actionTitle { PrimaryButton(title: actionTitle, action: action).padding(.top, DS.Space.s2) }
        }
        .padding(DS.Space.s6)
        .frame(maxWidth: .infinity)
    }
}

/// S09: Power-Delta + Rückgängig. Bleibt bei VoiceOver stehen, bis es geschlossen wird.
struct LogToast: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        if let o = model.lastOutcome {
            HStack(spacing: DS.Space.s3) {
                Image(systemName: "bolt.fill").foregroundStyle(DS.Palette.power).accessibilityHidden(true)
                Text(o.powerDelta >= 0 ? "Power +\(o.powerDelta)" : "Power \(o.powerDelta)")
                    .font(DS.Typo.headline).foregroundStyle(DS.Palette.text)
                Button("Rückgängig") { model.deleteLog(id: o.logID) }
                    .font(DS.Typo.footnote.weight(.semibold))
                Button { model.clearOutcome() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Schließen")
                    .foregroundStyle(DS.Palette.textMuted)
            }
            .padding(.horizontal, DS.Space.s4).padding(.vertical, DS.Space.s3)
            .background(Capsule().fill(DS.Palette.surfaceRaised).shadow(color: .black.opacity(0.08), radius: 3, y: 1))
            .overlay(Capsule().strokeBorder(DS.Palette.border))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: o.id) {
                AccessibilityNotification.Announcement("Satz gespeichert, Power \(o.powerDelta >= 0 ? "plus" : "minus") \(abs(o.powerDelta))").post()
                guard !voiceOver else { return }
                try? await Task.sleep(for: .seconds(4))
                if model.lastOutcome?.id == o.id { model.clearOutcome() }
            }
        }
    }
}

struct LevelUpSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let outcome: AppModel.LogOutcome

    var body: some View {
        VStack(spacing: DS.Space.s5) {
            if let g = outcome.overallGradeUp {
                GradeBadge(grade: g, size: .lg)
                Text("Du bist jetzt \(GradeNames.overall(g)).").font(DS.Typo.title).multilineTextAlignment(.center)
            } else if let up = outcome.regionGradeUp {
                let g = up.1
                let name = model.catalog.region(up.0)?.name ?? up.0
                GradeBadge(grade: g, kind: .region(name), size: .lg)
                Text("\(name): jetzt Grad \(g).").font(DS.Typo.title).multilineTextAlignment(.center)
            }
            if let s = outcome.clearedStage {
                Label("Abgehakt: \(s.name)", systemImage: "checkmark.circle.fill")
                    .font(DS.Typo.headline).foregroundStyle(DS.Palette.success)
            }
            Text("Power \(outcome.powerDelta >= 0 ? "+" : "")\(outcome.powerDelta)")
                .font(DS.Typo.power).foregroundStyle(DS.Palette.text)
            PrimaryButton(title: "Weiter trainieren") { dismiss() }
        }
        .padding(DS.Layout.gutter)
        .presentationDetents([.medium])
        .sensoryFeedback(outcome.overallGradeUp != nil ? .impact(flexibility: .rigid) : .success, trigger: outcome.id)
    }
}

/// Zeigt `content` für PRO, sonst einen Hinweis mit Paywall.
struct ProGate<Content: View>: View {
    @Environment(StoreService.self) private var store
    @State private var showPaywall = false
    let title: String
    let text: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        if store.isPro { content() } else {
            EmptyStateView(symbol: "lock", title: title, text: text, actionTitle: "PRO ansehen") { showPaywall = true }
                .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
