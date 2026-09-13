import Foundation

/// App Group payload for home/lock screen widgets.
struct WidgetTaskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueAt: Date?
    var isOverdue: Bool
}

struct WidgetHabitItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isDone: Bool
}

struct WidgetNextEvent: Codable, Hashable {
    var title: String
    var startAt: Date
}

/// Broken-down remaining time for countdown widgets (days / hours / minutes).
struct CountdownRemaining: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int

    var isZero: Bool { days == 0 && hours == 0 && minutes == 0 }

    static func until(_ end: Date, from start: Date = .now) -> CountdownRemaining? {
        guard end > start else { return nil }
        let comps = Calendar.current.dateComponents([.day, .hour, .minute], from: start, to: end)
        let days = max(0, comps.day ?? 0)
        let hours = max(0, comps.hour ?? 0)
        // Round up partial minutes so "1m left" doesn't show as 0m.
        var minutes = max(0, comps.minute ?? 0)
        let seconds = Calendar.current.dateComponents([.second], from: start, to: end).second ?? 0
        if seconds > 0 { minutes = max(minutes, 0) }
        // If under a minute but still future, show 1 minute.
        if days == 0, hours == 0, minutes == 0, end > start {
            minutes = 1
        }
        return CountdownRemaining(days: days, hours: hours, minutes: minutes)
    }

    /// e.g. "2d 5h 12m", "5h 12m", "12m"
    var compactLabel: String {
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

/// One Eisenhower quadrant summary for the Matrix widget.
struct WidgetMatrixTask: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
}

struct WidgetMatrixQuadrant: Codable, Identifiable, Hashable {
    var id: String
    var roman: String
    var title: String
    var count: Int
    var tasks: [WidgetMatrixTask]

    /// Legacy titles-only payload (pre task-id widgets).
    var taskTitles: [String] { tasks.map(\.title) }

    enum CodingKeys: String, CodingKey {
        case id, roman, title, count, tasks, taskTitles
    }

    init(id: String, roman: String, title: String, count: Int, tasks: [WidgetMatrixTask]) {
        self.id = id
        self.roman = roman
        self.title = title
        self.count = count
        self.tasks = tasks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        roman = try c.decode(String.self, forKey: .roman)
        title = try c.decode(String.self, forKey: .title)
        count = try c.decode(Int.self, forKey: .count)
        if let tasks = try c.decodeIfPresent([WidgetMatrixTask].self, forKey: .tasks) {
            self.tasks = tasks
        } else {
            let titles = try c.decodeIfPresent([String].self, forKey: .taskTitles) ?? []
            self.tasks = titles.map { WidgetMatrixTask(id: UUID(), title: $0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(roman, forKey: .roman)
        try c.encode(title, forKey: .title)
        try c.encode(count, forKey: .count)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(taskTitles, forKey: .taskTitles)
    }
}

/// Timed block on the large Calendar day-timeline widget (TickTick-style).
struct WidgetTimedEvent: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var startAt: Date
    var endAt: Date
    /// Cycles block color (0 purple, 1 blue, …).
    var tintIndex: Int
}

/// One day strip cell + agenda for the Calendar widget.
struct WidgetCalendarDay: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var weekdaySymbol: String
    var dayNumber: Int
    var isToday: Bool
    var eventTitles: [String]
    var openTaskCount: Int
    /// Timed events/tasks for the dual-column day timeline (usually populated for today).
    var timedEvents: [WidgetTimedEvent]

    enum CodingKeys: String, CodingKey {
        case id, date, weekdaySymbol, dayNumber, isToday
        case eventTitles, openTaskCount, timedEvents
    }

    init(
        id: String,
        date: Date,
        weekdaySymbol: String,
        dayNumber: Int,
        isToday: Bool,
        eventTitles: [String],
        openTaskCount: Int,
        timedEvents: [WidgetTimedEvent] = []
    ) {
        self.id = id
        self.date = date
        self.weekdaySymbol = weekdaySymbol
        self.dayNumber = dayNumber
        self.isToday = isToday
        self.eventTitles = eventTitles
        self.openTaskCount = openTaskCount
        self.timedEvents = timedEvents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        weekdaySymbol = try c.decode(String.self, forKey: .weekdaySymbol)
        dayNumber = try c.decode(Int.self, forKey: .dayNumber)
        isToday = try c.decode(Bool.self, forKey: .isToday)
        eventTitles = try c.decodeIfPresent([String].self, forKey: .eventTitles) ?? []
        openTaskCount = try c.decodeIfPresent(Int.self, forKey: .openTaskCount) ?? 0
        timedEvents = try c.decodeIfPresent([WidgetTimedEvent].self, forKey: .timedEvents) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(weekdaySymbol, forKey: .weekdaySymbol)
        try c.encode(dayNumber, forKey: .dayNumber)
        try c.encode(isToday, forKey: .isToday)
        try c.encode(eventTitles, forKey: .eventTitles)
        try c.encode(openTaskCount, forKey: .openTaskCount)
        try c.encode(timedEvents, forKey: .timedEvents)
    }
}

struct WidgetSnapshot: Codable {
    var updatedAt: Date
    var tasks: [WidgetTaskItem]
    var habits: [WidgetHabitItem]
    var nextEvent: WidgetNextEvent?
    var pendingTaskToggles: [UUID]
    var pendingHabitToggles: [UUID]
    /// Eisenhower quadrant summaries (open tasks only).
    var matrixQuadrants: [WidgetMatrixQuadrant]
    /// Next several calendar days (today → +6).
    var calendarDays: [WidgetCalendarDay]

    static let empty = WidgetSnapshot(
        updatedAt: .now,
        tasks: [],
        habits: [],
        nextEvent: nil,
        pendingTaskToggles: [],
        pendingHabitToggles: [],
        matrixQuadrants: WidgetSnapshot.placeholderMatrix,
        calendarDays: []
    )

    static let placeholderMatrix: [WidgetMatrixQuadrant] = [
        .init(id: "urgentImportant", roman: "I", title: "Urgent & Important", count: 0, tasks: []),
        .init(id: "notUrgentImportant", roman: "II", title: "Not Urgent & Important", count: 0, tasks: []),
        .init(id: "urgentUnimportant", roman: "III", title: "Urgent & Unimportant", count: 0, tasks: []),
        .init(id: "notUrgentUnimportant", roman: "IV", title: "Not Urgent & Unimportant", count: 0, tasks: []),
    ]

    enum CodingKeys: String, CodingKey {
        case updatedAt, tasks, habits, nextEvent
        case pendingTaskToggles, pendingHabitToggles
        case matrixQuadrants, calendarDays
    }

    init(
        updatedAt: Date,
        tasks: [WidgetTaskItem],
        habits: [WidgetHabitItem],
        nextEvent: WidgetNextEvent?,
        pendingTaskToggles: [UUID],
        pendingHabitToggles: [UUID],
        matrixQuadrants: [WidgetMatrixQuadrant],
        calendarDays: [WidgetCalendarDay]
    ) {
        self.updatedAt = updatedAt
        self.tasks = tasks
        self.habits = habits
        self.nextEvent = nextEvent
        self.pendingTaskToggles = pendingTaskToggles
        self.pendingHabitToggles = pendingHabitToggles
        self.matrixQuadrants = matrixQuadrants
        self.calendarDays = calendarDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        tasks = try c.decodeIfPresent([WidgetTaskItem].self, forKey: .tasks) ?? []
        habits = try c.decodeIfPresent([WidgetHabitItem].self, forKey: .habits) ?? []
        nextEvent = try c.decodeIfPresent(WidgetNextEvent.self, forKey: .nextEvent)
        pendingTaskToggles = try c.decodeIfPresent([UUID].self, forKey: .pendingTaskToggles) ?? []
        pendingHabitToggles = try c.decodeIfPresent([UUID].self, forKey: .pendingHabitToggles) ?? []
        matrixQuadrants = try c.decodeIfPresent([WidgetMatrixQuadrant].self, forKey: .matrixQuadrants)
            ?? WidgetSnapshot.placeholderMatrix
        calendarDays = try c.decodeIfPresent([WidgetCalendarDay].self, forKey: .calendarDays) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(habits, forKey: .habits)
        try c.encodeIfPresent(nextEvent, forKey: .nextEvent)
        try c.encode(pendingTaskToggles, forKey: .pendingTaskToggles)
        try c.encode(pendingHabitToggles, forKey: .pendingHabitToggles)
        try c.encode(matrixQuadrants, forKey: .matrixQuadrants)
        try c.encode(calendarDays, forKey: .calendarDays)
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.musclemeal.app"
    private static let snapshotKey = "widget_snapshot_v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return decoded
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    static func queueTaskToggle(_ id: UUID) {
        var snap = load()
        if !snap.pendingTaskToggles.contains(id) {
            snap.pendingTaskToggles.append(id)
        }
        save(snap)
    }

    static func queueHabitToggle(_ id: UUID) {
        var snap = load()
        if !snap.pendingHabitToggles.contains(id) {
            snap.pendingHabitToggles.append(id)
        }
        save(snap)
    }

    static func consumePendingToggles() -> (tasks: [UUID], habits: [UUID]) {
        var snap = load()
        let tasks = snap.pendingTaskToggles
        let habits = snap.pendingHabitToggles
        snap.pendingTaskToggles = []
        snap.pendingHabitToggles = []
        save(snap)
        return (tasks, habits)
    }
}
