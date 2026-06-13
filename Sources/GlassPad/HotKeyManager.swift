import Carbon.HIToolbox

final class HotKeyManager {
    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(keyCode: UInt32 = UInt32(kVK_ANSI_C),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey),
                  handler: @escaping () -> Void) {
        self.handler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(),
                            hotKeyEventHandler,
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &eventHandlerRef)

        registerCombo(keyCode: keyCode, modifiers: modifiers)
    }

    // Re-register at runtime without reinstalling the event handler or losing the
    // stored handler closure. Tears down the previous EventHotKeyRef first so the
    // old combo can't keep firing (and the ref can't leak). On failure — e.g. the
    // combo is held exclusively by another app — the old registration is left in
    // place and the call reports false so the caller can beep.
    @discardableResult
    func update(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        return registerCombo(keyCode: keyCode, modifiers: modifiers)
    }

    @discardableResult
    private func registerCombo(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x53544B43), id: 1) // 'STKC'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetEventDispatcherTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}

// Carbon takes a C function pointer, which cannot capture context; the manager
// instance travels through the userData pointer instead.
private func hotKeyEventHandler(_ nextHandler: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handler?()
    return noErr
}
