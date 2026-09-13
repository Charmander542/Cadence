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
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        heroImage
                        metaSectionContent
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(exerciseGuideHeroLabel)
                    instructionsSection
                    attribution
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.bottom, Theme.Space.xl + Theme.Space.md)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
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
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
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
        // Equinox+: muted-caps metadata labels + ink values.
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: exercise))
            if let catalog {
                if !catalog.equipment.isEmpty {
                    metaRow(label: "EQUIPMENT", value: catalog.equipment.capitalized)
                }
                if !catalog.primaryMuscles.isEmpty {
                    metaRow(
                        label: "TARGET",
                        value: catalog.primaryMuscles.prefix(3).map(\.capitalized).joined(separator: ", ")
                    )
                }
            }
            metaRow(label: "PRESCRIPTION", value: WorkoutVisuals.repRange(exercise))
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.lowercased()), \(value)")
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
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("HOW TO PERFORM")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            if let steps = catalog?.instructions, !steps.isEmpty {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: Theme.Space.md) {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Theme.cta, in: Circle())
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
            .padding(.top, Theme.Space.sm)
            .accessibilityAddTraits(.isStaticText)
    }
}
