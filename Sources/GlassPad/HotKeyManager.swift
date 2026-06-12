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

        let hotKeyID = EventHotKeyID(signature: OSType(0x53544B43), id: 1) // 'STKC'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetEventDispatcherTarget(), 0, &hotKeyRef)
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
