import AppKit

private enum InteractionMode {
    case navigation
    case annotation
}

private enum DragMode {
    case freehand
    case arrow
    case rectangle
    case ellipse
}

private enum Annotation {
    case freehand(points: [CGPoint], color: NSColor)
    case arrow(start: CGPoint, end: CGPoint, color: NSColor)
    case rectangle(rect: CGRect, color: NSColor)
    case ellipse(rect: CGRect, color: NSColor)
}

private enum SaveMode {
    case inactive
    case awaitingChoice
    case selecting(start: CGPoint, current: CGPoint)
}

final class StillZoomCanvasView: NSView {
    var onDismiss: (() -> Void)?
    var onError: ((String) -> Void)?

    private let sourceImage: CGImage
    private let screenScaleFactor: CGFloat

    private let minZoom: CGFloat = 1.1
    private let maxZoom: CGFloat = 8.0
    private let annotationLineWidth: CGFloat = 4.0
    private var zoomLevel: CGFloat = 2.0
    private var panCenter: CGPoint
    private var visibleSourceRect: CGRect = .zero
    private var interactionMode: InteractionMode = .navigation

    private var annotations: [Annotation] = []
    private var currentColor: NSColor = .systemRed

    private var currentDragMode: DragMode?
    private var dragStartSourcePoint: CGPoint?
    private var currentFreehandPoints: [CGPoint] = []
    private var previewEndSourcePoint: CGPoint?
    private var saveMode: SaveMode = .inactive

    private var isSaveModeActive: Bool {
        switch saveMode {
        case .inactive:
            return false
        case .awaitingChoice, .selecting:
            return true
        }
    }

    init(
        frame: NSRect,
        sourceImage: CGImage,
        scaleFactor: CGFloat,
        initialPanCenter: CGPoint
    ) {
        self.sourceImage = sourceImage
        self.screenScaleFactor = scaleFactor
        self.panCenter = initialPanCenter
        super.init(frame: frame)
        updateVisibleSourceRect()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseMoved(with event: NSEvent) {
        if handleSaveModeMouseMove(with: event) {
            return
        }

        guard interactionMode == .navigation, currentDragMode == nil else {
            return
        }

        let viewPoint = convert(event.locationInWindow, from: nil)
        panCenter = sourcePointFromScreenPosition(viewPoint)
        updateVisibleSourceRect()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if handleSaveModeMouseDown(with: event) {
            return
        }

        guard interactionMode == .annotation else {
            lockForAnnotation()
            return
        }

        beginDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if handleSaveModeMouseDragged(with: event) {
            return
        }

        guard let currentDragMode else {
            return
        }

        let sourcePoint = sourcePointFromCurrentZoom(convert(event.locationInWindow, from: nil))
        switch currentDragMode {
        case .freehand:
            currentFreehandPoints.append(sourcePoint)
        case .arrow, .rectangle, .ellipse:
            previewEndSourcePoint = sourcePoint
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if handleSaveModeMouseUp(with: event) {
            return
        }

        finishDrag(at: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard !isSaveModeActive else {
            return
        }

        guard interactionMode == .annotation else {
            return
        }

        switch dragMode(for: event) {
        case .freehand:
            return
        case .arrow, .rectangle, .ellipse:
            beginDrag(with: event)
        }
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard !isSaveModeActive else {
            return
        }

        if currentDragMode != nil {
            mouseDragged(with: event)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        guard !isSaveModeActive else {
            return
        }

        if currentDragMode != nil {
            finishDrag(at: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard !isSaveModeActive else {
            return
        }

        guard interactionMode == .navigation else {
            return
        }

        if event.scrollingDeltaY > 0 {
            zoomLevel = min(maxZoom, zoomLevel + 0.2)
        } else if event.scrollingDeltaY < 0 {
            zoomLevel = max(minZoom, zoomLevel - 0.2)
        }

        updateVisibleSourceRect()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        guard let characters = event.charactersIgnoringModifiers?.uppercased() else {
            return
        }

        if AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .save
        ) {
            enterSaveMode()
            return
        }

        if handleSaveModeKeyDown(characters) {
            return
        }

        switch true {
        case characters == "\u{1B}":
            onDismiss?()
        case AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .red
        ):
            currentColor = .systemRed
        case AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .blue
        ):
            currentColor = .systemBlue
        case AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .green
        ):
            currentColor = .systemGreen
        case AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .yellow
        ):
            currentColor = .systemYellow
        case AppConfiguration.matchesShortcut(
            characters: characters,
            modifiers: modifierFlags,
            action: .clear
        ):
            annotations.removeAll()
            clearTransientState()
            needsDisplay = true
        default:
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        drawAnnotations()
        drawPreviewAnnotation()
        drawSaveOverlay()
        drawInteractionHint()
    }

    private func beginDrag(with event: NSEvent) {
        window?.makeFirstResponder(self)

        let sourcePoint = sourcePointFromCurrentZoom(convert(event.locationInWindow, from: nil))
        dragStartSourcePoint = sourcePoint
        previewEndSourcePoint = sourcePoint
        currentDragMode = dragMode(for: event)

        switch currentDragMode {
        case .freehand:
            currentFreehandPoints = [sourcePoint]
        case .arrow, .rectangle, .ellipse:
            currentFreehandPoints = []
        case nil:
            break
        }

        needsDisplay = true
    }

    private func lockForAnnotation() {
        interactionMode = .annotation
        clearTransientState()
        needsDisplay = true
    }

    private func enterSaveMode() {
        clearTransientState()
        saveMode = .awaitingChoice
        needsDisplay = true
    }

    private func exitSaveMode() {
        saveMode = .inactive
        needsDisplay = true
    }

    private func finishDrag(at event: NSEvent) {
        guard let currentDragMode,
              let dragStartSourcePoint else {
            return
        }

        let sourcePoint = sourcePointFromCurrentZoom(convert(event.locationInWindow, from: nil))

        switch currentDragMode {
        case .freehand:
            if currentFreehandPoints.count > 1 {
                annotations.append(.freehand(points: currentFreehandPoints, color: currentColor))
            }
        case .arrow:
            if dragStartSourcePoint != sourcePoint {
                annotations.append(.arrow(start: dragStartSourcePoint, end: sourcePoint, color: currentColor))
            }
        case .rectangle:
            let rect = normalizedRect(from: dragStartSourcePoint, to: sourcePoint)
            if rect.width > 1, rect.height > 1 {
                annotations.append(.rectangle(rect: rect, color: currentColor))
            }
        case .ellipse:
            let rect = circleRect(fromCenter: dragStartSourcePoint, to: sourcePoint)
            if rect.width > 1, rect.height > 1 {
                annotations.append(.ellipse(rect: rect, color: currentColor))
            }
        }

        clearTransientState()
        needsDisplay = true
    }

    private func clearTransientState() {
        currentDragMode = nil
        dragStartSourcePoint = nil
        currentFreehandPoints.removeAll()
        previewEndSourcePoint = nil
    }

    private func dragMode(for event: NSEvent) -> DragMode {
        if event.modifierFlags.contains(.control) {
            return .arrow
        }
        if event.modifierFlags.contains(.command) {
            return .rectangle
        }
        if event.modifierFlags.contains(.option) {
            return .ellipse
        }
        return .freehand
    }

    private func updateVisibleSourceRect() {
        let imageSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        let visibleWidth = imageSize.width / zoomLevel
        let visibleHeight = imageSize.height / zoomLevel

        let maxOriginX = max(0, imageSize.width - visibleWidth)
        let maxOriginY = max(0, imageSize.height - visibleHeight)

        let originX = min(max(0, panCenter.x - visibleWidth / 2), maxOriginX)
        let originY = min(max(0, panCenter.y - visibleHeight / 2), maxOriginY)

        visibleSourceRect = CGRect(x: originX, y: originY, width: visibleWidth, height: visibleHeight)
    }

    private func sourcePointFromScreenPosition(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: max(0, min(CGFloat(sourceImage.width), viewPoint.x * screenScaleFactor)),
            y: max(0, min(CGFloat(sourceImage.height), CGFloat(sourceImage.height) - (viewPoint.y * screenScaleFactor)))
        )
    }

    private func sourcePointFromCurrentZoom(_ viewPoint: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let normalizedX = viewPoint.x / bounds.width
        let normalizedY = viewPoint.y / bounds.height

        return CGPoint(
            x: visibleSourceRect.minX + (normalizedX * visibleSourceRect.width),
            y: visibleSourceRect.minY + (normalizedY * visibleSourceRect.height)
        )
    }

    private func viewPointFromSource(_ sourcePoint: CGPoint) -> CGPoint {
        guard visibleSourceRect.width > 0, visibleSourceRect.height > 0 else {
            return .zero
        }

        let normalizedX = (sourcePoint.x - visibleSourceRect.minX) / visibleSourceRect.width
        let normalizedY = (sourcePoint.y - visibleSourceRect.minY) / visibleSourceRect.height

        return CGPoint(
            x: normalizedX * bounds.width,
            y: normalizedY * bounds.height
        )
    }

    private func drawBackground() {
        let cropRect = visibleSourceRect.integral
        guard cropRect.width > 0,
              cropRect.height > 0,
              let croppedImage = sourceImage.cropping(to: cropRect) else {
            return
        }

        let image = NSImage(cgImage: croppedImage, size: bounds.size)
        image.draw(in: bounds)
    }

    private func drawAnnotations() {
        for annotation in annotations {
            draw(annotation)
        }
    }

    private func drawPreviewAnnotation() {
        guard !isSaveModeActive else {
            return
        }

        guard let currentDragMode,
              let dragStartSourcePoint else {
            return
        }

        switch currentDragMode {
        case .freehand:
            guard currentFreehandPoints.count > 1 else {
                return
            }
            drawFreehand(points: currentFreehandPoints, color: currentColor)
        case .arrow:
            guard let previewEndSourcePoint else {
                return
            }
            drawArrow(from: dragStartSourcePoint, to: previewEndSourcePoint, color: currentColor)
        case .rectangle:
            guard let previewEndSourcePoint else {
                return
            }
            drawRectangle(normalizedRect(from: dragStartSourcePoint, to: previewEndSourcePoint), color: currentColor)
        case .ellipse:
            guard let previewEndSourcePoint else {
                return
            }
            drawEllipse(circleRect(fromCenter: dragStartSourcePoint, to: previewEndSourcePoint), color: currentColor)
        }
    }

    private func drawInteractionHint() {
        let message: String
        switch saveMode {
        case .awaitingChoice:
            message = "Save mode: press Enter to save the full image, or left-click to start a capture rectangle. Esc cancels."
        case .selecting:
            message = "Save mode: drag to size the capture rectangle and release to save it. Enter saves the current selection. Esc cancels."
        case .inactive:
            switch interactionMode {
            case .navigation:
                message = "Move the mouse to pan, scroll to zoom, then left-click to lock the still image for annotation. Esc exits."
            case .annotation:
                message = "Annotate with drag. Ctrl-drag draws an arrow, Cmd-drag a rectangle, Option-drag a circle, \(AppConfiguration.key(for: .red))/\(AppConfiguration.key(for: .blue))/\(AppConfiguration.key(for: .green))/\(AppConfiguration.key(for: .yellow)) change color, \(AppConfiguration.key(for: .clear)) clears, Ctrl+\(AppConfiguration.key(for: .save)) saves, Esc exits."
            }
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let textRect = CGRect(
            x: 24,
            y: 24,
            width: min(bounds.width - 48, 760),
            height: 42
        )
        let backgroundRect = textRect.insetBy(dx: -10, dy: -8)

        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 10, yRadius: 10).fill()

        let attributedString = NSAttributedString(
            string: message,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedString.draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }

    private func drawSaveOverlay() {
        guard isSaveModeActive else {
            return
        }

        let selectionRect: CGRect?
        switch saveMode {
        case .inactive, .awaitingChoice:
            selectionRect = nil
        case let .selecting(start, current):
            selectionRect = normalizedRect(from: start, to: current)
        }

        let dimPath = NSBezierPath(rect: bounds)
        if let selectionRect, selectionRect.width > 0, selectionRect.height > 0 {
            dimPath.append(NSBezierPath(rect: selectionRect))
            dimPath.windingRule = .evenOdd
        }

        NSColor.black.withAlphaComponent(0.45).setFill()
        dimPath.fill()

        guard let selectionRect, selectionRect.width > 0, selectionRect.height > 0 else {
            return
        }

        NSColor.white.setStroke()
        let outlinePath = NSBezierPath(rect: selectionRect)
        outlinePath.lineWidth = 2
        outlinePath.setLineDash([6, 4], count: 2, phase: 0)
        outlinePath.stroke()
    }

    private func draw(_ annotation: Annotation) {
        switch annotation {
        case let .freehand(points, color):
            drawFreehand(points: points, color: color)
        case let .arrow(start, end, color):
            drawArrow(from: start, to: end, color: color)
        case let .rectangle(rect, color):
            drawRectangle(rect, color: color)
        case let .ellipse(rect, color):
            drawEllipse(rect, color: color)
        }
    }

    private func drawFreehand(points: [CGPoint], color: NSColor) {
        guard points.count > 1 else {
            return
        }

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = annotationLineWidth
        color.setStroke()

        let transformedPoints = points.map(viewPointFromSource)
        path.move(to: transformedPoints[0])
        for point in transformedPoints.dropFirst() {
            path.line(to: point)
        }
        path.stroke()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor) {
        let startPoint = viewPointFromSource(start)
        let endPoint = viewPointFromSource(end)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let arrowLength = hypot(deltaX, deltaY)

        guard arrowLength > 1 else {
            return
        }

        color.setStroke()

        let linePath = NSBezierPath()
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.lineWidth = annotationLineWidth
        linePath.move(to: startPoint)
        linePath.line(to: endPoint)
        linePath.stroke()

        let headLength = max(16, annotationLineWidth * 4)
        let headAngle: CGFloat = .pi / 7
        let angle = atan2(deltaY, deltaX)

        let leftPoint = CGPoint(
            x: endPoint.x - cos(angle - headAngle) * headLength,
            y: endPoint.y - sin(angle - headAngle) * headLength
        )
        let rightPoint = CGPoint(
            x: endPoint.x - cos(angle + headAngle) * headLength,
            y: endPoint.y - sin(angle + headAngle) * headLength
        )

        let headPath = NSBezierPath()
        headPath.lineCapStyle = .round
        headPath.lineJoinStyle = .round
        headPath.lineWidth = annotationLineWidth
        headPath.move(to: endPoint)
        headPath.line(to: leftPoint)
        headPath.move(to: endPoint)
        headPath.line(to: rightPoint)
        headPath.stroke()
    }

    private func drawRectangle(_ rect: CGRect, color: NSColor) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        color.setStroke()
        let viewRect = transformedRect(from: rect)
        let path = NSBezierPath(rect: viewRect)
        path.lineWidth = annotationLineWidth
        path.stroke()
    }

    private func drawEllipse(_ rect: CGRect, color: NSColor) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        color.setStroke()
        let viewRect = transformedRect(from: rect)
        let path = NSBezierPath(ovalIn: viewRect)
        path.lineWidth = annotationLineWidth
        path.stroke()
    }

    private func transformedRect(from rect: CGRect) -> CGRect {
        let minPoint = viewPointFromSource(CGPoint(x: rect.minX, y: rect.minY))
        let maxPoint = viewPointFromSource(CGPoint(x: rect.maxX, y: rect.maxY))
        return normalizedRect(from: minPoint, to: maxPoint)
    }

    private func handleSaveModeKeyDown(_ characters: String) -> Bool {
        guard isSaveModeActive else {
            return false
        }

        switch characters {
        case "\u{1B}":
            exitSaveMode()
            return true
        case "\r", "\u{3}":
            switch saveMode {
            case .awaitingChoice:
                saveSnapshot(in: bounds)
            case let .selecting(start, current):
                let selectionRect = normalizedRect(from: start, to: current).integral
                if selectionRect.width > 1, selectionRect.height > 1 {
                    saveSnapshot(in: selectionRect)
                } else {
                    NSSound.beep()
                }
            case .inactive:
                break
            }
            return true
        default:
            return true
        }
    }

    private func handleSaveModeMouseMove(with event: NSEvent) -> Bool {
        guard isSaveModeActive else {
            return false
        }

        return true
    }

    private func handleSaveModeMouseDown(with event: NSEvent) -> Bool {
        guard isSaveModeActive else {
            return false
        }

        window?.makeFirstResponder(self)
        let point = clampedViewPoint(convert(event.locationInWindow, from: nil))

        switch saveMode {
        case .awaitingChoice:
            saveMode = .selecting(start: point, current: point)
            needsDisplay = true
        case .selecting:
            break
        case .inactive:
            break
        }

        return true
    }

    private func handleSaveModeMouseDragged(with event: NSEvent) -> Bool {
        guard isSaveModeActive else {
            return false
        }

        if case let .selecting(start, _) = saveMode {
            let point = clampedViewPoint(convert(event.locationInWindow, from: nil))
            saveMode = .selecting(start: start, current: point)
            needsDisplay = true
        }

        return true
    }

    private func handleSaveModeMouseUp(with event: NSEvent) -> Bool {
        guard isSaveModeActive else {
            return false
        }

        guard case let .selecting(start, _) = saveMode else {
            return true
        }

        let point = clampedViewPoint(convert(event.locationInWindow, from: nil))
        let selectionRect = normalizedRect(from: start, to: point).integral

        if selectionRect.width > 1, selectionRect.height > 1 {
            saveSnapshot(in: selectionRect)
        } else {
            NSSound.beep()
            saveMode = .awaitingChoice
            needsDisplay = true
        }

        return true
    }

    private func clampedViewPoint(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(0, viewPoint.x), bounds.width),
            y: min(max(0, viewPoint.y), bounds.height)
        )
    }

    private func saveSnapshot(in renderRect: CGRect) {
        do {
            guard let image = renderSnapshot(in: renderRect) else {
                throw SaveError.renderFailed
            }

            try writeSnapshot(image)
            try copySnapshotToPasteboard(image)
            exitSaveMode()
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func renderSnapshot(in renderRect: CGRect) -> NSImage? {
        let captureRect = renderRect.integral.intersection(bounds).integral
        guard captureRect.width > 0, captureRect.height > 0 else {
            return nil
        }

        guard let fullImage = renderFullSnapshot() else {
            return nil
        }

        guard captureRect != bounds.integral else {
            return fullImage
        }

        let scaleFactor = window?.backingScaleFactor ?? screenScaleFactor
        let pixelsWide = max(1, Int(captureRect.width * scaleFactor))
        let pixelsHigh = max(1, Int(captureRect.height * scaleFactor))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        bitmap.size = captureRect.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
        graphicsContext.cgContext.clear(CGRect(origin: .zero, size: captureRect.size))
        fullImage.draw(
            in: CGRect(
                x: -captureRect.minX,
                y: -captureRect.minY,
                width: bounds.width,
                height: bounds.height
            )
        )
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: captureRect.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func renderFullSnapshot() -> NSImage? {
        let scaleFactor = window?.backingScaleFactor ?? screenScaleFactor
        let pixelsWide = max(1, Int(bounds.width * scaleFactor))
        let pixelsHigh = max(1, Int(bounds.height * scaleFactor))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        bitmap.size = bounds.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
        graphicsContext.cgContext.clear(bounds)
        drawBackground()
        drawAnnotations()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func writeSnapshot(_ image: NSImage) throws {
        let saveFolderURL = AppConfiguration.saveFolderURL
        try FileManager.default.createDirectory(at: saveFolderURL, withIntermediateDirectories: true)

        let fileURL = saveFolderURL.appendingPathComponent(Self.snapshotFilename())
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SaveError.pngEncodingFailed
        }

        try pngData.write(to: fileURL, options: .atomic)
    }

    private func copySnapshotToPasteboard(_ image: NSImage) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects([image]) else {
            throw SaveError.clipboardWriteFailed
        }
    }

    private static func snapshotFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return "ZoomItMac-\(formatter.string(from: Date())).png"
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func circleRect(fromCenter center: CGPoint, to edgePoint: CGPoint) -> CGRect {
        let radius = hypot(edgePoint.x - center.x, edgePoint.y - center.y)
        return CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
}

private enum SaveError: LocalizedError {
    case renderFailed
    case pngEncodingFailed
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Unable to render the current zoom image for saving."
        case .pngEncodingFailed:
            return "Unable to encode the saved image as PNG."
        case .clipboardWriteFailed:
            return "The image was saved, but ZoomItMac could not copy it to the clipboard."
        }
    }
}
