import SwiftUI

/// 新建任务表单：可一次录入多个进度节点
struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// (标题, 备注, 截止日期, 初始节点标题)
    var onCreate: (String, String, Date?, [String]) -> Void

    @State private var title = ""
    @State private var note = ""
    @State private var hasDue = false
    @State private var due = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var draftNode = ""
    @State private var nodeTitles: [String] = []
    @FocusState private var focus: Field?

    private enum Field { case title, node }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务名称") {
                    TextField("例如：上线个人博客", text: $title)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .node }
                }

                Section("备注（可选）") {
                    TextField("补充说明", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("截止日期（可选）") {
                    Toggle("设置截止日期", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("截止", selection: $due, displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        TextField("输入节点后回车添加", text: $draftNode)
                            .focused($focus, equals: .node)
                            .submitLabel(.done)
                            .onSubmit(addDraft)
                        Button {
                            addDraft()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(draftNode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(Array(nodeTitles.enumerated()), id: \.offset) { idx, t in
                        HStack(spacing: 10) {
                            Image(systemName: "\(idx + 1).circle")
                                .foregroundStyle(Theme.accent)
                            Text(t)
                            Spacer()
                        }
                    }
                    .onDelete { nodeTitles.remove(atOffsets: $0) }
                } header: {
                    Text("进度节点（\(nodeTitles.count)）")
                } footer: {
                    Text("这些节点会按顺序排列，每完成一个，任务的进度条就前进一格。也可以先建空任务，之后在详情页里再加。")
                }
            }
            .navigationTitle("新建任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        addDraft()
                        onCreate(title, note, hasDue ? due : nil, nodeTitles)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focus = .title }
        }
    }

    private func addDraft() {
        let t = draftNode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        nodeTitles.append(t)
        draftNode = ""
        focus = .node
    }
}

/// 编辑任务信息（标题 / 备注 / 截止日期）
struct TaskInfoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var task: Task
    var onSave: (String, String, Date?) -> Void

    @State private var title: String
    @State private var note: String
    @State private var hasDue: Bool
    @State private var due: Date

    init(task: Task, onSave: @escaping (String, String, Date?) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note)
        _hasDue = State(initialValue: task.dueDate != nil)
        _due = State(initialValue: task.dueDate ?? Date().addingTimeInterval(7 * 24 * 3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务名称") {
                    TextField("名称", text: $title)
                }
                Section("备注") {
                    TextField("补充说明", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("截止", selection: $due, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                               note,
                               hasDue ? due : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// 编辑单个节点的标题和备注
struct NodeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var node: TaskNode
    var onSave: (TaskNode) -> Void

    @State private var title: String
    @State private var note: String

    init(node: TaskNode, onSave: @escaping (TaskNode) -> Void) {
        self.node = node
        self.onSave = onSave
        _title = State(initialValue: node.title)
        _note = State(initialValue: node.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("节点名称") {
                    TextField("名称", text: $title)
                }
                Section("该节点的备注") {
                    TextField("可选", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("编辑节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var n = node
                        n.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        n.note = note
                        onSave(n)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
