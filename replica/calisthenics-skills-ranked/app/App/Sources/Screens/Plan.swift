import SwiftUI
import GradingKit

// S10
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @State private var logStage: Stage?

    var body: some View {
        ProGate(title: "Plan für deine schwächste Region",
                text: "PRO stellt dir die nächsten Stufen zusammen, die deinen Gesamtgrad am stärksten anheben.") {
            content
        }
        .navigationTitle("Plan")
        .sheet(item: $logStage) { LogSheet(stage: $0) }
    }

    @ViewBuilder private var content: some View {
        let _ = model.summary            // beobachten: nach jedem Log neu zeichnen
        if let plan = model.currentPlan() {
            List {
                Section {
                    Text("Ziel: \(model.catalog.region(plan.targetRegionID)?.name ?? plan.targetRegionID) aufholen")
                        .font(DS.Typo.headline)
                    if plan.status == "done" {
                        Label("Plan erledigt. Erstelle einen neuen für den nächsten Schritt.", systemImage: "checkmark.seal")
                            .foregroundStyle(DS.Palette.success)
                    }
                }
                Section("Übungen") {
                    ForEach(plan.items.sorted { $0.sort < $1.sort }) { item in
                        if let s = model.catalog.stages[model.catalog.resolve(item.stageID)] {
                            HStack(spacing: DS.Space.s3) {
                                Button { model.toggleDone(item) } label: {
                                    Image(systemName: item.doneAt == nil ? "circle" : "checkmark.circle.fill")
                                        .font(DS.Typo.title)
                                        .foregroundStyle(item.doneAt == nil ? DS.Palette.borderInput : DS.Palette.success)
                                        .frame(width: DS.Layout.minTap, height: DS.Layout.minTap)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.doneAt == nil ? "Als erledigt markieren" : "Erledigt, zurücksetzen")
                                VStack(alignment: .leading) {
                                    Text(s.name).font(DS.Typo.body)
                                    Text("\(model.catalog.line(s.lineID)?.name ?? "") · \(item.sets) × \(s.criterion)")
                                        .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
                                }
                                Spacer()
                                Button("Loggen") { logStage = s }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Section {
                    Button("Plan neu erstellen") { model.generatePlan() }
                }
            }
        } else {
            EmptyStateView(symbol: "checklist", title: "Kein aktiver Plan",
                           text: "Der Plan nimmt die nächsten offenen Stufen deiner schwächsten Region.",
                           actionTitle: "Plan erstellen") { model.generatePlan() }
        }
    }
}
