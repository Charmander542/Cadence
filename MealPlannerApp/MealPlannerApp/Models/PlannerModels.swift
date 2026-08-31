import Foundation
import SwiftData
import SwiftUI

enum TaskPriority: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        case .none: return "No Priority"
        }
    }

    var flagColor: Color {
        switch self {
        case .high: return Theme.flagHigh
        case .medium: return Theme.flagMedium
        case .low: return Theme.flagLow
        case .none: return Theme.flagNone
        }
    }

    /// TickTick default: flag maps onto Eisenhower quadrants.
    var matrixQuadrant: MatrixQuadrant {
        switch self {
        case .high: return .urgentImportant
        case .medium: return .notUrgentImportant
        case .low: return .urgentUnimportant
        case .none: return .notUrgentUnimportant
        }
    }
}

enum MatrixQuadrant: String, CaseIterable, Identifiable, Hashable {
    case urgentImportant
    case notUrgentImportant
    case urgentUnimportant
    case notUrgentUnimportant

    var id: String { rawValue }

    var roman: String {
        switch self {
        case .urgentImportant: return "I"
        case .notUrgentImportant: return "II"
        case .urgentUnimportant: return "III"
        case .notUrgentUnimportant: return "IV"
        }
    }

    var title: String {
        switch self {
        case .urgentImportant: return "Urgent & Important"
        case .notUrgentImportant: return "Not Urgent & Important"
        case .urgentUnimportant: return "Urgent & Unimportant"
        case .notUrgentUnimportant: return "Not Urgent & Unimportant"
        }
    }

    var tint: Color {
        switch self {
        case .urgentImportant: return Theme.matrixI
        case .notUrgentImportant: return Theme.matrixII
        case .urgentUnimportant: return Theme.matrixIII
        case .notUrgentUnimportant: return Theme.matrixIV
        }
    }

    var defaultPriority: TaskPriority {
        switch self {
        case .urgentImportant: return .high
        case .notUrgentImportant: return .medium
        case .urgentUnimportant: return .low
        case .notUrgentUnimportant: return .none
        }
    }
}

enum HabitPeriod: String, Codable, CaseIterable, Hashable {
    case morning, afternoon, evening, other

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Night"
        case .other: return "Others"
        }
    }
}

enum HabitFrequency: String, Codable, CaseIterable, Hashable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

enum TaskRecurrence: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case daily
    case weekly
    case customWeekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .customWeekly: return "Custom"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum CalendarScope: String, CaseIterable, Identifiable, Hashable {
    case year, month, week, threeDay, day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .year: return "Year"
        case .month: return "Month"
        case .week: return "Week"
        case .threeDay: return "3 Day"
        case .day: return "Day"
        }
    }

    var icon: String {
        switch self {
        case .year: return "square.grid.3x3"
        case .month: return "calendar"
        case .week: return "rectangle.split.3x1"
        case .threeDay: return "rectangle.split.2x1"
        case .day: return "rectangle.split.1x2"
        }
    }
}

enum PlannerDestination: Hashable {
    case today
    case next7
    case inbox
    case list(UUID)
    case meals
    case shop
    case matrix
}

@Model
final class PlannerTagEntity {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(name: String, colorHex: String) {
        id = UUID()
        self.name = name.lowercased()
        self.colorHex = colorHex
        createdAt = .now
    }
}

@Model
final class TaskListEntity {
    var id: UUID
    var name: String
    var isSystem: Bool
    var sortOrder: Int
    var createdAt: Date
    /// When true, undated open tasks in this list appear on Today.
    var showInToday: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \PlannerTaskEntity.list)
    var tasks: [PlannerTaskEntity]

    init(name: String, isSystem: Bool = false, sortOrder: Int = 0, showInToday: Bool? = nil) {
        id = UUID()
        self.name = name
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        createdAt = .now
        if let showInToday {
            self.showInToday = showInToday
        } else {
            self.showInToday = name.lowercased() == "inbox"
        }
        tasks = []
    }
}

@Model
final class PlannerTaskEntity {
    var id: UUID
    var title: String
    var notes: String
    var location: String = ""
    var tagsRaw: String = ""
    var colorHex: String = ""
    var dueAt: Date?
    var reminderAt: Date?
    var durationMinutes: Int
    var recurrenceRaw: String = "none"
    /// Bitmask for custom weekly repeat (Calendar weekday 1=Sun … 7=Sat).
    var recurrenceWeekdayMask: Int = 0
    var priorityRaw: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var list: TaskListEntity?
    /// EventKit event identifiers per Apple sub-calendar (calendarIdentifier → eventIdentifier).
    var appleCalendarEventIDsJSON: String = "{}"
    /// Google Calendar API event ids per calendar (calendarID → eventID).
    var googleCalendarEventIDsJSON: String = "{}"
    /// Legacy single-calendar EventKit id (migrated into `appleCalendarEventIDsJSON`).
    var appleCalendarEventID: String?
    /// Legacy single-calendar Google id (migrated into `googleCalendarEventIDsJSON`).
    var googleCalendarEventID: String?
    /// Calendar events (created via PlannerEventSheet) — excluded from task/todo lists.
    var isEvent: Bool = false

    init(
        title: String,
        dueAt: Date? = nil,
        priority: TaskPriority = .none,
        list: TaskListEntity? = nil
    ) {
        id = UUID()
        self.title = title
        notes = ""
        location = ""
        self.dueAt = dueAt
        reminderAt = nil
        durationMinutes = 60
        recurrenceRaw = TaskRecurrence.none.rawValue
        priorityRaw = priority.rawValue
        isCompleted = false
        completedAt = nil
        createdAt = .now
        self.list = list
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var recurrence: TaskRecurrence {
        get { TaskRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            tagsRaw.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue.map { $0.lowercased() }.joined(separator: ",")
        }
    }

    var isOverdue: Bool {
        guard !isCompleted, let dueAt else { return false }
        return dueAt < Calendar.current.startOfDay(for: .now)
    }

    var appleCalendarEventIDs: [String: String] {
        get { CalendarEventIDMap.decode(appleCalendarEventIDsJSON, legacy: appleCalendarEventID, legacyCalendarID: PlannerPreferences.appleCalendarIdentifier) }
        set {
            appleCalendarEventIDsJSON = CalendarEventIDMap.encode(newValue)
            appleCalendarEventID = newValue.values.first
        }
    }

    var googleCalendarEventIDs: [String: String] {
        get {
            var map = CalendarEventIDMap.decode(googleCalendarEventIDsJSON, legacy: googleCalendarEventID, legacyCalendarID: PlannerPreferences.googleCalendarID)
            if map.isEmpty, let legacy = googleCalendarEventID, !legacy.isEmpty {
                map["primary"] = legacy
            }
            return map
        }
        set {
            googleCalendarEventIDsJSON = CalendarEventIDMap.encode(newValue)
            googleCalendarEventID = newValue.values.first
        }
    }
}

enum CalendarEventIDMap {
    static func decode(_ json: String, legacy: String?, legacyCalendarID: String?) -> [String: String] {
        var map = (try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))) ?? [:]
        if map.isEmpty, let legacy, !legacy.isEmpty, let calID = legacyCalendarID, !calID.isEmpty {
            map[calID] = legacy
        }
        return map
    }

    static func encode(_ map: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(map),
              let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }
}

@Model
final class HabitEntity {
    var id: UUID
    var name: String
    var icon: String
    var iconColorHex: String = "5BCB8A"
    var periodRaw: String
    var frequencyRaw: String = "daily"
    /// Bitmask for Calendar weekday (1=Sun … 7=Sat) → bit (weekday - 1).
    var weekdayMask: Int = 127
    var sortOrder: Int
    var createdAt: Date
    var reminderHour: Int
    var reminderMinute: Int
    var remindersEnabled: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \HabitLogEntity.habit)
    var logs: [HabitLogEntity]

    init(
        name: String,
        icon: String = "checkmark.circle.fill",
        iconColorHex: String = "5BCB8A",
        period: HabitPeriod = .morning,
        frequency: HabitFrequency = .daily,
        weekdayMask: Int = 127,
        reminderHour: Int = 8
    ) {
        id = UUID()
        self.name = name
        self.icon = icon
        self.iconColorHex = iconColorHex
        periodRaw = period.rawValue
        frequencyRaw = frequency.rawValue
        self.weekdayMask = weekdayMask
        sortOrder = 0
        createdAt = .now
        self.reminderHour = reminderHour
        reminderMinute = 0
        remindersEnabled = true
        logs = []
    }

    var period: HabitPeriod {
        get { HabitPeriod(rawValue: periodRaw) ?? .other }
        set { periodRaw = newValue.rawValue }
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    func isScheduled(on day: Date) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: day)
            return HabitWeekdayMask.contains(weekday, in: weekdayMask)
        }
    }

    func log(on day: Date) -> HabitLogEntity? {
        let start = Calendar.current.startOfDay(for: day)
        return logs.first { Calendar.current.isDate($0.day, inSameDayAs: start) }
    }

    func isDone(on day: Date) -> Bool {
        log(on: day)?.status == .done
    }

    func totalDoneCount() -> Int {
        logs.filter { $0.statusRaw == HabitLogStatus.done.rawValue }.count
    }
}

enum HabitLogStatus: String, Codable {
    case done
    case skipped
}

@Model
final class HabitLogEntity {
    var id: UUID
    var day: Date
    var statusRaw: String
    var habit: HabitEntity?

    init(day: Date, status: HabitLogStatus, habit: HabitEntity) {
        id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        statusRaw = status.rawValue
        self.habit = habit
    }

    var status: HabitLogStatus {
        get { HabitLogStatus(rawValue: statusRaw) ?? .done }
        set { statusRaw = newValue.rawValue }
    }
}

enum PlannerStore {
    static func isLegacyShoppingList(_ list: TaskListEntity) -> Bool {
        list.isSystem && list.name.lowercased() == "shopping"
    }

    static func seedIfNeeded(in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<TaskListEntity>())) ?? []
        if lists.isEmpty {
            context.insert(TaskListEntity(name: "Inbox", isSystem: true, sortOrder: 0, showInToday: true))
        }
        removeLegacyShoppingList(in: context)
        migrateLegacyEvents(in: context)
        let habits = (try? context.fetch(FetchDescriptor<HabitEntity>())) ?? []
        if habits.isEmpty {
            context.insert(HabitEntity(name: "Take Drugs + Brush", icon: "pills.fill", iconColorHex: "64B5F6", period: .morning, reminderHour: 7))
        }
        try? context.save()
    }

    /// Retired the separate Shopping task list — grocery shop lives under Meals.
    static func removeLegacyShoppingList(in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<TaskListEntity>())) ?? []
        guard let shopping = lists.first(where: isLegacyShoppingList) else { return }
        let inbox = lists.first { $0.name.lowercased() == "inbox" }
        for task in shopping.tasks {
            task.list = inbox
        }
        context.delete(shopping)
        try? context.save()
    }

    /// Events created before `isEvent` existed used explicit `colorHex` from the event sheet.
    static func migrateLegacyEvents(in context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        var changed = false
        for task in tasks where !task.isEvent && !task.colorHex.isEmpty {
            task.isEvent = true
            changed = true
        }
        if changed { try? context.save() }
    }

    static func inbox(in context: ModelContext) -> TaskListEntity? {
        let lists = (try? context.fetch(FetchDescriptor<TaskListEntity>())) ?? []
        return lists.first { $0.name == "Inbox" } ?? lists.first
    }

    @discardableResult
    static func ensureInbox(in context: ModelContext) -> TaskListEntity {
        if let inbox = inbox(in: context) { return inbox }
        let list = TaskListEntity(name: "Inbox", isSystem: true, sortOrder: 0, showInToday: true)
        context.insert(list)
        try? context.save()
        return list
    }

    static func visibleTaskLists(_ lists: [TaskListEntity]) -> [TaskListEntity] {
        lists.filter { !isLegacyShoppingList($0) }
    }

    static func addTask(
        title: String,
        due: Date?,
        priority: TaskPriority,
        list: TaskListEntity?,
        tags: [String] = [],
        reminderAt: Date? = nil,
        in context: ModelContext
    ) {
        let parsed = TaskTitleParser.parse(title)
        let finalTitle = parsed.cleanTitle.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : parsed.cleanTitle
        guard !finalTitle.isEmpty else { return }

        var resolvedList = list ?? inbox(in: context)
        let finalDue = parsed.dueDate ?? due
        var allTags = parsed.tags
        for tag in tags where !allTags.contains(tag.lowercased()) {
            allTags.append(tag.lowercased())
        }

        let task = PlannerTaskEntity(
            title: finalTitle,
            dueAt: finalDue,
            priority: priority,
            list: resolvedList
        )
        task.tags = allTags
        TagCatalog.ensureTags(allTags, in: context)
        task.reminderAt = reminderAt
        context.insert(task)
        try? context.save()
        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: context) }
        WidgetSnapshotWriter.publish(in: context)
    }

    static func addList(named name: String, showInToday: Bool = true, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lists = (try? context.fetch(FetchDescriptor<TaskListEntity>())) ?? []
        guard !lists.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        let order = (lists.map(\.sortOrder).max() ?? 0) + 1
        context.insert(TaskListEntity(name: trimmed, sortOrder: order, showInToday: showInToday))
        try? context.save()
    }

    static func list(named name: String, in context: ModelContext) -> TaskListEntity? {
        let lists = (try? context.fetch(FetchDescriptor<TaskListEntity>())) ?? []
        return lists.first { $0.name.lowercased() == name.lowercased() }
    }
}

enum PlannerDate {
    static func isInNext7Days(_ date: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        guard let end = cal.date(byAdding: .day, value: 8, to: start) else { return false }
        return date >= start && date < end
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func shortDue(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }
}
