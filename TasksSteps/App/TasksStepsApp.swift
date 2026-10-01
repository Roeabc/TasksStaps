import SwiftUI

@main
struct TasksStepsApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
        // 落盘已经在 TaskStore 的每次改动里做了（save()），
        // 这里不再挂 onChange(of: scenePhase) —— 它在 iOS 17 已废弃，
        // 用双参数写法又和 TaskListView 里的重复，直接删掉最干净。
    }
}
