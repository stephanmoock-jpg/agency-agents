import SwiftUI

// S13
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var confirmWipe = false
    @State private var showPaywall = false

    var body: some View {
        Form {
            #if !PERSONAL
            Section("PRO") {
                LabeledContent("Status", value: store.isPro ? "Aktiv" : "Nicht aktiv")
                if !store.isPro { Button("PRO ansehen") { showPaywall = true } }
                Button("Käufe wiederherstellen") { Task { await store.restore() } }
                Link("Abo verwalten", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            #endif
            Section("Daten") {
                if let exportURL {
                    ShareLink("CSV teilen", item: exportURL)
                } else {
                    Button("Sätze als CSV exportieren") { exportURL = try? model.exportCSV() }
                }
                Button("Einstufung wiederholen") {
                    model.wipeAssessmentOnly()
                    dismiss()
                }
                Button("Alle Daten löschen", role: .destructive) { confirmWipe = true }
            }
            Section {
                Text("Deine Daten bleiben auf diesem iPhone. Es gibt kein Konto und keinen Upload. Ohne Export gehen sie mit dem Gerät verloren.")
                Text("Training auf eigenes Risiko. Die App ersetzt keine ärztliche oder trainerische Beratung.")
            }
            .font(DS.Typo.footnote).foregroundStyle(DS.Palette.textMuted)
            Section {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                LabeledContent("Katalog", value: "v\(model.catalog.version)")
            }
        }
        .navigationTitle("Einstellungen")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        .confirmationDialog("Wirklich alles löschen?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Alles löschen", role: .destructive) { model.wipeAll(); dismiss() }
        } message: {
            Text("Sätze, Einstufung, Verlauf und Plan werden entfernt. Das lässt sich nicht rückgängig machen.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
