import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
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
            title: "Toggle Still Zoom (Ctrl+1)",
            action: #selector(handleToggleMenuItem),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
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
