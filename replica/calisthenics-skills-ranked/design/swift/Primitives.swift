// Primitives des Design-Systems. Spec: ../components.md. Tokens: DesignTokens.swift (generiert).
// Ungetestet: in dieser Umgebung gibt es keinen Swift-Compiler. Vor Nutzung in Xcode bauen.
import SwiftUI

// MARK: - GradeBadge

struct GradeBadge: View {
    enum Kind { case overall, region(String), line }
    enum Size { case sm, md, lg
        var side: CGFloat { switch self { case .sm: 28; case .md: 44; case .lg: 96 } }
    }
    let grade: Int              // overall/region: 1...9, line: 1...4
    var kind: Kind = .overall
    var size: Size = .md
    var locked = false

    private var fillGrade: Int {
        if case .line = kind { return [2, 4, 6, 8][max(0, min(3, grade - 1))] }
        return max(1, min(9, grade))
    }
    private var label: String {
        if case .line = kind { return ["I", "II", "III", "IV"][max(0, min(3, grade - 1))] }
        return "\(grade)"
    }
    private var font: Font {
        switch size { case .sm: DS.Typo.caption; case .md: DS.Typo.headline; case .lg: DS.Typo.grade }
    }

    var body: some View {
        ZStack {
            Circle().fill(locked ? DS.Palette.track : DS.Palette.grade(fillGrade))
            Circle().strokeBorder(DS.Palette.gradeRing, lineWidth: 1)
            if locked {
                Image(systemName: "lock.fill").font(font).foregroundStyle(DS.Palette.textMuted)
            } else {
                Text(label).font(font).foregroundStyle(DS.Palette.onGrade(fillGrade))
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
        }
        .frame(width: size.side, height: size.side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(locked ? "Mit PRO sichtbar" : "")
    }

    private var a11yLabel: String {
        switch kind {
        case .overall: return "Gesamtgrad \(grade) von 9"
        case .region(let name): return "\(name), Grad \(grade) von 9"
        case .line: return "Liniengrad \(label)"
        }
    }
}

// MARK: - PowerMeter

struct PowerMeter: View {
    let value: Int
    var delta: Int = 0
    var progress: Double          // 0...1 bis zum nächsten Gesamtgrad
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s2) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s2) {
                Text("\(value)").font(DS.Typo.power).foregroundStyle(DS.Palette.text)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
                if delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(DS.Typo.headline)
                        .foregroundStyle(delta > 0 ? DS.Palette.success : DS.Palette.textMuted)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Palette.track)
                    Capsule().fill(DS.Palette.power)
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 8)
        }
        .animation(DS.Motion.reveal(reduced: reduceMotion), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power Level \(value)")
        .accessibilityValue(delta == 0 ? "" : (delta > 0 ? "plus \(delta)" : "minus \(-delta)"))
    }
}

// MARK: - RegionBars

struct RegionScore: Identifiable {
    let id: String        // "push", "pull", ...
    let name: String
    let grade: Int        // 1...9
    let score: Double     // 0...1
}

struct RegionBars: View {
    let regions: [RegionScore]
    var weakestID: String?
    var locked = false

    var body: some View {
        VStack(spacing: DS.Space.s3) {
            ForEach(regions) { r in
                let weakest = r.id == weakestID
                HStack(spacing: DS.Space.s3) {
                    Text(r.name).font(DS.Typo.footnote).foregroundStyle(DS.Palette.text)
                        .frame(minWidth: 72, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Palette.track)
                            if !locked {
                                Capsule().fill(DS.Palette.region(r.id))
                                    .frame(width: geo.size.width * max(0.02, min(1, r.score)))
                            }
                        }
                    }
                    .frame(height: 10)
                    if locked {
                        Image(systemName: "lock.fill").foregroundStyle(DS.Palette.textMuted)
                    } else {
                        GradeBadge(grade: r.grade, kind: .region(r.name), size: .sm)
                    }
                }
                .padding(.vertical, DS.Space.s1)
                .padding(.horizontal, DS.Space.s2)
                .overlay {
                    if weakest {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .strokeBorder(DS.Palette.accent, lineWidth: 2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if weakest {
                        Text("Schwächste").font(DS.Typo.caption).foregroundStyle(DS.Palette.accent)
                            .offset(y: -DS.Space.s4)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(locked ? "\(r.name), mit PRO sichtbar"
                                    : "\(r.name), Grad \(r.grade) von 9\(weakest ? ", schwächste Region" : "")")
            }
        }
    }
}

// MARK: - StageChain

struct StageItem: Identifiable {
    enum Status { case locked, current, cleared }
    let id: String
    let index: Int
    let name: String
    let criterion: String     // "10 Sekunden halten"
    let status: Status
}

struct StageChain: View {
    let stages: [StageItem]
    var onLog: (StageItem) -> Void = { _ in }
    @AccessibilityFocusState private var focused: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { i, s in
                HStack(alignment: .top, spacing: DS.Space.s3) {
                    VStack(spacing: 0) {
                        marker(s.status)
                        if i < stages.count - 1 {
                            Rectangle().fill(DS.Palette.border).frame(width: 2).frame(minHeight: DS.Space.s6)
                        }
                    }
                    VStack(alignment: .leading, spacing: DS.Space.s1) {
                        Text(s.name)
                            .font(s.status == .current ? DS.Typo.headline : DS.Typo.body)
                            .foregroundStyle(s.status == .locked ? DS.Palette.textMuted : DS.Palette.text)
                        Text(s.criterion).font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                        if s.status == .current {
                            PrimaryButton(title: "Satz loggen", size: .sm) { onLog(s) }
                                .padding(.top, DS.Space.s1)
                        }
                    }
                    .padding(.bottom, DS.Space.s4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stufe \(s.index) von \(stages.count), \(s.name), \(s.criterion), \(statusText(s.status))")
                .accessibilityFocused($focused, equals: s.id)
            }
        }
        .onAppear { focused = stages.first(where: { $0.status == .current })?.id }
    }

    @ViewBuilder private func marker(_ st: StageItem.Status) -> some View {
        switch st {
        case .locked:
            Circle().strokeBorder(DS.Palette.borderInput, lineWidth: 2).frame(width: 28, height: 28)
        case .current:
            Circle().fill(DS.Palette.accent).frame(width: 28, height: 28)
        case .cleared:
            ZStack {
                Circle().fill(DS.Palette.success)
                Image(systemName: "checkmark").font(DS.Typo.caption.weight(.bold)).foregroundStyle(DS.Palette.bg)
            }
            .frame(width: 28, height: 28)
        }
    }
    private func statusText(_ st: StageItem.Status) -> String {
        switch st { case .locked: "gesperrt"; case .current: "aktuell"; case .cleared: "geschafft" }
    }
}

// MARK: - NumberStepper

struct NumberStepper: View {
    enum Metric { case reps, seconds
        var label: String { self == .reps ? "Wiederholungen" : "Sekunden" }
    }
    @Binding var value: Int
    var metric: Metric = .reps
    var range: ClosedRange<Int> = 1...10_000

    var body: some View {
        HStack(spacing: DS.Space.s4) {
            stepButton("minus", enabled: value > range.lowerBound) { value = max(range.lowerBound, value - 1) }
            VStack(spacing: 0) {
                TextField("", value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(DS.Typo.power)
                    .foregroundStyle(DS.Palette.text)
                Text(metric.label).font(DS.Typo.caption).foregroundStyle(DS.Palette.textMuted)
            }
            .frame(minWidth: 96)
            stepButton("plus", enabled: value < range.upperBound) { value = min(range.upperBound, value + 1) }
        }
        .padding(DS.Space.s3)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Palette.borderInput, lineWidth: 1))
        .onChange(of: value) { _, v in if !range.contains(v) { value = min(max(v, range.lowerBound), range.upperBound) } }  // BUG-001
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(DS.Typo.headline)
                .frame(width: DS.Layout.minTap, height: DS.Layout.minTap)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Palette.surface))
                .foregroundStyle(DS.Palette.text)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    enum Size { case md, sm
        var height: CGFloat { self == .md ? 50 : 36 }
    }
    let title: String
    var size: Size = .md
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(DS.Palette.onAccent) }
            }
            .font(DS.Typo.headline)
            .frame(maxWidth: size == .md ? .infinity : nil, minHeight: size.height)
            .padding(.horizontal, DS.Space.s4)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Palette.accent))
            .foregroundStyle(DS.Palette.onAccent)
        }
        .buttonStyle(PressStyle())
        .disabled(isLoading)        // verhindert Doppel-Log
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(DS.Typo.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Palette.border))
                .foregroundStyle(DS.Palette.text)
        }
        .buttonStyle(PressStyle())
    }
}

private struct PressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.85 : 1))
            .animation(DS.Motion.fast, value: configuration.isPressed)
    }
}

// MARK: - Galerie (Design-System-Check, entspricht /design-Route)

struct DesignGallery: View {
    @State private var reps = 8
    private let regions = [
        RegionScore(id: "push", name: "Push", grade: 5, score: 0.55),
        RegionScore(id: "pull", name: "Pull", grade: 3, score: 0.30),
        RegionScore(id: "core", name: "Core", grade: 4, score: 0.44),
        RegionScore(id: "legs", name: "Beine", grade: 4, score: 0.41),
        RegionScore(id: "shoulders", name: "Schultern", grade: 6, score: 0.62),
        RegionScore(id: "grip", name: "Griff", grade: 5, score: 0.50),
    ]
    private let stages = [
        StageItem(id: "a", index: 1, name: "Stufe A", criterion: "3 × 10 Wdh.", status: .cleared),
        StageItem(id: "b", index: 2, name: "Stufe B", criterion: "20 Sekunden halten", status: .current),
        StageItem(id: "c", index: 3, name: "Stufe C", criterion: "10 Sekunden halten", status: .locked),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.s6) {
                Text("Grade").font(DS.Typo.title)
                ScrollView(.horizontal) {
                    HStack { ForEach(1...9, id: \.self) { GradeBadge(grade: $0) } }
                }
                HStack { ForEach(1...4, id: \.self) { GradeBadge(grade: $0, kind: .line, size: .sm) }
                         GradeBadge(grade: 5, locked: true) }
                GradeBadge(grade: 7, size: .lg)
                Text("Power").font(DS.Typo.title)
                PowerMeter(value: 1240, delta: 35, progress: 0.62)
                Text("Regionen").font(DS.Typo.title)
                RegionBars(regions: regions, weakestID: "pull")
                RegionBars(regions: regions, locked: true)
                Text("Stufen").font(DS.Typo.title)
                StageChain(stages: stages)
                Text("Eingabe").font(DS.Typo.title)
                NumberStepper(value: $reps)
                PrimaryButton(title: "Speichern") {}
                PrimaryButton(title: "Speichern", isLoading: true) {}
                SecondaryButton(title: "Abbrechen") {}
            }
            .padding(DS.Layout.gutter)
        }
        .background(DS.Palette.bg)
    }
}

#Preview("Light") { DesignGallery().preferredColorScheme(.light) }
#Preview("Dark") { DesignGallery().preferredColorScheme(.dark) }
#Preview("AX5") { DesignGallery().environment(\.dynamicTypeSize, .accessibility5) }
