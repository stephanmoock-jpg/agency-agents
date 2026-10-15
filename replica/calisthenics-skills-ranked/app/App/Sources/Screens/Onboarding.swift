import SwiftUI
import StoreKit
import GradingKit

/// S01 -> S02 -> S03 -> (S04) -> Tabs
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    enum Step { case intro, assessment, result }
    @State private var step: Step = .intro

    var body: some View {
        switch step {
        case .intro: IntroView { step = .assessment }
        case .assessment: AssessmentView { answers in model.submitAssessment(answers); step = .result }
        case .result: ResultView { model.finishOnboarding() }
        }
    }
}

// S01
struct IntroView: View {
    let onStart: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s5) {
            Spacer()
            HStack(spacing: DS.Space.s2) { ForEach([2, 4, 6, 8], id: \.self) { GradeBadge(grade: $0, size: .sm) } }
                .accessibilityHidden(true)
            Text("Miss, was du kannst.").font(DS.Typo.large).foregroundStyle(DS.Palette.text)
            Text("Nicht wie viele Wiederholungen, sondern welche Stufe. Jeder Satz verschiebt deinen Grad – und zeigt, welche Körperregion dich bremst.")
                .font(DS.Typo.body).foregroundStyle(DS.Palette.textMuted)
            Label("Alles bleibt auf deinem iPhone. Kein Konto.", systemImage: "lock.iphone")
                .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
            Spacer()
            PrimaryButton(title: "Einstufung starten", action: onStart)
            Text("Dauert etwa zwei Minuten.").font(DS.Typo.caption).foregroundStyle(DS.Palette.textMuted)
                .frame(maxWidth: .infinity)
        }
        .padding(DS.Layout.gutter)
        .background(DS.Palette.bg)
    }
}

// S02: eine Frage pro Linie, gruppiert nach Region.
struct AssessmentView: View {
    @Environment(AppModel.self) private var model
    let onDone: ([String: Int]) -> Void
    @State private var index = 0
    @State private var answers: [String: Int] = [:]

    /// Zwei Kernlinien je Region (12 Fragen). Weitere Linien stuft man in S07 über echte Sätze ein.
    private var lines: [SkillLine] {
        model.catalog.regions.flatMap { model.catalog.lines(in: $0.id).prefix(2) }
    }

    var body: some View {
        let line = lines[index]
        let region = model.catalog.region(line.regionID)?.name ?? ""
        VStack(alignment: .leading, spacing: DS.Space.s4) {
            ProgressView(value: Double(index + 1), total: Double(lines.count)).tint(DS.Palette.accent)
                .accessibilityLabel("Frage \(index + 1) von \(lines.count)")
            Text(region.uppercased()).font(DS.Typo.caption).foregroundStyle(DS.Palette.textMuted)
            Text("\(line.name): Was schaffst du heute sauber?").font(DS.Typo.title).foregroundStyle(DS.Palette.text)
            ScrollView {
                VStack(spacing: DS.Space.s2) {
                    option(title: "Nichts davon / weiß nicht", detail: nil, idx: 0)
                    ForEach(line.stages) { s in option(title: s.name, detail: s.criterion, idx: s.index) }
                }
            }
            HStack {
                if index > 0 { Button("Zurück") { index -= 1 }.foregroundStyle(DS.Palette.textMuted) }
                Spacer()
                Text("Ehrlich bleiben: Der Grad steigt später durch echte Sätze.")
                    .font(DS.Typo.caption).foregroundStyle(DS.Palette.textMuted)
            }
        }
        .padding(DS.Layout.gutter)
        .background(DS.Palette.bg)
    }

    private func option(title: String, detail: String?, idx: Int) -> some View {
        let selected = answers[lines[index].id] == idx
        return Button {
            answers[lines[index].id] = idx
            if index + 1 < lines.count { index += 1 } else { onDone(answers) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.Typo.body).foregroundStyle(DS.Palette.text)
                    if let detail { Text(detail).font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(DS.Palette.accent) }
            }
            .padding(DS.Space.s3)
            .frame(minHeight: DS.Layout.minTap)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(selected ? DS.Palette.accent : DS.Palette.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// S03
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreService.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var showPaywall = false
    let onContinue: () -> Void

    var body: some View {
        let s = model.summary
        let weakest = model.catalog.region(s.weakest)?.name ?? s.weakest
        ScrollView {
            VStack(spacing: DS.Space.s5) {
                Text("Deine Einstufung").font(DS.Typo.headline).foregroundStyle(DS.Palette.textMuted)
                GradeBadge(grade: s.overallGrade, size: .lg)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.6)
                    .opacity(revealed ? 1 : 0)
                Text("\(GradeNames.overall(s.overallGrade)) von 9").font(DS.Typo.title)
                VStack(alignment: .leading, spacing: DS.Space.s2) {
                    Text("Was dich bremst: \(weakest)").font(DS.Typo.headline)
                    Text("Dein Gesamtgrad richtet sich auch nach deiner schwächsten Region. Wer dort aufholt, steigt am schnellsten.")
                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RegionBars(regions: regionScores(), weakestID: s.weakest)
                VStack(alignment: .leading, spacing: DS.Space.s1) {
                    PowerMeter(value: s.power, progress: s.progressToNextGrade())
                    Text("Power startet bei 0 und wächst nur mit Sätzen, die du wirklich loggst.")
                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                }
                PrimaryButton(title: "Weiter") { if store.isPro || Self.skipPaywall { onContinue() } else { showPaywall = true } }
            }
            .padding(DS.Layout.gutter)
        }
        .background(DS.Palette.bg)
        .onAppear { withAnimation(DS.Motion.reveal(reduced: reduceMotion)) { revealed = true } }
        .sheet(isPresented: $showPaywall, onDismiss: onContinue) { PaywallView() }
    }

    #if DEBUG
    static let skipPaywall = ProcessInfo.processInfo.arguments.contains("-skipPaywall")
    #else
    static let skipPaywall = false
    #endif

    private func regionScores() -> [RegionScore] {
        model.catalog.regions.map {
            RegionScore(id: $0.id, name: $0.name, grade: model.summary.regionGrades[$0.id] ?? 1,
                        score: model.summary.regionScores[$0.id] ?? 0)
        }
    }
}

// S04
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store

    var body: some View {
        SubscriptionStoreView(groupID: StoreService.groupID) {
            VStack(spacing: DS.Space.s3) {
                Image(systemName: "rosette").font(.system(size: 44)).foregroundStyle(DS.Palette.accent)
                    .accessibilityHidden(true)
                Text("PRO").font(DS.Typo.large)
                VStack(alignment: .leading, spacing: DS.Space.s2) {
                    Label("Grad für jede der sechs Regionen", systemImage: "chart.bar")
                    Label("Plan, der gezielt deine schwächste Region trainiert", systemImage: "checklist")
                    Label("Verlauf von Grad und Power", systemImage: "chart.xyaxis.line")
                }
                .font(DS.Typo.body)
            }
            .padding(DS.Layout.gutter)
        }
        .storeButton(.visible, for: .restorePurchases, .policies, .cancellation)
        .subscriptionStorePolicyDestination(url: URL(string: "https://example.com/agb")!, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: URL(string: "https://example.com/datenschutz")!, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, _ in await store.refresh(); if store.isPro { dismiss() } }
    }
}
