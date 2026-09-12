import Foundation
import SwiftData

enum FocusStore {
    static func recordCompleted(
        mode: FocusMode,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        label: String,
        in context: ModelContext
    ) {
        guard durationSeconds > 0 else { return }
        let session = FocusSessionEntity(
            mode: mode,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            label: label.isEmpty ? "Focus" : label,
            completed: true
        )
        context.insert(session)
        try? context.save()
    }

    static func delete(_ session: FocusSessionEntity, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    static func completed(_ sessions: [FocusSessionEntity]) -> [FocusSessionEntity] {
        sessions.filter(\.completed)
    }

    static func totalSeconds(in sessions: [FocusSessionEntity], day: Date = .now) -> Int {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions
            .filter { $0.completed && $0.startedAt >= start && $0.startedAt < end }
            .map(\.durationSeconds)
            .reduce(0, +)
    }

    static func pomoCount(in sessions: [FocusSessionEntity], day: Date = .now) -> Int {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions.filter {
            $0.completed && $0.mode == .pomo && $0.startedAt >= start && $0.startedAt < end
        }.count
    }

    static func sessions(in sessions: [FocusSessionEntity], day: Date) -> [FocusSessionEntity] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions.filter { $0.completed && $0.startedAt >= start && $0.startedAt < end }
    }

    /// Seconds by mode for a calendar day (for donut breakdown).
    static func modeBreakdown(in sessions: [FocusSessionEntity], day: Date) -> (pomo: Int, stopwatch: Int) {
        let daySessions = self.sessions(in: sessions, day: day)
        let pomo = daySessions.filter { $0.mode == .pomo }.map(\.durationSeconds).reduce(0, +)
        let stop = daySessions.filter { $0.mode == .stopwatch }.map(\.durationSeconds).reduce(0, +)
        return (pomo, stop)
    }

    /// Daily totals for `dayCount` days ending on `endDay` (inclusive), oldest first.
    static func dailyTotals(
        in sessions: [FocusSessionEntity],
        endingOn endDay: Date,
        dayCount: Int
    ) -> [(date: Date, seconds: Int)] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: endDay)
        return (0..<dayCount).compactMap { offset -> (Date, Int)? in
            let daysBack = dayCount - 1 - offset
            guard let day = cal.date(byAdding: .day, value: -daysBack, to: end) else { return nil }
            return (day, totalSeconds(in: sessions, day: day))
        }
    }

    /// Weekly totals for `weekCount` weeks ending the week of `anchor`, oldest first.
    static func weeklyTotals(
        in sessions: [FocusSessionEntity],
        endingNear anchor: Date,
        weekCount: Int
    ) -> [(weekStart: Date, seconds: Int)] {
        let cal = Calendar.current
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: anchor)?.start else { return [] }
        return (0..<weekCount).compactMap { offset -> (Date, Int)? in
            let weeksBack = weekCount - 1 - offset
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek),
                  let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)
            else { return nil }
            let secs = sessions
                .filter { $0.completed && $0.startedAt >= weekStart && $0.startedAt < weekEnd }
                .map(\.durationSeconds)
                .reduce(0, +)
            return (weekStart, secs)
        }
    }

    /// Mode breakdown for an inclusive day range `[start, endExclusive)`.
    static func modeBreakdown(
        in sessions: [FocusSessionEntity],
        from start: Date,
        to endExclusive: Date
    ) -> (pomo: Int, stopwatch: Int) {
        let slice = sessions.filter {
            $0.completed && $0.startedAt >= start && $0.startedAt < endExclusive
        }
        let pomo = slice.filter { $0.mode == .pomo }.map(\.durationSeconds).reduce(0, +)
        let stop = slice.filter { $0.mode == .stopwatch }.map(\.durationSeconds).reduce(0, +)
        return (pomo, stop)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// Compact duration for deltas / chart axes.
    static func formatDurationCompact(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0, m == 0 { return "\(h)h" }
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }

    static func formatClock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let r = s % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, r)
        }
        return String(format: "%02d:%02d", m, r)
    }
}
