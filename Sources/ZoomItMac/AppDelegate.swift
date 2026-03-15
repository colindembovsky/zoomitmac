import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private let hotkeyManager = HotkeyManager()
    private var stillZoomController: StillZoomController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotkeyManager.onToggleStillZoom = { [weak self] in
            self?.toggleStillZoom()
        }
        hotkeyManager.start()
        requestScreenCapturePermissionOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    @objc
    private func handleToggleMenuItem() {
        toggleStillZoom()
    }

    @objc
    private func handleQuitMenuItem() {
        NSApp.terminate(nil)
    }

    @objc
    private func handleChooseSaveFolderMenuItem() {
        chooseSaveFolder()
    }

    @objc
    private func handleCustomizeShortcutsMenuItem() {
        presentShortcutCustomization()
    }

    private func toggleStillZoom() {
        if let stillZoomController {
            stillZoomController.dismiss()
            self.stillZoomController = nil
            return
        }

        let controller = StillZoomController()
        controller.onDismiss = { [weak self] in
            self?.stillZoomController = nil
        }
        controller.onError = { [weak self] message in
            self?.stillZoomController = nil
            self?.presentError(message: message)
        }

        stillZoomController = controller
        controller.present()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "ZoomItMac"

        if let image = NSImage(
            systemSymbolName: "plus.magnifyingglass",
            accessibilityDescription: "ZoomItMac"
        ) {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "ZI"
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "",
            action: #selector(handleToggleMenuItem),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        toggleMenuItem = toggleItem
        updateToggleMenuItemTitle()

        let saveFolderItem = NSMenuItem(
            title: "Choose Save Folder…",
            action: #selector(handleChooseSaveFolderMenuItem),
            keyEquivalent: ""
        )
        saveFolderItem.target = self
        menu.addItem(saveFolderItem)

        let customizeShortcutsItem = NSMenuItem(
            title: "Customize Shortcuts…",
            action: #selector(handleCustomizeShortcutsMenuItem),
            keyEquivalent: ""
        )
        customizeShortcutsItem.target = self
        menu.addItem(customizeShortcutsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(handleQuitMenuItem),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func updateToggleMenuItemTitle() {
        toggleMenuItem?.title = "Toggle Still Zoom (\(AppConfiguration.toggleHotkeyDisplayString))"
    }

    private func chooseSaveFolder() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose Save Folder"
        panel.message = "Saved still-zoom images will be written here."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = AppConfiguration.saveFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            AppConfiguration.saveFolderURL = url
        }
    }

    private func presentShortcutCustomization() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Customize Shortcuts"
        alert.informativeText = "Use a single letter or number for each shortcut."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let toggleKeyField = NSTextField(string: AppConfiguration.toggleHotkeyKey)
        let redKeyField = NSTextField(string: AppConfiguration.key(for: .red))
        let blueKeyField = NSTextField(string: AppConfiguration.key(for: .blue))
        let greenKeyField = NSTextField(string: AppConfiguration.key(for: .green))
        let yellowKeyField = NSTextField(string: AppConfiguration.key(for: .yellow))
        let clearKeyField = NSTextField(string: AppConfiguration.key(for: .clear))
        let saveKeyField = NSTextField(string: AppConfiguration.key(for: .save))

        let toggleModifierPopup = NSPopUpButton()
        ToggleHotkeyModifierOption.allCases.forEach {
            toggleModifierPopup.addItem(withTitle: $0.displayName)
        }
        toggleModifierPopup.selectItem(at: ToggleHotkeyModifierOption.allCases.firstIndex(of: AppConfiguration.toggleHotkeyModifier) ?? 0)

        let labels = [
            "Toggle Hotkey",
            "Toggle Modifiers",
            AppShortcutAction.red.displayName,
            AppShortcutAction.blue.displayName,
            AppShortcutAction.green.displayName,
            AppShortcutAction.yellow.displayName,
            AppShortcutAction.clear.displayName,
            AppShortcutAction.save.displayName
        ]

        let fields: [NSView] = [
            toggleKeyField,
            toggleModifierPopup,
            redKeyField,
            blueKeyField,
            greenKeyField,
            yellowKeyField,
            clearKeyField,
            saveKeyField
        ]

        let rows = zip(labels, fields).map { labelText, field in
            [NSTextField(labelWithString: labelText), field]
        }

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.widthAnchor.constraint(equalToConstant: 420).isActive = true
        alert.accessoryView = grid

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        guard let toggleKey = ShortcutKeyMapper.normalizedKeyInput(toggleKeyField.stringValue),
              ShortcutKeyMapper.carbonKeyCode(for: toggleKey) != nil else {
            presentAlert(
                title: "Invalid Shortcut",
                message: "The toggle hotkey must be a single letter or number.",
                style: .warning
            )
            return
        }

        let modifierSelection = max(0, toggleModifierPopup.indexOfSelectedItem)
        let toggleModifier = ToggleHotkeyModifierOption.allCases[modifierSelection]

        let plainShortcutInputs: [(AppShortcutAction, String)] = [
            (.red, redKeyField.stringValue),
            (.blue, blueKeyField.stringValue),
            (.green, greenKeyField.stringValue),
            (.yellow, yellowKeyField.stringValue),
            (.clear, clearKeyField.stringValue)
        ]

        var normalizedPlainKeys: [AppShortcutAction: String] = [:]
        for (action, rawValue) in plainShortcutInputs {
            guard let normalized = ShortcutKeyMapper.normalizedKeyInput(rawValue) else {
                presentAlert(
                    title: "Invalid Shortcut",
                    message: "\(action.displayName) must be a single letter or number.",
                    style: .warning
                )
                return
            }
            normalizedPlainKeys[action] = normalized
        }

        let usedPlainKeys = Array(normalizedPlainKeys.values)
        guard Set(usedPlainKeys).count == usedPlainKeys.count else {
            presentAlert(
                title: "Invalid Shortcuts",
                message: "Red, blue, green, yellow, and clear shortcuts must all be different.",
                style: .warning
            )
            return
        }

        guard let saveKey = ShortcutKeyMapper.normalizedKeyInput(saveKeyField.stringValue) else {
            presentAlert(
                title: "Invalid Shortcut",
                message: "\(AppShortcutAction.save.displayName) must be a single letter or number.",
                style: .warning
            )
            return
        }

        AppConfiguration.toggleHotkeyKey = toggleKey
        AppConfiguration.toggleHotkeyModifier = toggleModifier
        normalizedPlainKeys.forEach { action, key in
            AppConfiguration.setKey(key, for: action)
        }
        AppConfiguration.setKey(saveKey, for: .save)

        hotkeyManager.restart()
        updateToggleMenuItemTitle()
    }

    private func requestScreenCapturePermissionOnLaunch() {
        switch StillZoomController.requestScreenCapturePermissionOnLaunch() {
        case .granted:
            return
        case .grantedNeedsRelaunch:
            presentAlert(
                title: "Screen Recording Enabled",
                message: "ZoomItMac now has Screen Recording permission. Quit and reopen the app once before using still zoom.",
                style: .informational
            )
        case .denied:
            presentAlert(
                title: "Screen Recording Permission Needed",
                message: "Enable ZoomItMac in System Settings > Privacy & Security > Screen Recording, then reopen the app.",
                style: .warning
            )
        }
    }

    private func presentError(message: String) {
        presentAlert(
            title: "Unable to start still zoom",
            message: message,
            style: .warning
        )
    }

    private func presentAlert(title: String, message: String, style: NSAlert.Style) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
