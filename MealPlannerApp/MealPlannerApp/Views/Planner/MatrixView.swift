import SwiftUI
import SwiftData

private struct MatrixUndoAction {
    let taskID: UUID
    let completedAt: Date?
}

private struct MatrixGridHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > value { value = next }
    }
}

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}
    @Query(
        filter: #Predicate<PlannerTaskEntity> { task in
            !task.isCompleted && !task.isEvent
        },
        sort: \PlannerTaskEntity.createdAt
    ) private var tasks: [PlannerTaskEntity]
    @State private var showQuickAdd = false
    @State private var editingTask: PlannerTaskEntity?
    @State private var pendingUndo: MatrixUndoAction?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var completingTaskID: UUID?
    /// Locked after first layout so keyboard / Quick Add never shrinks the quadrants.
    @State private var lockedGridHeight: CGFloat = 0

    private let matrixFABClearance: CGFloat = 78

    private var openTasks: [PlannerTaskEntity] { tasks }

    private var tasksByQuadrant: [MatrixQuadrant: [PlannerTaskEntity]] {
        Dictionary(grouping: tasks, by: { $0.priority.matrixQuadrant })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Matrix", onMenu: onOpenDrawer)
                .padding(.bottom, 14)

            GeometryReader { geo in
                let gap: CGFloat = 10
                let contentHeight = lockedGridHeight > 0 ? lockedGridHeight : geo.size.height
                let w = (geo.size.width - 32 - gap) / 2
                let h = max(160, (contentHeight - gap - matrixFABClearance) / 2)
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        quadrant(.urgentImportant, width: w, height: h)
                        quadrant(.notUrgentImportant, width: w, height: h)
                    }
                    HStack(spacing: gap) {
                        quadrant(.urgentUnimportant, width: w, height: h)
                        quadrant(.notUrgentUnimportant, width: w, height: h)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, matrixFABClearance)
            }
            .frame(height: lockedGridHeight > 0 ? lockedGridHeight : nil)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: MatrixGridHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(MatrixGridHeightKey.self) { height in
                if height > 100, lockedGridHeight == 0 {
                    lockedGridHeight = height
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .dialFABChrome(
            leading: {
                Group {
                    if pendingUndo != nil {
                        UndoFAB(accessibilityHint: "Marks the last matrix task incomplete again") {
                            performUndo()
                        }
                        .padding(.leading, 22)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: pendingUndo != nil)
            },
            fab: {
                OrangeFAB { showQuickAdd = true }
            }
        )
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }

    private func quadrant(_ q: MatrixQuadrant, width: CGFloat, height: CGFloat) -> some View {
        let items = tasksByQuadrant[q, default: []]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(q.roman). \(q.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(q.tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text("\(items.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(q.tint)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(matrixQuadrantHeaderLabel(q, count: items.count))
            .accessibilityAddTraits(.isHeader)
            if items.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { task in
                            matrixTaskRow(task)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .padding(10)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(q.tint.opacity(0.35), lineWidth: 1)
        )
        .dropDestination(for: String.self) { items, _ in
            moveTask(items, to: q)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(matrixQuadrantHeaderLabel(q, count: items.count))
        .accessibilityHint("Drop tasks here to change priority")
    }

    private func matrixQuadrantHeaderLabel(_ q: MatrixQuadrant, count: Int) -> String {
        "\(q.roman). \(q.title), \(count) open task\(count == 1 ? "" : "s")"
    }

    private func matrixTaskRow(_ task: PlannerTaskEntity) -> some View {
        HStack(alignment: .top, spacing: 8) {
            TaskCheckbox(
                completed: completingTaskID == task.id,
                overdue: task.isOverdue
            ) {
                completeTask(task)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                if let due = task.dueAt {
                    Text(PlannerDate.shortDue(due))
                        .font(.caption2)
                        .foregroundStyle(task.isOverdue ? Theme.danger : Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(matrixTaskAccessibilityLabel(task))
            .accessibilityHint("Double tap to edit. Drag to another quadrant to change priority.")
        }
        .draggable(task.id.uuidString)
    }

    private func moveTask(_ items: [String], to quadrant: MatrixQuadrant) -> Bool {
        guard let raw = items.first,
              let id = UUID(uuidString: raw),
              let task = openTasks.first(where: { $0.id == id }) else { return false }
        let newPriority = quadrant.defaultPriority
        guard task.priority != newPriority else { return false }
        task.priority = newPriority
        try? modelContext.save()
        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
        return true
    }

    private func completeTask(_ task: PlannerTaskEntity) {
        guard completingTaskID == nil else { return }
        completingTaskID = task.id
        appModel.taskCompletionHaptic()
        let snapshot = MatrixUndoAction(taskID: task.id, completedAt: task.completedAt)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard completingTaskID == task.id else { return }
            task.isCompleted = true
            task.completedAt = .now
            try? modelContext.save()
            Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
            completingTaskID = nil
            scheduleUndo(snapshot)
        }
    }

    private func scheduleUndo(_ action: MatrixUndoAction) {
        pendingUndo = action
        undoDismissTask?.cancel()
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            pendingUndo = nil
        }
    }

    private func performUndo() {
        undoDismissTask?.cancel()
        guard let action = pendingUndo,
              let task = tasks.first(where: { $0.id == action.taskID }) else {
            pendingUndo = nil
            return
        }
        pendingUndo = nil
        task.isCompleted = false
        task.completedAt = action.completedAt
        try? modelContext.save()
        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
    }

    private func matrixTaskAccessibilityLabel(_ task: PlannerTaskEntity) -> String {
        if let due = task.dueAt {
            return "\(task.title), due \(PlannerDate.shortDue(due))"
        }
        return task.title
    }
}
