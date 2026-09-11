import SwiftUI
import SwiftData

/// Garmin Edit Tabs × X Custom navigation — show/hide modules and reorder the dial.
struct AppsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity
    @StateObject private var appsModel = CadenceAppsModel()
    @State private var editMode: EditMode = .inactive
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                SettingsPageHero(
                    systemImage: "square.grid.2x2",
                    title: "Apps & wheel",
                    subtitle: "Choose what’s on the dial. Today stays pinned. Hold empty space in the swipe-up grid to edit and drag.",
                    tint: Theme.accent
                )
            }

            Section {
                ForEach(appsModel.orderedConfigurableVisible, id: \.rawValue) { dest in
                    appRow(dest, visible: true)
                }
                .onMove(perform: moveVisible)
                .onDelete(perform: hideVisible)
            } header: {
                settingsDetailSectionHeader("On the dial")
            } footer: {
                Text("Tap Edit to reorder. Minus or swipe removes from the dial (data is kept).")
                    .accessibilityAddTraits(.isStaticText)
            }

            if !appsModel.hiddenConfigurable.isEmpty {
                Section {
                    ForEach(appsModel.hiddenConfigurable, id: \.rawValue) { dest in
                        appRow(dest, visible: false)
                    }
                } header: {
                    settingsDetailSectionHeader("Available")
                }
            }

            Section {
                Button {
                    CadenceAppsPreferences.restoreDefaults()
                    profile.workoutsEnabled = true
                    Task { await PlannerSyncCoordinator.shared.refreshAll(in: modelContext) }
                    statusMessage = "Defaults restored."
                } label: {
                    Label("Restore defaults", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                }
                .accessibilityHint("Shows all apps on the dial in the default order")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Apps & wheel")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .foregroundStyle(Theme.cta)
            }
        }
        .environment(\.editMode, $editMode)
        .settingsFormChrome()
        .id(appsModel.revision)
    }

    @ViewBuilder
    private func appRow(_ dest: WheelDestination, visible: Bool) -> some View {
        let item = dest.navItem
        Button {
            setVisible(dest, !visible)
        } label: {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: visible ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(visible ? Color.red.opacity(0.9) : Theme.cta)
                    .accessibilityHidden(true)

                Theme.IconWell(systemImage: item.systemImage, tint: Theme.accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(CadenceAppsPreferences.blurb(for: dest))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Theme.MetaPill(text: visible ? "On dial" : "Add", tone: visible ? .accent : .cta)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(visible ? "Hide \(item.label)" : "Show \(item.label)")
        .accessibilityHint(CadenceAppsPreferences.blurb(for: dest))
        .disabled(editMode.isEditing && visible)
    }

    private func setVisible(_ dest: WheelDestination, _ on: Bool) {
        CadenceAppsPreferences.setVisible(dest, on)
        if dest == .workout {
            profile.workoutsEnabled = on
            Task { await PlannerSyncCoordinator.shared.refreshAll(in: modelContext) }
        }
        statusMessage = on ? "\(dest.navItem.label) added to dial." : "\(dest.navItem.label) hidden."
    }

    private func moveVisible(from source: IndexSet, to destination: Int) {
        CadenceAppsPreferences.reorderConfigurableVisible(from: source, to: destination)
        statusMessage = "Dial order updated."
    }

    private func hideVisible(at offsets: IndexSet) {
        let items = appsModel.orderedConfigurableVisible
        for index in offsets {
            guard items.indices.contains(index) else { continue }
            setVisible(items[index], false)
        }
    }
}

extension CadenceAppsModel {
    var orderedConfigurableVisible: [WheelDestination] {
        _ = revision
        return CadenceAppsPreferences.orderedConfigurableVisible
    }

    var hiddenConfigurable: [WheelDestination] {
        _ = revision
        return CadenceAppsPreferences.hiddenConfigurable
    }
}
