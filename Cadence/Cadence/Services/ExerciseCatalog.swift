import Foundation
import SwiftUI
import UIKit

/// Exercise illustrations + how-to copy from [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (Unlicense).
struct ExerciseCatalogEntry: Codable, Hashable {
    var name: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var equipment: String
    var instructions: [String]
    /// Bundled JPEG filename in Resources/ExerciseImages, if any.
    var image: String?
    var sourceId: String
}

enum ExerciseCatalog {
    private static let entries: [String: ExerciseCatalogEntry] = load()

    static func entry(for exerciseID: String) -> ExerciseCatalogEntry? {
        entries[exerciseID]
    }

    static func image(for exercise: WorkoutExerciseTemplate) -> Image? {
        guard let file = entries[exercise.id]?.image,
              let url = Bundle.main.url(forResource: file.replacingOccurrences(of: ".jpg", with: ""),
                                        withExtension: "jpg",
                                        subdirectory: "ExerciseImages")
                ?? Bundle.main.url(forResource: file.replacingOccurrences(of: ".jpg", with: ""),
                                   withExtension: "jpg") else {
            return nil
        }
        return Image(uiImage: UIImage(contentsOfFile: url.path) ?? UIImage())
    }

    static func thumbnail(for exercise: WorkoutExerciseTemplate, selected: Bool = false) -> some View {
        ExerciseCatalogThumbnail(exercise: exercise, selected: selected)
    }

    private static func load() -> [String: ExerciseCatalogEntry] {
        guard let url = Bundle.main.url(forResource: "exercise_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: ExerciseCatalogEntry].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

struct ExerciseCatalogThumbnail: View {
    var exercise: WorkoutExerciseTemplate
    var selected: Bool
    /// Thumbnail width when `fullWidth` is false; height = width × heightRatio.
    var width: CGFloat = 56
    var heightRatio: CGFloat = 1.45
    /// Portrait image spanning the container width (Hevy-style hero).
    var fullWidth: Bool = false

    private var fixedHeight: CGFloat { width * heightRatio }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: fullWidth ? 14 : 10, style: .continuous)
        Group {
            if fullWidth {
                Color.clear
                    .aspectRatio(1 / heightRatio, contentMode: .fit)
                    .overlay { imageContent }
                    .clipped()
            } else {
                imageContent
                    .frame(width: width, height: fixedHeight)
                    .clipped()
            }
        }
        .background(Theme.sunken)
        .clipShape(shape)
        .contentShape(shape)
        .overlay(
            shape.stroke(selected ? Theme.accent : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .bottom) {
            if selected, !fullWidth {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: width * 0.6, height: 3)
                    .padding(.bottom, 5)
            }
        }
        .accessibilityLabel(exercise.name)
        .accessibilityAddTraits(selected ? [.isImage, .isSelected] : .isImage)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let ui = catalogUIImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                // Prevent scaledToFill from expanding the hit target past the frame.
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            Image(systemName: WorkoutVisuals.fallbackIcon(for: exercise))
                .font(fullWidth ? .largeTitle : .title3)
                .foregroundStyle(selected ? Theme.accent : Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var catalogUIImage: UIImage? {
        guard let file = ExerciseCatalog.entry(for: exercise.id)?.image else { return nil }
        let base = file.replacingOccurrences(of: ".jpg", with: "")
        if let url = Bundle.main.url(forResource: base, withExtension: "jpg", subdirectory: "ExerciseImages")
            ?? Bundle.main.url(forResource: base, withExtension: "jpg"),
           let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        return nil
    }
}
