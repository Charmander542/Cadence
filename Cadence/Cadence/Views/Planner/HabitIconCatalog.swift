import SwiftUI

struct HabitIconOption: Identifiable, Hashable {
    var id: String { symbol }
    var symbol: String
    var colorHex: String
}

enum HabitWeekdayMask {
    static let allDays = (1...7).reduce(0) { $0 | (1 << ($1 - 1)) }

    static func contains(_ weekday: Int, in mask: Int) -> Bool {
        guard (1...7).contains(weekday) else { return false }
        return mask & (1 << (weekday - 1)) != 0
    }

    static func toggle(_ weekday: Int, in mask: Int) -> Int {
        mask ^ (1 << (weekday - 1))
    }

    static func labels() -> [(weekday: Int, short: String)] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (1...7).map { weekday in
            (weekday, symbols[max(0, min(symbols.count - 1, weekday - 1))])
        }
    }
}

enum HabitIconCatalog {
    static let defaultColorHex = "5BCB8A"

    static let options: [HabitIconOption] = [
        HabitIconOption(symbol: "face.smiling.fill", colorHex: "F2D34A"),
        HabitIconOption(symbol: "drop.fill", colorHex: "5EB3FF"),
        HabitIconOption(symbol: "book.fill", colorHex: "C89BFF"),
        HabitIconOption(symbol: "figure.run", colorHex: "FF8A65"),
        HabitIconOption(symbol: "leaf.fill", colorHex: "5BCB8A"),
        HabitIconOption(symbol: "sun.max.fill", colorHex: "FFB020"),
        HabitIconOption(symbol: "cup.and.saucer.fill", colorHex: "A1887F"),
        HabitIconOption(symbol: "pills.fill", colorHex: "64B5F6"),
        HabitIconOption(symbol: "heart.fill", colorHex: "F06292"),
        HabitIconOption(symbol: "brain.head.profile", colorHex: "9575CD"),
        HabitIconOption(symbol: "bed.double.fill", colorHex: "7986CB"),
        HabitIconOption(symbol: "fork.knife", colorHex: "FF7043"),
        HabitIconOption(symbol: "carrot.fill", colorHex: "FFA726"),
        HabitIconOption(symbol: "figure.yoga", colorHex: "4DB6AC"),
        HabitIconOption(symbol: "pencil", colorHex: "90A4AE"),
        HabitIconOption(symbol: "moon.stars.fill", colorHex: "5C6BC0"),
        HabitIconOption(symbol: "dumbbell.fill", colorHex: "FF6B00"),
        HabitIconOption(symbol: "sparkles", colorHex: "FFD54F"),
        HabitIconOption(symbol: "pawprint.fill", colorHex: "8D6E63"),
        HabitIconOption(symbol: "music.note", colorHex: "EC407A"),
        HabitIconOption(symbol: "iphone.slash", colorHex: "78909C"),
    ]

    static func color(hex: String) -> Color {
        PlannerColor.from(hex: hex)
    }
}

struct HabitIconBadge: View {
    var symbol: String
    var colorHex: String
    var size: CGFloat = 40
    var selected: Bool = false
    var completed: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                (completed ? Theme.accent : HabitIconCatalog.color(hex: colorHex)),
                in: Circle()
            )
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(Theme.accent)
                    .background(Circle().fill(Theme.canvas))
                    .offset(x: 4, y: 4)
            }
        }
    }
}
