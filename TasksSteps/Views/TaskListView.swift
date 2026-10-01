import SwiftUI

/// 首页：任务列表 + 总进度概览
struct TaskListView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingEditor = false
    @State private var pendingDelete: Task?
    @State private var lastDeleted: Task?
    @State private var showUndoBar = false
    @State private var undoDismissTask: Task<Void, Never>?

    private var visible: [Task] { store.displayedTasks }

    var body: some View {
        NavigationStack {
            Group {
                if store.tasks.isEmpty {
                    emptyState
                } else {
                    listBody
                }
            }
            .navigationTitle("任务进度")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !store.tasks.isEmpty {
                        Menu {
                            Picker("排序方式", selection: $store.sortMode) {
                                ForEach(TaskStore.SortMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                TaskEditorSheet { title, note, due, nodeTitles in
                    store.add(title: title, note: note, dueDate: due, nodeTitles: nodeTitles)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                TaskDetailView(taskID: id)
            }
            .overlay(alignment: .bottom) { undoBar }
            .confirmationDialog(
                pendingDelete.map { "删除任务「\($0.title)」？" } ?? "",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let t = pendingDelete {
                        store.delete(t)
                        lastDeleted = t
                        withAnimation { showUndoBar = true }
                        scheduleUndoDismiss()
                    }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("该任务下的所有节点也会一起删除。")
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { store.save() }
            }
        }
    }

    // MARK: - 列表

    private var listBody: some View {
        List {
            Section {
                OverviewCard(stats: store.totalStats,
                             tasks: store.tasks)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(visible) { task in
                    ZStack {
                        NavigationLink(value: task.id) { EmptyView() }
                            .opacity(0)
                        TaskRow(task: task)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = task
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            store.duplicate(task)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            store.completeAll(of: task.id)
                        } label: {
                            Label("全部完成", systemImage: "checkmark.circle")
                        }
                        .tint(Theme.doneGreen)
                    }
                }
                .onMove(perform: store.move)
            } header: {
                Text("共 \(store.tasks.count) 个任务")
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: visible)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent.opacity(0.7))
            Text("还没有任务")
                .font(.title3.weight(.semibold))
            Text("新建一个任务，把它拆成若干进度节点，\n完成一个节点进度条就前进一格。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingEditor = true
            } label: {
                Label("新建任务", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(32)
    }

    // MARK: - 撤销条

    @ViewBuilder
    private var undoBar: some View {
        if showUndoBar, let deleted = lastDeleted {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                Text("已删除「\(deleted.title)」")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("撤销") {
                    store.tasks.append(deleted)
                    store.save()
                    lastDeleted = nil
                    withAnimation { showUndoBar = false }
                }
                .font(.subheadline.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color(.label).opacity(0.88)))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func scheduleUndoDismiss() {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation { showUndoBar = false }
                    lastDeleted = nil
                }
            }
        }
    }
}

// MARK: - 顶部总览卡

private struct OverviewCard: View {
    var stats: (tasks: Int, nodes: Int, done: Int)
    var tasks: [Task]

    private var overall: Double {
        stats.nodes == 0 ? 0 : Double(stats.done) / Double(stats.nodes)
    }

    private var finished: Int { tasks.filter(\.isFinished).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ProgressRing(progress: overall, size: 62, lineWidth: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text("整体进度")
                        .font(.headline)
                    Text("\(stats.done) / \(stats.nodes) 个节点已完成")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("已完结任务 \(finished) / \(stats.tasks)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 任务行

private struct TaskRow: View {
    var task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text("\(task.percent)%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.progressColor(task.progress))
            }

            MiniProgressBar(progress: task.progress)

            HStack(spacing: 10) {
                Label("\(task.doneCount)/\(task.nodes.count)", systemImage: "checklist")
                if let next = task.nextNode {
                    Text("· 下一步：\(next.title)")
                        .lineLimit(1)
                } else if task.nodes.isEmpty {
                    Text("· 还没拆节点")
                } else {
                    Text("· 全部完成 🎉")
                }
                Spacer(minLength: 0)
                if let due = task.dueDate {
                    Label(Self.dateText(due),
                          systemImage: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                        .foregroundStyle(task.isOverdue ? Theme.warnOrange : Color.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.progressColor(task.progress))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}
