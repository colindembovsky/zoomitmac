import AppKit

@MainActor
final class ShortcutCustomizationWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    var onShortcutsChanged: (() -> Void)?

    private let instructionLabel = NSTextField(labelWithString: "Click a command to record a new shortcut.")
    private let tableView = NSTableView()
    private var recordingItem: ShortcutListItem?
    private var keyMonitor: Any?

    private enum ShortcutListItem: CaseIterable {
        case toggleStillZoom
        case red
        case blue
        case green
        case yellow
        case clear
        case save

        var title: String {
            switch self {
            case .toggleStillZoom:
                return "Toggle Still Zoom"
            case .red:
                return AppShortcutAction.red.displayName
            case .blue:
                return AppShortcutAction.blue.displayName
            case .green:
                return AppShortcutAction.green.displayName
            case .yellow:
                return AppShortcutAction.yellow.displayName
            case .clear:
                return AppShortcutAction.clear.displayName
            case .save:
                return AppShortcutAction.save.displayName
            }
        }

        var shortcutDisplay: String {
            switch self {
            case .toggleStillZoom:
                return AppConfiguration.toggleHotkeyDisplayString
            case .red:
                return AppConfiguration.key(for: .red)
            case .blue:
                return AppConfiguration.key(for: .blue)
            case .green:
                return AppConfiguration.key(for: .green)
            case .yellow:
                return AppConfiguration.key(for: .yellow)
            case .clear:
                return AppConfiguration.key(for: .clear)
            case .save:
                return "Ctrl+\(AppConfiguration.key(for: .save))"
            }
        }

        var plainShortcutAction: AppShortcutAction? {
            switch self {
            case .toggleStillZoom:
                return nil
            case .red:
                return .red
            case .blue:
                return .blue
            case .green:
                return .green
            case .yellow:
                return .yellow
            case .clear:
                return .clear
            case .save:
                return .save
            }
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Customize Shortcuts"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        setupUI()
        installKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        ShortcutListItem.allCases.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = ShortcutListItem.allCases[row]
        let identifier = NSUserInterfaceItemIdentifier(tableColumn?.identifier.rawValue ?? "Cell")
        let text: String

        switch tableColumn?.identifier.rawValue {
        case "Command":
            text = item.title
        default:
            text = recordingItem == item ? "Recording…" : item.shortcutDisplay
        }

        let cellView = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? NSTableCellView()
        cellView.identifier = identifier

        let label: NSTextField
        if let existing = cellView.textField {
            label = existing
        } else {
            label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(label)
            cellView.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        }

        label.stringValue = text
        label.font = tableColumn?.identifier.rawValue == "Shortcut" && recordingItem == item
            ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            stopRecording(withMessage: "Click a command to record a new shortcut.")
            return
        }

        let item = ShortcutListItem.allCases[row]
        recordingItem = item
        instructionLabel.stringValue = "Recording \(item.title). Press a new shortcut, or Esc to cancel."
        tableView.reloadData()
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording(withMessage: "Click a command to record a new shortcut.")
    }

    private func setupUI() {
        guard let window, let contentView = window.contentView else {
            return
        }

        let commandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Command"))
        commandColumn.title = "Command"
        commandColumn.width = 300

        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Shortcut"))
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 180

        tableView.addTableColumn(commandColumn)
        tableView.addTableColumn(shortcutColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 28

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.lineBreakMode = .byWordWrapping

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(handleResetToDefaults))
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = NSButton(title: "Done", target: self, action: #selector(handleDone))
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(instructionLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(resetButton)
        contentView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -12),

            resetButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resetButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            doneButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            guard self.window?.isKeyWindow == true,
                  let recordingItem = self.recordingItem else {
                return event
            }

            self.handleRecordedShortcut(event, for: recordingItem)
            return nil
        }
    }

    private func handleRecordedShortcut(_ event: NSEvent, for item: ShortcutListItem) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.uppercased() ?? ""

        if characters == "\u{1B}" {
            stopRecording(withMessage: "Recording cancelled.")
            return
        }

        guard let normalizedKey = ShortcutKeyMapper.normalizedKeyInput(characters) else {
            rejectRecording("Use a single letter or number.")
            return
        }

        switch item {
        case .toggleStillZoom:
            guard let toggleModifier = ToggleHotkeyModifierOption.from(modifiers: modifiers),
                  ShortcutKeyMapper.carbonKeyCode(for: normalizedKey) != nil else {
                rejectRecording("Toggle Still Zoom must use a letter/number plus a supported modifier combination.")
                return
            }

            AppConfiguration.toggleHotkeyKey = normalizedKey
            AppConfiguration.toggleHotkeyModifier = toggleModifier
        case .save:
            AppConfiguration.setKey(normalizedKey, for: .save)
        case .red, .blue, .green, .yellow, .clear:
            guard let action = item.plainShortcutAction else {
                return
            }

            guard plainShortcutCanUse(key: normalizedKey, for: action) else {
                rejectRecording("That key is already in use by another plain shortcut.")
                return
            }

            AppConfiguration.setKey(normalizedKey, for: action)
        }

        onShortcutsChanged?()
        stopRecording(withMessage: "Shortcut updated. Click another command to record a new shortcut.")
    }

    private func plainShortcutCanUse(key: String, for action: AppShortcutAction) -> Bool {
        for existingAction in [AppShortcutAction.red, .blue, .green, .yellow, .clear] where existingAction != action {
            if AppConfiguration.key(for: existingAction) == key {
                return false
            }
        }
        return true
    }

    private func rejectRecording(_ message: String) {
        NSSound.beep()
        instructionLabel.stringValue = message
    }

    private func stopRecording(withMessage message: String) {
        recordingItem = nil
        instructionLabel.stringValue = message
        tableView.deselectAll(nil)
        tableView.reloadData()
    }

    @objc
    private func handleResetToDefaults() {
        AppConfiguration.resetShortcutsToDefaults()
        onShortcutsChanged?()
        stopRecording(withMessage: "Shortcuts reset to defaults.")
    }

    @objc
    private func handleDone() {
        close()
    }
}
