import SwiftUI

/// Per-workout detail from Apple Health / Watch (Bevel Fitness logger drill-down).
struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: HealthKitClient.WorkoutSummary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(workout.name)
                                .font(Theme.display(.title2))
                                .foregroundStyle(Theme.ink)
                            Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            Label(workout.source, systemImage: "applewatch")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.sm) {
                        metricCard("Duration", String(format: "%.0f min", workout.durationMinutes), "timer")
                        metricCard("Active energy", String(format: "%.0f kcal", workout.activeEnergyKcal), "flame.fill")
                        metricCard(
                            "Avg heart rate",
                            workout.averageHR.map { "\(Int($0.rounded())) bpm" } ?? "—",
                            "heart.fill"
                        )
                        metricCard("Source", workout.source, "link")
                    }

                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("WHAT THIS MEANS")
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.muted)
                            Text("This session came from Apple Health. Cadence folds its energy and duration into today’s Strain (active load). Open Lift for Cadence strength programming.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private func metricCard(_ title: String, _ value: String, _ icon: String) -> some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
