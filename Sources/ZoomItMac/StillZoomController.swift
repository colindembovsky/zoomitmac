import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenCapturePermissionStatus {
    case granted
    case grantedNeedsRelaunch
    case denied
}

@MainActor
final class StillZoomController {
    var onDismiss: (() -> Void)?
    var onError: ((String) -> Void)?

    private var overlayWindow: OverlayWindow?
    private var canvasView: StillZoomCanvasView?
    private var isPresenting = false

    func present() {
        guard overlayWindow == nil, !isPresenting else {
            return
        }

        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            onError?("Unable to find the display under the cursor.")
            return
        }

        isPresenting = true

        Task { @MainActor in
            defer {
                isPresenting = false
            }

            do {
                let capture = try await Self.captureStillImage(for: screen)
                showOverlay(
                    on: screen,
                    sourceImage: capture.image,
                    scaleFactor: capture.scaleFactor,
                    initialPanCenter: capture.initialPanCenter
                )
            } catch let error as StillZoomError {
                onError?(error.errorDescription ?? "Unable to capture the screen.")
            } catch {
                onError?(error.localizedDescription)
            }
        }
    }

    func dismiss() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
        canvasView = nil
        onDismiss?()
    }

    static func requestScreenCapturePermissionOnLaunch() -> ScreenCapturePermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }

        return CGRequestScreenCaptureAccess() ? .grantedNeedsRelaunch : .denied
    }

    private func showOverlay(
        on screen: NSScreen,
        sourceImage: CGImage,
        scaleFactor: CGFloat,
        initialPanCenter: CGPoint
    ) {
        let window = OverlayWindow(for: screen)
        let canvasView = StillZoomCanvasView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            sourceImage: sourceImage,
            scaleFactor: scaleFactor,
            initialPanCenter: initialPanCenter
        )

        canvasView.onDismiss = { [weak self] in
            self?.dismiss()
        }
        canvasView.onError = { [weak self] message in
            self?.onError?(message)
        }

        window.contentView = canvasView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvasView)

        NSApplication.shared.activate(ignoringOtherApps: true)

        overlayWindow = window
        self.canvasView = canvasView
    }

    private static func captureStillImage(for screen: NSScreen) async throws -> CaptureResult {
        // ScreenCaptureKit can succeed even when the preflight permission signal lags behind
        // the current System Settings state, so try the capture first before failing fast.
        do {
            return try await performStillCapture(for: screen)
        } catch {
            if CGPreflightScreenCaptureAccess() {
                throw error
            }

            guard CGRequestScreenCaptureAccess() else {
                throw StillZoomError.permissionDenied
            }

            do {
                return try await performStillCapture(for: screen)
            } catch {
                if CGPreflightScreenCaptureAccess() {
                    throw error
                }
                throw StillZoomError.permissionGrantedRetry
            }
        }
    }

    private static func performStillCapture(for screen: NSScreen) async throws -> CaptureResult {
        let scaleFactor = screen.backingScaleFactor
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()

        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = availableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw StillZoomError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(screen.frame.width * scaleFactor)
        configuration.height = Int(screen.frame.height * scaleFactor)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let mouseLocation = NSEvent.mouseLocation
        let localMouse = CGPoint(
            x: mouseLocation.x - screen.frame.origin.x,
            y: mouseLocation.y - screen.frame.origin.y
        )
        let initialPanCenter = CGPoint(
            x: localMouse.x * scaleFactor,
            y: localMouse.y * scaleFactor
        )

        return CaptureResult(
            image: image,
            scaleFactor: scaleFactor,
            initialPanCenter: initialPanCenter
        )
    }
}

private struct CaptureResult {
    let image: CGImage
    let scaleFactor: CGFloat
    let initialPanCenter: CGPoint
}

private enum StillZoomError: LocalizedError {
    case permissionDenied
    case permissionGrantedRetry
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required for still zoom. If it is already enabled, quit ZoomItMac, re-enable the current app entry in System Settings, and try again."
        case .permissionGrantedRetry:
            return "Screen Recording permission was granted, but macOS has not applied it to this app session yet. Relaunch ZoomItMac and trigger still zoom again."
        case .displayNotFound:
            return "Unable to resolve the selected display for capture."
        }
    }
}

private extension NSScreen {
    static var screenContainingMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first(where: { $0.frame.contains(mouseLocation) })
    }
}
