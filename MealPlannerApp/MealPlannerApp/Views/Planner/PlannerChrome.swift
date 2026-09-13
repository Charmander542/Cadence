import SwiftUI
import SwiftData
import UIKit

struct PlannerTabChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Theme.canvas, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct AppGridExpandedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isAppGridExpanded: Bool {
        get { self[AppGridExpandedKey.self] }
        set { self[AppGridExpandedKey.self] = newValue }
    }
}

enum PlannerChromeMetrics {
    /// Reserved bottom inset so page layout stays put while the dial draws larger on top.
    static let dialLayoutHeight: CGFloat = 102
    static let dialFABTrailingPadding: CGFloat = 22
    /// Gap above the dial inset so + sits clearly clear of the wheel icons.
    static let dialFABBottomPadding: CGFloat = 28
    /// Extra scroll clearance under page lists so last rows clear the + above the dial.
    static var dialFABClearance: CGFloat { dialLayoutHeight + dialFABBottomPadding + 58 + 16 }
}

enum FABAction: Equatable {
    case todayQuickAdd
    case matrixQuickAdd
    case addEvent
    case addHabit
    case addSpendItem

    var accessibilityLabel: String {
        switch self {
        case .todayQuickAdd, .matrixQuickAdd: return "Add task"
        case .addEvent: return "Add event"
        case .addHabit: return "Add habit"
        case .addSpendItem: return "Add purchase"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .todayQuickAdd, .matrixQuickAdd: return "Opens quick add"
        case .addEvent: return "Opens new calendar event"
        case .addHabit: return "Opens new habit form"
        case .addSpendItem: return "Opens new purchase form"
        }
    }
}

/// Leading undo chip above the dial inset (optional helper).
struct DialUndoBar<Leading: View>: View {
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        leading()
            .padding(.leading, 22)
            .padding(.bottom, PlannerChromeMetrics.dialFABBottomPadding)
    }
}

extension View {
    /// Undo chip only — bottom-leading, no full-width plate over the dial.
    func dialUndoChrome<Leading: View>(
        @ViewBuilder leading: @escaping () -> Leading
    ) -> some View {
        overlay(alignment: .bottomLeading) {
            leading()
                .padding(.leading, 22)
                .padding(.bottom, PlannerChromeMetrics.dialFABBottomPadding)
        }
    }

    /// Pages keep undo via leading; trailing + is hosted above the dial in RootView.
    func dialFABChrome<Leading: View, FAB: View>(
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder fab: @escaping () -> FAB
    ) -> some View {
        dialUndoChrome(leading: leading)
    }

    func dialFABChrome<FAB: View>(
        @ViewBuilder fab: @escaping () -> FAB
    ) -> some View {
        self
    }
}

/// Compact create control above the dial — plus only, one tap → sheet.
/// Refs: [Todoist](https://mobbin.com/screens/1ae63b10-6840-42ec-838a-0117cb219e99),
/// [Structured](https://mobbin.com/screens/2945ca91-3537-4a3c-82c5-0901c16a3af1)
/// (no speed-dial fan-out).
struct CreateFAB: View {
    var accessibilityLabel: String = "Add task"
    var accessibilityHint: String = "Opens quick add"
    var action: () -> Void
    @Environment(\.isAppGridExpanded) private var isAppGridExpanded

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.cta, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Theme.cta.opacity(0.35), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(FABPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .opacity(isAppGridExpanded ? 0 : 1)
        .allowsHitTesting(!isAppGridExpanded)
        .accessibilityHidden(isAppGridExpanded)
        .animation(.easeOut(duration: 0.18), value: isAppGridExpanded)
    }
}

/// Legacy name — dial create control is CTA blue, not orange.
typealias OrangeFAB = CreateFAB

/// Light press feedback only — no expand / fan-out motion.
private struct FABPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct UndoFAB: View {
    var label: String = "UNDO"
    var accessibilityHint: String = "Restores the last completed task"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm - 2) {
                Image(systemName: "arrow.uturn.backward")
                Text(label)
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, Theme.Space.lg)
            .frame(height: 52)
            .background(Theme.flagMedium, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
    }
}

struct PlannerDrawer: View {
    var lists: [TaskListEntity]
    var destination: PlannerDestination
    var onSelect: (PlannerDestination) -> Void
    var onSettings: () -> Void
    var onClose: () -> Void
    var onAddList: (String) -> Void
    var onManageTags: () -> Void
    var onSearch: () -> Void
    /// While edge-swiping open: panel x reveal in points (0…panelWidth). `nil` = settled open.
    var interactiveOpenX: CGFloat? = nil

    @State private var showNewList = false
    @State private var newListName = ""
    @State private var editingList: TaskListEntity?
    /// Interactive swipe-to-close offset (0 = open, negative = dragging shut).
    @State private var closeDragX: CGFloat = 0
    @State private var isClosing = false

    private let panelWidth: CGFloat = 300
    private let closeThreshold: CGFloat = 90

    private var isInteractiveOpening: Bool { interactiveOpenX != nil }

    private var navigableLists: [TaskListEntity] {
        lists.filter {
            $0.name.lowercased() != "inbox" && !PlannerStore.isLegacyShoppingList($0)
        }
    }

    private var panelOffset: CGFloat {
        if let x = interactiveOpenX {
            return -panelWidth + min(panelWidth, max(0, x))
        }
        return closeDragX
    }

    private var scrimOpacity: Double {
        if let x = interactiveOpenX {
            return 0.55 * Double(min(1, max(0, x / panelWidth)))
        }
        let progress = 1 - min(1, max(0, -closeDragX / panelWidth))
        return 0.55 * Double(progress)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(scrimOpacity)
                .ignoresSafeArea()
                .onTapGesture { closeInteractively() }
                .allowsHitTesting(!isInteractiveOpening)
                .accessibilityLabel("Dismiss sidebar")
                .accessibilityAddTraits(.isButton)

            panel
                .offset(x: panelOffset)
                .simultaneousGesture(closeDragGesture)
                .accessibilityElement(children: .contain)
        }
        .alert("New list", isPresented: $showNewList) {
            TextField("List name", text: $newListName)
            Button("Create") {
                onAddList(newListName)
                newListName = ""
            }
            .accessibilityHint("Creates custom task list with entered name")
            Button("Cancel", role: .cancel) { newListName = "" }
                .accessibilityHint("Discards new list")
        } message: {
            Text("Custom lists organize tasks outside Today and Matrix defaults.")
                .accessibilityAddTraits(.isStaticText)
        }
        .sheet(item: $editingList) { list in
            ListSettingsSheet(list: list)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Sidebar")
                        .font(Theme.title(.title3))
                    Spacer()
                    Button {
                        closeInteractively()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Close sidebar")
                    .accessibilityHint("Closes the sidebar")
                }
                .padding(.horizontal, Theme.Space.lg + 2)
                .padding(.top, Theme.Space.lg + 2)
                .padding(.bottom, Theme.Space.md)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        drawerSectionHeader("Views")
                        drawerRow("Today", icon: "sun.max", dest: .today, hint: "Shows today’s tasks and habits")
                        drawerRow("Next 7 Days", icon: "calendar", dest: .next7, hint: "Shows tasks due in the next week")
                        drawerRow("Inbox", icon: "tray", dest: .inbox, hint: "Shows tasks without a due date")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, Theme.Space.sm)
                        drawerSectionHeader("Lists")
                        ForEach(navigableLists) { list in
                            listDrawerRow(list)
                        }
                        Button {
                            showNewList = true
                        } label: {
                            Label("NEW LIST", systemImage: "plus.circle")
                                .font(.caption.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.cta)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.sm + 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Creates a custom task list")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, Theme.Space.sm)
                        drawerSectionHeader("More")
                        if CadenceAppsPreferences.isVisible(.shop) {
                            drawerRow("Shop", icon: "basket", dest: .shop, hint: "Opens grocery shop list on Meals tab")
                        }
                        Button(action: onManageTags) {
                            Label("MANAGE TAGS", systemImage: "number")
                                .font(.caption.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.cta)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.sm + 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit task tag names and colors")
                    }
                    .padding(.horizontal, Theme.Space.sm + 2)
                }

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    Divider().overlay(Theme.gridDivider)
                    Button(action: onSearch) {
                        HStack(spacing: Theme.Space.md) {
                            Theme.IconWell(systemImage: "magnifyingglass", tint: Theme.cta, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Search")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("Tasks, habits, events, recipes, shop, and settings")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                                    .accessibilityAddTraits(.isStaticText)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, Theme.Space.md + 2)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .padding(.horizontal, Theme.Space.sm + 2)
                        .padding(.vertical, Theme.Space.sm - 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search. Tasks, habits, events, recipes, shop, and settings")
                    .accessibilityHint("Search tasks, habits, events, recipes, shop items, and settings")
                    .accessibilityIdentifier("global-search-drawer")
                    Divider().overlay(Theme.gridDivider)
                    Button(action: onSettings) {
                        HStack(spacing: Theme.Space.md) {
                            Theme.IconWell(systemImage: "gearshape", tint: Theme.cta, size: 32)
                            Text("Settings")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, Theme.Space.md + 2)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .padding(.horizontal, Theme.Space.sm + 2)
                        .padding(.vertical, Theme.Space.sm - 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings")
                }
            }
            .frame(width: panelWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Theme.surface)
            .overlay(alignment: .trailing) {
                // Grabber strip for swipe-to-close.
                ZStack(alignment: .trailing) {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1)
                    Capsule()
                        .fill(Theme.muted.opacity(0.35))
                        .frame(width: 4, height: 36)
                        .padding(.trailing, 6)
                        .accessibilityHidden(true)
                }
                .frame(width: 28, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(closeDragGesture)
                .accessibilityLabel("Sidebar edge")
                .accessibilityHint("Swipe left to close the sidebar")
            }
    }

    private var closeDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !isInteractiveOpening, !isClosing else { return }
                // Prefer horizontal dismiss; ignore mostly-vertical scrolls in the list.
                guard abs(value.translation.width) > abs(value.translation.height) * 0.65 else { return }
                // Only left (close). Don’t rubber-band past the open position.
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    closeDragX = min(0, value.translation.width)
                }
            }
            .onEnded { value in
                guard !isInteractiveOpening, !isClosing else { return }
                let shouldClose = value.translation.width < -closeThreshold
                    || value.predictedEndTranslation.width < -closeThreshold * 1.35
                if shouldClose {
                    closeInteractively(fromDrag: true)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        closeDragX = 0
                    }
                }
            }
    }

    /// Slide the panel fully off-screen, then remove it without a second `.move` transition
    /// (resetting `closeDragX` under RootView’s removal animation caused ghost panels).
    private func closeInteractively(fromDrag: Bool = false) {
        guard !isClosing else { return }
        isClosing = true
        let offscreen = -panelWidth - 24
        let duration: TimeInterval = fromDrag ? 0.18 : 0.22
        withAnimation(.easeOut(duration: duration)) {
            closeDragX = offscreen
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                closeDragX = 0
                isClosing = false
                onClose()
            }
        }
    }

    private func drawerSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .textCase(nil)
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.sm - 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func listDrawerRow(_ list: TaskListEntity) -> some View {
        let selected = destination == .list(list.id)
        return HStack(spacing: 0) {
            Button {
                onSelect(.list(list.id))
            } label: {
                HStack {
                    Theme.IconWell(
                        systemImage: "list.bullet",
                        tint: selected ? Theme.accent : Theme.muted,
                        size: 28
                    )
                    Text(list.name)
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.accent : Theme.ink)
                    Spacer()
                    if list.showInToday {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(selected ? Theme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "\(list.name) list, selected" : "\(list.name) list")
            .accessibilityHint("Opens this task list")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            Button {
                editingList = list
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("List settings for \(list.name)")
            .accessibilityHint("Edit list name and Today visibility")
        }
    }

    private func drawerRow(_ title: String, icon: String, dest: PlannerDestination, hint: String) -> some View {
        let selected = dest == destination
        return Button {
            onSelect(dest)
        } label: {
            // Superlist/Fabric: accent “where you are” + trailing chevron when selected.
            HStack(spacing: Theme.Space.md) {
                Theme.IconWell(
                    systemImage: icon,
                    tint: selected ? Theme.accent : Theme.muted,
                    size: 32
                )
                Text(title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.accent : Theme.ink)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Space.sm + 2)
            .padding(.vertical, Theme.Space.sm)
            .background(selected ? Theme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.28) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "\(title), selected" : title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct SettingsGearButton: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Button {
            appModel.showSettingsSheet = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens app settings")
    }
}

struct GlobalSearchButton: View {
    @EnvironmentObject private var appModel: AppModel
    var prominent = false

    var body: some View {
        Button {
            appModel.showGlobalSearchSheet = true
        } label: {
            Group {
                if prominent {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                        .padding(.horizontal, Theme.Space.sm + 2)
                        .padding(.vertical, Theme.Space.sm - 2)
                        .background(Theme.surface, in: Capsule())
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityHint("Search tasks, habits, events, recipes, and shop items")
        .accessibilityIdentifier(prominent ? "global-search-prominent" : "global-search-button")
        .accessibilityAddTraits(.isButton)
    }
}

struct PlannerHeaderActions: View {
    var showSearch = true

    var body: some View {
        HStack(spacing: 4) {
            if showSearch {
                GlobalSearchButton()
            }
            SettingsGearButton()
        }
    }
}

/// Opens the planner sidebar (Today, Inbox, custom lists, search, settings).
struct PlannerMenuButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open sidebar")
        .accessibilityHint("Opens the sidebar with lists, search, shop, and settings")
    }
}

/// Large-title header with optional trailing toolbar (Meals, Calendar scope picker).
/// Content-first tabs without header actions use `PlannerTitleHeader` instead.
struct PlannerScreenHeader<Trailing: View>: View {
    let title: String
    var onMenu: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, onMenu: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.onMenu = onMenu
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onMenu {
                PlannerMenuButton(action: onMenu)
            }
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            trailing()
                .layoutPriority(1)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.sm + 2)
        .padding(.bottom, Theme.Space.xs)
    }
}

extension PlannerScreenHeader where Trailing == EmptyView {
    init(title: String, onMenu: (() -> Void)? = nil) {
        self.title = title
        self.onMenu = onMenu
        self.trailing = { EmptyView() }
    }
}

/// Title-only header for content-first tabs (Matrix, Habits).
/// Tabs with actions (Meals, Calendar) use `PlannerScreenHeader` with a trailing toolbar instead.
struct PlannerTitleHeader: View {
    let title: String
    var onMenu: (() -> Void)?

    init(title: String, onMenu: (() -> Void)? = nil) {
        self.title = title
        self.onMenu = onMenu
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onMenu {
                PlannerMenuButton(action: onMenu)
            }
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.sm + 2)
        .padding(.bottom, Theme.Space.xs)
    }
}

struct PlannerTopBar: View {
    var title: String
    var onMenu: () -> Void
    /// When false, search is omitted from the top bar (e.g. Today uses a prominent pill below the title).
    var showSearchInBar = true
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            PlannerMenuButton(action: onMenu)
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let trailing {
                trailing()
            } else if showSearchInBar {
                GlobalSearchButton()
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.xs)
        .padding(.bottom, Theme.Space.xs)
    }
}

struct TaskCheckbox: View {
    var completed: Bool
    var overdue: Bool
    var action: () -> Void

    private let size: CGFloat = 24

    @State private var fillScale: CGFloat = 0
    @State private var checkScale: CGFloat = 0.2
    @State private var checkOpacity: Double = 0
    @State private var burstScale: CGFloat = 0.75
    @State private var burstOpacity: Double = 0
    @State private var pressScale: CGFloat = 1
    @State private var showsFilled = false

    private var ringColor: Color {
        showsFilled ? Theme.accent : (overdue ? Theme.danger : Theme.muted.opacity(0.45))
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                pressScale = 0.86
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                    pressScale = 1
                }
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(burstOpacity), lineWidth: 2.5)
                    .frame(width: size, height: size)
                    .scaleEffect(burstScale)

                Circle()
                    .stroke(ringColor, lineWidth: 1.8)
                    .frame(width: size, height: size)

                if showsFilled {
                    Circle()
                        .fill(Theme.accent.gradient)
                        .frame(width: size, height: size)
                        .scaleEffect(fillScale)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 4, y: 1)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(checkScale)
                        .opacity(checkOpacity)
                        .rotationEffect(.degrees(checkScale < 1 ? -14 : 0))
                }
            }
            .frame(width: size + 6, height: size + 6)
            .scaleEffect(pressScale)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: showsFilled)
        .onAppear { applyCompletedState(completed, animated: false) }
        .onChange(of: completed) { _, new in
            if new && !showsFilled {
                playCompleteAnimation()
            } else if !new && showsFilled {
                playUncheckAnimation()
            }
        }
        .accessibilityLabel(completed ? "Mark incomplete" : (overdue ? "Mark complete, overdue task" : "Mark complete"))
        .accessibilityHint(completed ? "Reopens task" : "Marks task complete")
        .accessibilityAddTraits(.isButton)
    }

    private func applyCompletedState(_ isCompleted: Bool, animated: Bool) {
        if isCompleted {
            if animated { playCompleteAnimation() }
            else { setCompletedVisuals(active: true) }
        } else {
            if animated { playUncheckAnimation() }
            else { setCompletedVisuals(active: false) }
        }
    }

    private func playCompleteAnimation() {
        guard !showsFilled else { return }
        showsFilled = true
        fillScale = 0.15
        checkScale = 0.15
        checkOpacity = 0
        burstScale = 0.75
        burstOpacity = 0.7

        withAnimation(.spring(response: 0.32, dampingFraction: 0.56)) {
            fillScale = 1.08
            checkScale = 1.18
            checkOpacity = 1
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74).delay(0.05)) {
            fillScale = 1
            checkScale = 1
        }
        withAnimation(.easeOut(duration: 0.42)) {
            burstScale = 2.1
            burstOpacity = 0
        }
    }

    private func playUncheckAnimation() {
        guard showsFilled else { return }
        burstOpacity = 0
        withAnimation(.easeIn(duration: 0.14)) {
            fillScale = 0.2
            checkScale = 0.2
            checkOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            showsFilled = false
            setCompletedVisuals(active: false)
        }
    }

    private func setCompletedVisuals(active: Bool) {
        showsFilled = active
        fillScale = active ? 1 : 0
        checkScale = active ? 1 : 0.2
        checkOpacity = active ? 1 : 0
        burstOpacity = 0
        burstScale = 0.75
    }
}

enum TabBarAppearance {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .black : .systemBackground
        }
        let orange = UIColor(named: "AccentColor") ?? UIColor(red: 1, green: 0.42, blue: 0, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = orange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: orange]
        let unselected = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.45)
                : .secondaryLabel
        }
        appearance.stackedLayoutAppearance.normal.iconColor = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = unselected
    }
}

struct CountdownTrackButton: View {
    @Environment(\.modelContext) private var modelContext
    let eventID: UUID
    @State private var trackedRevision = 0

    private var isTracked: Bool {
        _ = trackedRevision
        return CountdownTracking.isTracked(eventID)
    }

    var body: some View {
        Button {
            CountdownTracking.toggle(eventID, in: modelContext)
        } label: {
            Image(systemName: isTracked ? "star.fill" : "star")
                .font(.body.weight(.semibold))
                .foregroundStyle(isTracked ? Theme.accent : Theme.muted.opacity(0.55))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(isTracked ? Theme.accent.opacity(0.14) : Theme.sunken.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTracked ? "Countdown tracked" : "Track countdown")
        .accessibilityHint(
            isTracked
                ? "Removes this event from the countdown widget"
                : "Shows this event on the countdown widget. Only one event can be tracked."
        )
        .onReceive(NotificationCenter.default.publisher(for: .countdownTrackingDidChange)) { _ in
            trackedRevision += 1
        }
    }
}

struct GlobalSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \PlannerTaskEntity.title) private var tasks: [PlannerTaskEntity]
    @Query(sort: \HabitEntity.name) private var habits: [HabitEntity]
    @Query(sort: \GroceryItemEntity.sortOrder) private var groceryItems: [GroceryItemEntity]

    @State private var query = ""
    @State private var searchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var editingTask: PlannerTaskEntity?
    @State private var editingHabit: HabitEntity?
    @State private var editingEvent: EventSheetContext?
    @FocusState private var searchFieldFocused: Bool
    @State private var searchRecents: [String] = PlannerPreferences.searchRecents()

    private let searchDebounceMs = 350

    private func searchSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    private var tokens: [String] {
        searchQuery.lowercased().split(separator: " ").map(String.init).filter { $0.count > 1 }
    }

    private var matchingTasks: [PlannerTaskEntity] {
        guard !tokens.isEmpty else { return [] }
        return tasks.filter { task in
            let hay = task.title.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .filter { !$0.isEvent }
        .prefix(20)
        .map { $0 }
    }

    private var matchingEvents: [PlannerTaskEntity] {
        guard !tokens.isEmpty else { return [] }
        return tasks.filter { task in
            guard task.isEvent else { return false }
            let hay = task.title.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        .prefix(20)
        .map { $0 }
    }

    private var matchingHabits: [HabitEntity] {
        guard !tokens.isEmpty else { return [] }
        return habits.filter { habit in
            let hay = habit.name.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .prefix(20)
        .map { $0 }
    }

    private var matchingRecipes: [Recipe] {
        guard !tokens.isEmpty else { return [] }
        return appModel.recipeDB.search(searchQuery, limit: 20)
    }

    private var matchingGroceries: [GroceryItemEntity] {
        guard !tokens.isEmpty else { return [] }
        return groceryItems.filter { item in
            let hay = item.ingredientName.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .prefix(20)
        .map { $0 }
    }

    private var matchingSettings: [SettingsSearchMatch] {
        SettingsSearchMatch.matches(query: searchQuery)
    }

    private var isSearching: Bool {
        query.trimmingCharacters(in: .whitespaces) != searchQuery.trimmingCharacters(in: .whitespaces)
    }

    private var hasAnyResults: Bool {
        !matchingTasks.isEmpty
            || !matchingEvents.isEmpty
            || !matchingHabits.isEmpty
            || !matchingRecipes.isEmpty
            || !matchingGroceries.isEmpty
            || !matchingSettings.isEmpty
    }

    private func recipeDisplayName(_ name: String) -> String {
        Theme.recipeDisplayName(name)
    }

    private func globalSearchTaskLabel(_ task: PlannerTaskEntity) -> String {
        if let due = task.dueAt {
            return "\(task.title), due \(PlannerDate.shortDue(due))"
        }
        return task.title
    }

    private func globalSearchEventLabel(_ event: PlannerTaskEntity) -> String {
        if let due = event.dueAt {
            return "\(event.title), event, \(PlannerDate.shortDue(due))"
        }
        return "\(event.title), event"
    }

    private func globalSearchRecipeLabel(_ recipe: Recipe) -> String {
        var parts = [
            recipeDisplayName(recipe.name),
            recipe.course.isEmpty ? "recipe" : recipe.course
        ]
        if !recipe.sourceCitation.isEmpty {
            parts.append(recipe.sourceCitation)
        }
        if recipe.webLink != nil {
            parts.append("web link available")
        }
        return parts.joined(separator: ", ")
    }

    private func globalSearchGroceryLabel(_ item: GroceryItemEntity) -> String {
        let checked = item.isChecked ? "checked off" : "not checked"
        return "\(item.ingredientName), \(item.category), \(checked)"
    }

    private func globalSearchSettingsLabel(_ match: SettingsSearchMatch) -> String {
        "\(match.title), settings, \(match.subtitle)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Theme.Space.sm + 2) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.muted)
                        TextField("Search tasks, habits, events, recipes, shop, and settings…", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($searchFieldFocused)
                            .accessibilityIdentifier("global-search-field")
                            .accessibilityHint("Search across tasks, habits, events, recipes, shop items, and settings")
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.sm + 2)
                    .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: Theme.Space.sm, leading: Theme.Space.lg, bottom: Theme.Space.sm, trailing: Theme.Space.lg))
                    .listRowBackground(Color.clear)
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchEmptyState
                } else if isSearching {
                    HStack(spacing: Theme.Space.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching…")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Searching")
                } else if !hasAnyResults {
                    // Revolut/Meta: clear recovery CTA for empty search.
                    VStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "magnifyingglass", tint: Theme.muted, size: 48)
                        Text("NO RESULTS")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                        Text("No results found")
                            .font(Theme.display(.headline))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("No matches for “\(searchQuery)”. Try another term.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        Button {
                            query = ""
                            searchQuery = ""
                            searchFieldFocused = true
                        } label: {
                            Text("CLEAR SEARCH")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, Theme.Space.lg)
                                .padding(.vertical, Theme.Space.sm + 2)
                                .background(Theme.cta, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clears the search field")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.xl + Theme.Space.sm)
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("No results for \(searchQuery)")
                } else {
                    if !matchingTasks.isEmpty {
                        Section {
                            ForEach(matchingTasks) { task in
                                Button {
                                    editingTask = task
                                } label: {
                                    HStack(spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "checkmark.circle", tint: Theme.cta, size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .foregroundStyle(Theme.ink)
                                            if let due = task.dueAt {
                                                Theme.MetaPill(
                                                    text: PlannerDate.shortDue(due),
                                                    tone: task.isOverdue ? .danger : .neutral
                                                )
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, Theme.Space.xs)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchTaskLabel(task))
                                .accessibilityHint("Opens task editor")
                            }
                        } header: {
                            searchSectionHeader("Tasks")
                        }
                    }
                    if !matchingEvents.isEmpty {
                        Section {
                            ForEach(matchingEvents) { event in
                                HStack(spacing: 0) {
                                    CountdownTrackButton(eventID: event.id)
                                    Button {
                                        editingEvent = EventSheetContext(task: event, startDate: event.dueAt ?? .now)
                                    } label: {
                                        HStack(spacing: Theme.Space.md) {
                                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                                .fill(PlannerColor.from(hex: event.colorHex.isEmpty ? PlannerColor.palette[0] : event.colorHex))
                                                .frame(width: 3, height: 32)
                                            Theme.IconWell(systemImage: "calendar", tint: Theme.accent, size: 32)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                    .foregroundStyle(Theme.ink)
                                                if let due = event.dueAt {
                                                    Theme.MetaPill(text: PlannerDate.shortDue(due), tone: .neutral)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, Theme.Space.xs)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(globalSearchEventLabel(event))
                                    .accessibilityHint("Opens event editor")
                                }
                            }
                        } header: {
                            searchSectionHeader("Events")
                        }
                    }
                    if !matchingHabits.isEmpty {
                        Section {
                            ForEach(matchingHabits) { habit in
                                Button {
                                    editingHabit = habit
                                } label: {
                                    HStack(spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "repeat", tint: Theme.accent, size: 32)
                                        Text(habit.name)
                                            .foregroundStyle(Theme.ink)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .accessibilityLabel("\(habit.name), habit")
                                .accessibilityHint("Opens habit editor")
                            }
                        } header: {
                            searchSectionHeader("Habits")
                        }
                    }
                    if !matchingRecipes.isEmpty {
                        Section {
                            ForEach(matchingRecipes) { recipe in
                                NavigationLink {
                                    RecipeDetailView(
                                        recipe: recipe,
                                        scaledServings: recipe.baseServings,
                                        reason: recipe.course.capitalized,
                                        proteinG: recipe.proteinGPerServing,
                                        calories: recipe.caloriesPerServing
                                    )
                                } label: {
                                    HStack(spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "fork.knife", tint: Theme.cta, size: 32)
                                        Text(recipeDisplayName(recipe.name))
                                        Spacer(minLength: 0)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchRecipeLabel(recipe))
                                .accessibilityHint("Opens recipe details")
                            }
                        } header: {
                            searchSectionHeader("Recipes")
                        }
                    }
                    if !matchingGroceries.isEmpty {
                        Section {
                            ForEach(matchingGroceries, id: \.persistentModelID) { item in
                                Button {
                                    dismiss()
                                    appModel.requestedMainTab = 2
                                    appModel.requestedOpenShop = true
                                } label: {
                                    HStack(spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "basket", tint: Theme.accent, size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.ingredientName)
                                                .foregroundStyle(Theme.ink)
                                            Text(item.category)
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchGroceryLabel(item))
                                .accessibilityHint("Opens shop list on Meals tab")
                            }
                        } header: {
                            searchSectionHeader("Shop")
                        }
                    }
                    if !matchingSettings.isEmpty {
                        Section {
                            ForEach(matchingSettings) { match in
                                Button {
                                    appModel.pendingSettingsRoute = match.route
                                    appModel.showSettingsSheet = true
                                    dismiss()
                                } label: {
                                    HStack(spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "gearshape", tint: Theme.muted, size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(match.title)
                                                .foregroundStyle(Theme.ink)
                                            Text(match.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchSettingsLabel(match))
                                .accessibilityHint("Opens this settings screen")
                            }
                        } header: {
                            searchSectionHeader("Settings")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.cta)
                        .accessibilityIdentifier("global-search-close")
                        .accessibilityHint("Closes search")
                }
            }
            .onAppear {
                searchFieldFocused = true
            }
            .onChange(of: query) { _, newValue in
                scheduleSearchQuery(newValue)
            }
            .onChange(of: searchQuery) { _, committed in
                if !committed.trimmingCharacters(in: .whitespaces).isEmpty, hasAnyResults {
                    PlannerPreferences.recordSearchQuery(committed)
                    searchRecents = PlannerPreferences.searchRecents()
                }
            }
            .onDisappear { searchDebounceTask?.cancel() }
            .accessibilityIdentifier("global-search-sheet")
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task)
            }
            .sheet(item: $editingHabit) { habit in
                NewHabitSheet(habit: habit)
            }
            .sheet(item: $editingEvent) { context in
                PlannerEventSheet(context: context)
            }
        }
    }

    private var searchEmptyState: some View {
        Group {
            if !searchRecents.isEmpty {
                Section {
                    ForEach(searchRecents, id: \.self) { recent in
                        Button {
                            query = recent
                            searchQuery = recent
                        } label: {
                            Label(recent, systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityHint("Runs this search again")
                    }
                } header: {
                    searchSectionHeader("Recent")
                }
            }
            Section {
                if CadenceAppsPreferences.isVisible(.meals) {
                    searchQuickJump("Tonight's dinner", icon: "fork.knife") {
                        if let recipe = tonightRecipeName {
                            query = recipe
                            searchQuery = recipe
                        } else {
                            dismiss()
                            appModel.requestedMainTab = 2
                        }
                    }
                    searchQuickJump("Shop list", icon: "basket") {
                        dismiss()
                        appModel.requestedMainTab = 2
                        appModel.requestedOpenShop = true
                    }
                }
                if CadenceAppsPreferences.isVisible(.workout),
                   let workout = WorkoutIntegration.scheduledSession(on: .now, workoutsEnabled: true) {
                    searchQuickJump("\(workout.name) workout", icon: "dumbbell") {
                        query = workout.name
                        searchQuery = workout.name
                    }
                }
                searchQuickJump("Settings", icon: "gearshape") {
                    appModel.showSettingsSheet = true
                    dismiss()
                }
                searchQuickJump("Customize apps", icon: "square.grid.2x2") {
                    appModel.pendingSettingsRoute = .apps
                    appModel.showSettingsSheet = true
                    dismiss()
                }
            } header: {
                searchSectionHeader("Quick jumps")
            } footer: {
                Text("Tasks, habits, events, recipes, shop, and settings")
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel("Search scope: tasks, habits, events, recipes, shop, and settings")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var tonightRecipeName: String? {
        guard let plan = try? modelContext.fetch(FetchDescriptor<WeeklyPlanEntity>()).first?.decoded(),
              let dinner = plan.meal(day: MealPlanView.mondayBasedDayIndex(), slot: .dinner),
              let recipe = appModel.recipeDB.recipe(id: dinner.recipeID)
        else { return nil }
        return Theme.recipeDisplayName(recipe.name)
    }

    private func searchQuickJump(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                Theme.IconWell(systemImage: icon, tint: Theme.cta, size: 32)
                Text(title)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
        }
        .accessibilityHint("Opens \(title.lowercased())")
    }

    private func scheduleSearchQuery(_ newValue: String) {
        searchDebounceTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchQuery = ""
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(searchDebounceMs))
            guard !Task.isCancelled else { return }
            searchQuery = newValue
        }
    }
}
