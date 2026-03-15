import Carbon.HIToolbox

final class HotkeyManager {
    var onToggleStillZoom: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private let signature: OSType = 0x5A544D43 // 'ZTMC'
    private let stillZoomHotKeyID: UInt32 = 1

    func start() {
        guard hotKeyRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: stillZoomHotKeyID)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_1),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            stop()
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var eventID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventID
        )

        guard status == noErr,
              eventID.signature == signature,
              eventID.id == stillZoomHotKeyID else {
            return OSStatus(eventNotHandledErr)
        }

        onToggleStillZoom?()
        return noErr
    }
}

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handleHotKeyEvent(event)
}
