import SwiftUI

/// 任务详情：大进度条 + 节点清单 + 勾选即推进进度
struct TaskDetailView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    let taskID: UUID

    @State private var newTitle = ""
    @State private var showBulkAdd = false
    @State private var editing: TaskNode?
    @State private var showInfoEditor = false
    @State private var showResetConfirm = false
    @FocusState private var nodeFieldFocused: Bool

    private var task: Task? { store.tasks.first { $0.id == taskID } }

    var body: some View {
        Group {
            if let task {
                content(task)
            } else {
                ContentUnavailableView("任务已删除", systemImage: "trash")
            }
        }
        .navigationTitle(task?.title ?? "任务")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 主体

    private func content(_ task: Task) -> some View {
        List {
            // 进度总览
            Section {
                ProgressHeader(task: task)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                HStack(spacing: 10) {
                    Button {
                        store.completeAll(of: task.id)
                    } label: {
                        Label("全部勾选", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.doneGreen)
                    .disabled(task.nodes.isEmpty || task.isFinished)

                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("重置进度", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.warnOrange)
                    .disabled(task.doneCount == 0)
                }
                .font(.subheadline)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // 节点清单
            Section {
                if task.nodes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("还没有进度节点")
                            .font(.subheadline.weight(.medium))
                        Text("在下面输入框添加，比如「选域名」「买服务器」「发布上线」。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(Array(task.nodes.enumerated()), id: \.element.id) { idx, node in
                        NodeRow(index: idx + 1, node: node)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    store.toggle(node: node.id, in: task.id)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.deleteNode(node.id, in: task.id)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    editing = node
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                    }
                    .onMove { source, dest in
                        store.moveNodes(in: task.id, from: source, to: dest)
                    }
                }
            } header: {
                HStack {
                    Text("进度节点 \(task.doneCount)/\(task.nodes.count)")
                    Spacer()
                    if task.nodes.count > 1 {
                        Text("长按可拖动排序")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 添加节点
            Section("添加节点") {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Theme.accent)
                    TextField("输入节点名称后回车", text: $newTitle)
                        .focused($nodeFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addNode)
                    Button("添加", action: addNode)
                        .font(.subheadline.weight(.semibold))
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button {
                    showBulkAdd = true
                } label: {
                    Label("批量粘贴多个节点", systemImage: "text.badge.plus")
                        .font(.subheadline)
                }
            }

            // 备注
            if !task.note.isEmpty {
                Section("备注") {
                    Text(task.note)
                        .font(.subheadline)
                }
            }

            Section {
                Button(role: .destructive) {
                    store.delete(task)
                    dismiss()
                } label: {
                    Label("删除这个任务", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: task)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showInfoEditor = true
                    } label: {
                        Label("编辑任务信息", systemImage: "square.and.pencil")
                    }
                    Button {
                        store.duplicate(task)
                    } label: {
                        Label("复制任务", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("重置全部节点", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        store.delete(task)
                        dismiss()
                    } label: {
                        Label("删除任务", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showBulkAdd) {
            BulkAddSheet { titles in
                store.addNodes(titles: titles, to: task.id)
            }
        }
        .sheet(item: $editing) { node in
            NodeEditorSheet(node: node) { updated in
                store.updateNode(updated, in: task.id)
            }
        }
        .sheet(isPresented: $showInfoEditor) {
            TaskInfoEditorSheet(task: task) { title, note, due in
                var t = task
                t.title = title
                t.note = note
                t.dueDate = due
                store.update(t)
            }
        }
        .confirmationDialog("重置进度？",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("全部节点改为未完成", role: .destructive) {
                withAnimation { store.resetProgress(of: task.id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有节点会被标记为未完成，进度条回到 0%。")
        }
    }

    private func addNode() {
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        withAnimation { store.addNode(title: t, to: taskID) }
        newTitle = ""
        nodeFieldFocused = true
    }
}

// MARK: - 详情页顶部进度卡

private struct ProgressHeader: View {
    var task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(task.percent)%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.progressColor(task.progress))
                    .contentTransition(.numericText())
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(task.doneCount) / \(task.nodes.count) 节点")
                        .font(.subheadline.weight(.medium))
                    if task.isFinished {
                        Label("已完成", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.doneGreen)
                    } else if let next = task.nextNode {
                        Text("下一步：\(next.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("等待拆解节点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            BigProgressBar(progress: task.progress,
                           height: 18,
                           segments: task.nodes.count)

            HStack(spacing: 12) {
                if let due = task.dueDate {
                    Label(dueText(due), systemImage: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                        .foregroundStyle(task.isOverdue ? Theme.warnOrange : Color.secondary)
                }
                if task.isOverdue {
                    Text("已逾期")
                        .foregroundStyle(Theme.warnOrange)
                }
                Spacer()
                Text("创建于 \(dayText(task.createdAt))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func dueText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "截止 M月d日"
        return f.string(from: d)
    }

    private func dayText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: d)
    }
}

// MARK: - 节点行

private struct NodeRow: View {
    var index: Int
    var node: TaskNode

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NodeCheck(done: node.done)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(index).")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(node.title)
                        .font(.body)
                        .strikethrough(node.done, color: .secondary)
                        .foregroundStyle(node.done ? Color.secondary : Color.primary)
                        .lineLimit(3)
                }
                if !node.note.isEmpty {
                    Text(node.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if node.done, let at = node.completedAt {
                    Text("完成于 \(Self.timeText(at))")
                        .font(.caption2)
                        .foregroundStyle(Theme.doneGreen.opacity(0.9))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    static func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }
}

// MARK: - 批量添加节点

private struct BulkAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: ([String]) -> Void

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .font(.body)
                } header: {
                    Text("每行一个节点")
                } footer: {
                    Text("把一整份清单粘进来，一行会变成一个进度节点。空行会自动忽略。")
                }
            }
            .navigationTitle("批量添加节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onAdd(parsed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(parsed.isEmpty)
                }
            }
        }
    }

    private var parsed: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
