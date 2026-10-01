import Foundation
import Combine
// 注意：`move(fromOffsets:toOffset:)` 与 `remove(atOffsets:)` 是 SwiftUI 给
// MutableCollection 加的扩展，只 import Foundation 是不够的。
import SwiftUI

/// 单个任务节点（进度节点）。
/// 勾选 done 之后，所属任务的进度条会实时前进。
struct TaskNode: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
    var note: String = ""
    var createdAt: Date = Date()
    var completedAt: Date?

    init(title: String, note: String = "") {
        self.title = title
        self.note = note
    }
}

/// 一个可管理的任务：由若干进度节点组成。
struct Task: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var nodes: [TaskNode] = []
    var createdAt: Date = Date()
    var dueDate: Date?

    /// 进度：0.0 ~ 1.0
    var progress: Double {
        guard !nodes.isEmpty else { return 0 }
        let done = nodes.filter(\.done).count
        return Double(done) / Double(nodes.count)
    }

    /// 百分比整数，例如 42
    var percent: Int {
        guard !nodes.isEmpty else { return 0 }
        return Int((progress * 100).rounded())
    }

    var doneCount: Int { nodes.filter(\.done).count }
    var remainingCount: Int { nodes.count - doneCount }

    var isFinished: Bool { !nodes.isEmpty && doneCount == nodes.count }

    /// 下一个待完成节点（用于列表页提示）
    var nextNode: TaskNode? { nodes.first(where: { !$0.done }) }

    /// 是否逾期
    var isOverdue: Bool {
        guard let due = dueDate, !isFinished else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }
}

/// 全局数据仓库：负责增删改与本地持久化（Application Support / tasks.json）。
final class TaskStore: ObservableObject {

    @Published var tasks: [Task] = []
    @Published var sortMode: SortMode = .manual

    enum SortMode: String, CaseIterable, Identifiable {
        case manual, createdAsc, progressDesc, dueAsc

        var id: String { rawValue }

        var label: String {
            switch self {
            case .manual: return "手动顺序"
            case .createdAsc: return "按创建时间"
            case .progressDesc: return "按进度"
            case .dueAsc: return "按截止日期"
            }
        }
    }

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("tasks.json")
        load()
        if tasks.isEmpty { tasks = TaskStore.sampleData }
    }

    // MARK: - 排序后的视图数据

    var displayedTasks: [Task] {
        switch sortMode {
        case .manual:
            return tasks
        case .createdAsc:
            return tasks.sorted { $0.createdAt < $1.createdAt }
        case .progressDesc:
            // 未完成的排前面，同组内进度高的优先
            return tasks.sorted {
                if $0.isFinished != $1.isFinished { return !$0.isFinished }
                return $0.progress > $1.progress
            }
        case .dueAsc:
            return tasks.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (l?, r?): return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return $0.createdAt < $1.createdAt
                }
            }
        }
    }

    var totalStats: (tasks: Int, nodes: Int, done: Int) {
        let nodes = tasks.reduce(0) { $0 + $1.nodes.count }
        let done = tasks.reduce(0) { $0 + $1.doneCount }
        return (tasks.count, nodes, done)
    }

    // MARK: - 任务

    func add(title: String, note: String = "", dueDate: Date? = nil, nodeTitles: [String] = []) {
        var task = Task(title: title.trimmingCharacters(in: .whitespacesAndNewlines), note: note, dueDate: dueDate)
        task.nodes = nodeTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { TaskNode(title: $0) }
        tasks.append(task)
        save()
    }

    func update(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        save()
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func duplicate(_ task: Task) {
        var copy = task
        copy.id = UUID()
        copy.createdAt = Date()
        copy.nodes = task.nodes.map { var n = $0; n.id = UUID(); return n }
        tasks.append(copy)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        sortMode = .manual
        save()
    }

    // MARK: - 节点

    func addNode(title: String, to taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        tasks[ti].nodes.append(TaskNode(title: t))
        save()
    }

    func addNodes(titles: [String], to taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let cleaned = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        tasks[ti].nodes.append(contentsOf: cleaned.map { TaskNode(title: $0) })
        save()
    }

    func toggle(node nodeID: UUID, in taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ni = tasks[ti].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var node = tasks[ti].nodes[ni]
        node.done.toggle()
        node.completedAt = node.done ? Date() : nil
        tasks[ti].nodes[ni] = node
        save()
    }

    func setDone(_ done: Bool, node nodeID: UUID, in taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ni = tasks[ti].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        tasks[ti].nodes[ni].done = done
        tasks[ti].nodes[ni].completedAt = done ? Date() : nil
        save()
    }

    func renameNode(_ nodeID: UUID, in taskID: UUID, to newTitle: String) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ni = tasks[ti].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        tasks[ti].nodes[ni].title = t
        save()
    }

    func updateNode(_ node: TaskNode, in taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ni = tasks[ti].nodes.firstIndex(where: { $0.id == node.id }) else { return }
        tasks[ti].nodes[ni] = node
        save()
    }

    func deleteNode(_ nodeID: UUID, in taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[ti].nodes.removeAll { $0.id == nodeID }
        save()
    }

    func deleteNodes(at offsets: IndexSet, in taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[ti].nodes.remove(atOffsets: offsets)
        save()
    }

    func moveNodes(in taskID: UUID, from source: IndexSet, to destination: Int) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[ti].nodes.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func resetProgress(of taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        for i in tasks[ti].nodes.indices {
            tasks[ti].nodes[i].done = false
            tasks[ti].nodes[i].completedAt = nil
        }
        save()
    }

    func completeAll(of taskID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        for i in tasks[ti].nodes.indices where !tasks[ti].nodes[i].done {
            tasks[ti].nodes[i].done = true
            tasks[ti].nodes[i].completedAt = Date()
        }
        save()
    }

    // MARK: - 持久化

    private struct Payload: Codable {
        var tasks: [Task]
        var sortMode: SortMode
    }

    func save() {
        do {
            let data = try encoder.encode(Payload(tasks: tasks, sortMode: sortMode))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[TaskStore] 保存失败: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(Payload.self, from: data) else { return }
        tasks = payload.tasks
        sortMode = payload.sortMode
    }

    /// 首次启动时给点示例数据，方便立刻看到进度条效果。
    static var sampleData: [Task] {
        [
            Task(
                title: "上线个人博客",
                note: "示例任务：勾选节点即可看到进度条前进。",
                nodes: [
                    TaskNode(title: "选域名", done: true),
                    TaskNode(title: "买服务器", done: true),
                    TaskNode(title: "写首页"),
                    TaskNode(title: "配置 SSL"),
                    TaskNode(title: "发布上线")
                ]
            ),
            Task(
                title: "读完《Swift 编程权威指南》",
                nodes: [
                    TaskNode(title: "第 1-4 章", done: true),
                    TaskNode(title: "第 5-8 章"),
                    TaskNode(title: "第 9-12 章")
                ]
            )
        ]
    }
}
