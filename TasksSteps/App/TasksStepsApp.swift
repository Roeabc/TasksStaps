import SwiftUI

@main
struct TasksStepsApp: App {
    @StateObject private var store = TaskStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { phase in
            // 退到后台时落盘，避免数据丢失
            if phase != .active { store.save() }
        }
    }
}
