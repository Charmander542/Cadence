import SwiftUI

enum WorkoutVisuals {
    static func fallbackIcon(for exercise: WorkoutExerciseTemplate) -> String {
        icon(for: exercise)
    }

    static func icon(for exercise: WorkoutExerciseTemplate) -> String {
        switch exercise.muscleGroup.lowercased() {
        case "chest": return "figure.strengthtraining.traditional"
        case "back", "lats": return "figure.rowing"
        case "shoulders": return "figure.arms.open"
        case "biceps", "triceps": return "figure.flexibility"
        case "quads", "hamstrings", "glutes", "calves", "adductors": return "figure.walk"
        case "abs": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }

    static func muscleTags(for exercise: WorkoutExerciseTemplate) -> [String] {
        var tags = [exercise.muscleGroup.capitalized]
        if exercise.perSide { tags.append("Unilateral") }
        return tags
    }

    static func estimatedMinutes(exerciseCount: Int) -> Int {
        max(25, exerciseCount * 8)
    }

    static func setLabel(index: Int, total: Int) -> String {
        index == 0 ? "F" : "\(index + 1)"
    }

    static func setLabel(for set: ActiveSetRow) -> String {
        WorkoutPrescription.setLabel(for: set)
    }

    static func repRange(_ ex: WorkoutExerciseTemplate) -> String {
        switch ex.progressionType {
        case .time:
            let lo = ex.durationMinSec ?? ex.repMin
            let hi = ex.durationMaxSec ?? ex.repMax
            return lo == hi ? "\(lo)s" : "\(lo)–\(hi)s"
        default:
            return ex.repMin == ex.repMax ? "\(ex.repMin)+ reps" : "\(ex.repMin)–\(ex.repMax) reps"
        }
    }
}

struct ExerciseThumbnail: View {
    var exercise: WorkoutExerciseTemplate
    var selected: Bool
    var width: CGFloat = 56
    var heightRatio: CGFloat = 1.45
    var fullWidth: Bool = false

    var body: some View {
        ExerciseCatalogThumbnail(
            exercise: exercise,
            selected: selected,
            width: width,
            heightRatio: heightRatio,
            fullWidth: fullWidth
        )
    }
}

struct MuscleTagRow: View {
    var tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.sunken, in: Capsule())
                }
            }
        }
    }
}

struct WorkoutInputField: View {
    var text: String
    var width: CGFloat = 72

    var body: some View {
        Text(text)
            .font(.body.monospacedDigit().weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: width, height: 36)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
