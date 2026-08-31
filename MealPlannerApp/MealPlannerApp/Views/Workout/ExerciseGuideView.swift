import SwiftUI

/// How-to sheet — opens when you tap the active exercise again in the carousel.
struct ExerciseGuideView: View {
    var exercise: WorkoutExerciseTemplate
    @Environment(\.dismiss) private var dismiss

    private var catalog: ExerciseCatalogEntry? {
        ExerciseCatalog.entry(for: exercise.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        heroImage
                        metaSectionContent
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(exerciseGuideHeroLabel)
                    instructionsSection
                    attribution
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                        .accessibilityHint("Closes exercise form guide")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var heroImage: some View {
        Group {
            if let catalog, catalog.image != nil {
                ExerciseCatalogThumbnail(
                    exercise: exercise,
                    selected: false,
                    heightRatio: 1.45,
                    fullWidth: true
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface)
                        .frame(height: 160)
                    Image(systemName: WorkoutVisuals.fallbackIcon(for: exercise))
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var metaSectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: exercise))
            if let catalog {
                HStack(spacing: 8) {
                    if !catalog.equipment.isEmpty {
                        metaPill(catalog.equipment.capitalized)
                    }
                    ForEach(catalog.primaryMuscles.prefix(3), id: \.self) { m in
                        metaPill(m.capitalized)
                    }
                }
            }
            Text(WorkoutVisuals.repRange(exercise))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private var exerciseGuideHeroLabel: String {
        "\(exercise.name). \(exerciseGuideMetaLabel)"
    }

    private var exerciseGuideMetaLabel: String {
        var parts = WorkoutVisuals.muscleTags(for: exercise)
        if let catalog {
            if !catalog.equipment.isEmpty {
                parts.insert(catalog.equipment.capitalized, at: 0)
            }
        }
        let tags = parts.isEmpty ? "Exercise details" : parts.joined(separator: ", ")
        return "\(tags). \(WorkoutVisuals.repRange(exercise))"
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to perform")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if let steps = catalog?.instructions, !steps.isEmpty {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent, in: Circle())
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(idx + 1), \(step)")
                }
            } else {
                Text("Keep a controlled tempo, full range of motion, and stop 1–2 reps before form breaks down.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var attribution: some View {
        Text("Exercise data from free-exercise-db (public domain).")
            .font(.caption2)
            .foregroundStyle(Theme.muted.opacity(0.7))
            .padding(.top, 8)
            .accessibilityAddTraits(.isStaticText)
    }

    private func metaPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.sunken, in: Capsule())
    }
}
