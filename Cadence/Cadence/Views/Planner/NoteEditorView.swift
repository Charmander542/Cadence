import SwiftUI
import SwiftData
import UIKit

// MARK: - List pane (Apple Notes folder contents)

enum ListContentMode: String, CaseIterable, Identifiable {
    case tasks
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .notes: return "Notes"
        }
    }
}

struct ListNotesPane: View {
    let listID: UUID?
    var onOpenNote: (PlannerNoteEntity) -> Void
    var onCreateNote: () -> Void

    @Query(sort: \PlannerNoteEntity.updatedAt, order: .reverse) private var allNotes: [PlannerNoteEntity]
    @State private var query = ""

    private var notes: [PlannerNoteEntity] {
        let scoped: [PlannerNoteEntity]
        if let listID {
            scoped = allNotes.filter { $0.list?.id == listID }
        } else {
            scoped = allNotes.filter { $0.list?.name == "Inbox" }
        }
        let filtered: [PlannerNoteEntity]
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = scoped
        } else {
            let q = query.lowercased()
            filtered = scoped.filter {
                $0.displayTitle.lowercased().contains(q) || $0.body.lowercased().contains(q)
            }
        }
        let pinned = filtered.filter(\.isPinned)
        let rest = filtered.filter { !$0.isPinned }
        return pinned + rest
    }

    private var pinned: [PlannerNoteEntity] { notes.filter(\.isPinned) }
    private var unpinned: [PlannerNoteEntity] { notes.filter { !$0.isPinned } }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.sm) {
                if notes.isEmpty && query.isEmpty {
                    Theme.EmptyState(
                        systemImage: "note.text",
                        title: "No notes yet",
                        message: "Capture ideas, meeting scribbles, or a Notion-style page for this list.",
                        cta: "New note",
                        ctaHint: "Creates a blank note in this list"
                    ) {
                        onCreateNote()
                    }
                    .frame(minHeight: 220)
                } else {
                    if !pinned.isEmpty {
                        noteSection(title: "Pinned", items: pinned)
                    }
                    if !unpinned.isEmpty {
                        noteSection(title: pinned.isEmpty ? nil : "Notes", items: unpinned)
                    } else if !query.isEmpty {
                        Text("No matching notes")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Theme.Space.sm)
                    }
                }
            }
            .padding(.bottom, Theme.Space.xl * 2)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Theme.Space.sm) {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.muted)
                    TextField("Search", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(Theme.sunken, in: Capsule())

                Button(action: onCreateNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                        .frame(width: 44, height: 44)
                        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New note")
            }
            .padding(.vertical, Theme.Space.sm)
            .background(Theme.canvas.opacity(0.92))
        }
    }

    @ViewBuilder
    private func noteSection(title: String?, items: [PlannerNoteEntity]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                ForEach(items) { note in
                    Button {
                        onOpenNote(note)
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)
                    if note.id != items.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    private func noteRow(_ note: PlannerNoteEntity) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.cta)
                    }
                    Text(note.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(Self.relativeStamp(note.updatedAt))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text(note.previewSnippet)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted.opacity(0.6))
        }
        .padding(.horizontal, Theme.Space.md + 2)
        .padding(.vertical, Theme.Space.md)
        .contentShape(Rectangle())
        .accessibilityLabel("\(note.displayTitle), \(note.previewSnippet)")
    }

    private static func relativeStamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Full-screen editor

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var note: PlannerNoteEntity

    @State private var titleText: String = ""
    @State private var attributedBody = NSAttributedString(string: "")
    @State private var showDeleteConfirm = false
    @State private var autosaveTask: Task<Void, Never>?
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title", text: $titleText, axis: .vertical)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .focused($titleFocused)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.md)
                    .padding(.bottom, Theme.Space.sm)

                RichNoteTextView(
                    attributedText: $attributedBody,
                    placeholder: "Start writing…",
                    onEdit: { scheduleAutosave() }
                )
                .padding(.horizontal, Theme.Space.md)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        persist()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.cta)
                    }
                    .accessibilityLabel("Done")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            note.isPinned.toggle()
                            persist()
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    PlannerStore.deleteNote(note, in: modelContext)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                titleText = note.title
                attributedBody = Self.loadAttributed(from: note)
            }
            .onDisappear { persist() }
            .onChange(of: titleText) { _, _ in scheduleAutosave() }
        }
        .preferredColorScheme(.light)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        note.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        note.body = attributedBody.string
        note.bodyRTF = Self.rtfData(from: attributedBody) ?? Data()
        PlannerStore.touchNote(note, in: modelContext)
    }

    private static func loadAttributed(from note: PlannerNoteEntity) -> NSAttributedString {
        if !note.bodyRTF.isEmpty,
           let attr = try? NSAttributedString(
            data: note.bodyRTF,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            return attr
        }
        return NSAttributedString(
            string: note.body,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        )
    }

    private static func rtfData(from attributed: NSAttributedString) -> Data? {
        try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

// MARK: - UITextView + Apple Notes–style accessory

struct RichNoteTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var placeholder: String
    var onEdit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 24, right: 4)
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.allowsEditingTextAttributes = true
        tv.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        tv.attributedText = attributedText
        context.coordinator.textView = tv
        tv.inputAccessoryView = context.coordinator.makeAccessory()
        context.coordinator.installPlaceholder(in: tv)
        context.coordinator.refreshPlaceholder()
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.attributedText.string != attributedText.string
            || uiView.attributedText.length != attributedText.length {
            let selected = uiView.selectedRange
            uiView.attributedText = attributedText
            if selected.location <= uiView.attributedText.length {
                uiView.selectedRange = selected
            }
        }
        context.coordinator.refreshPlaceholder()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichNoteTextView
        weak var textView: UITextView?
        private let placeholderLabel = UILabel()

        init(_ parent: RichNoteTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText ?? NSAttributedString(string: "")
            refreshPlaceholder()
            parent.onEdit()
        }

        func refreshPlaceholder() {
            guard let textView else { return }
            placeholderLabel.isHidden = !(textView.text?.isEmpty ?? true)
        }

        func installPlaceholder(in tv: UITextView) {
            placeholderLabel.text = parent.placeholder
            placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
            placeholderLabel.textColor = .tertiaryLabel
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            if placeholderLabel.superview == nil {
                tv.addSubview(placeholderLabel)
                NSLayoutConstraint.activate([
                    placeholderLabel.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 9),
                    placeholderLabel.topAnchor.constraint(equalTo: tv.topAnchor, constant: 8)
                ])
            }
        }

        func makeAccessory() -> UIView {
            let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 48))
            bar.barStyle = .default
            bar.isTranslucent = true
            bar.tintColor = UIColor(Theme.cta)

            let items: [UIBarButtonItem] = [
                makeItem(systemName: "bold", action: #selector(toggleBold)),
                makeItem(systemName: "italic", action: #selector(toggleItalic)),
                makeItem(systemName: "underline", action: #selector(toggleUnderline)),
                .flexibleSpace(),
                makeItem(systemName: "textformat.size.larger", action: #selector(applyHeading)),
                makeItem(systemName: "textformat", action: #selector(applyBody)),
                .flexibleSpace(),
                makeItem(systemName: "list.bullet", action: #selector(insertBullet)),
                makeItem(systemName: "checklist", action: #selector(insertChecklist)),
                .flexibleSpace(),
                makeItem(systemName: "keyboard.chevron.compact.down", action: #selector(dismissKeyboard))
            ]
            bar.items = items
            return bar
        }

        private func makeItem(systemName: String, action: Selector) -> UIBarButtonItem {
            UIBarButtonItem(image: UIImage(systemName: systemName), style: .plain, target: self, action: action)
        }

        @objc private func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        @objc private func toggleBold() { toggleTrait(.traitBold) }
        @objc private func toggleItalic() { toggleTrait(.traitItalic) }

        @objc private func toggleUnderline() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            var isUnderlined = false
            mutable.enumerateAttribute(.underlineStyle, in: range) { value, _, _ in
                if let style = value as? Int, style != 0 { isUnderlined = true }
            }
            mutable.addAttribute(
                .underlineStyle,
                value: isUnderlined ? 0 : NSUnderlineStyle.single.rawValue,
                range: range
            )
            tv.attributedText = mutable
            tv.selectedRange = range
            parent.attributedText = mutable
        }

        @objc private func applyHeading() {
            applyFont(UIFont.preferredFont(forTextStyle: .title2).bold())
        }

        @objc private func applyBody() {
            applyFont(UIFont.preferredFont(forTextStyle: .body))
        }

        @objc private func insertBullet() {
            insertLinePrefix("• ")
        }

        @objc private func insertChecklist() {
            insertLinePrefix("☐ ")
        }

        private func insertLinePrefix(_ prefix: String) {
            guard let tv = textView else { return }
            let loc = tv.selectedRange.location
            let text = tv.text as NSString? ?? ""
            let lineStart = text.lineRange(for: NSRange(location: min(loc, text.length), length: 0)).location
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            let insertion = NSAttributedString(
                string: prefix,
                attributes: tv.typingAttributes
            )
            mutable.insert(insertion, at: lineStart)
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: loc + prefix.count, length: 0)
            parent.attributedText = mutable
        }

        private func applyFont(_ font: UIFont) {
            guard let tv = textView else { return }
            var attrs = tv.typingAttributes
            attrs[.font] = font
            tv.typingAttributes = attrs
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            mutable.addAttribute(.font, value: font, range: range)
            tv.attributedText = mutable
            tv.selectedRange = range
            parent.attributedText = mutable
        }

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            guard range.length > 0 else {
                var attrs = tv.typingAttributes
                let current = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
                if let next = current.toggled(trait) {
                    attrs[.font] = next
                    tv.typingAttributes = attrs
                }
                return
            }
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
                if let next = font.toggled(trait) {
                    mutable.addAttribute(.font, value: next, range: subrange)
                }
            }
            tv.attributedText = mutable
            tv.selectedRange = range
            parent.attributedText = mutable
        }
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitBold)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    func toggled(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        var traits = fontDescriptor.symbolicTraits
        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return nil }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
