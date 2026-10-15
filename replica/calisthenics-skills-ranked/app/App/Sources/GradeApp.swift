import SwiftUI
import SwiftData
import GradingKit

@main
struct GradeApp: App {
    let container: ModelContainer
    @State private var model: AppModel
    @State private var store = StoreService()

    init() {
        let schema = Schema([SetLog.self, AssessmentAnswer.self, RankSnapshot.self, Plan.self, PlanItem.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            fatalError("ModelContainer: \(error)")
        }
        if inMemory { UserDefaults.standard.set(false, forKey: "hasOnboarded") }
        _model = State(initialValue: AppModel(context: container.mainContext, catalog: AppModel.loadCatalog()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(store)
                .tint(DS.Palette.accent)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if model.hasOnboarded { MainTabs() } else { OnboardingFlow() }
        }
        .onChange(of: phase) { _, p in if p == .active { model.ensureDailySnapshot() } }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @State private var levelUp: AppModel.LogOutcome?

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Rang", systemImage: "rosette") }
            NavigationStack { SkillsView() }
                .tabItem { Label("Skills", systemImage: "list.bullet.indent") }
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "checklist") }
            NavigationStack { HistoryView() }
                .tabItem { Label("Verlauf", systemImage: "chart.xyaxis.line") }
        }
        .overlay(alignment: .bottom) { LogToast().padding(.bottom, 64) }
        .onChange(of: model.lastOutcome) { _, o in
            guard let o, o.clearedStage != nil || o.overallGradeUp != nil || o.regionGradeUp != nil else { return }
            Task { try? await Task.sleep(for: .milliseconds(450)); levelUp = o }   // nach Sheet-Dismiss
        }
        .sheet(item: $levelUp) { LevelUpSheet(outcome: $0) }
    }
}
