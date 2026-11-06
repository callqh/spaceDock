import AppKit
import Carbon
import SpaceDockCore

final class KeyboardMonitor {
    private let lock = NSLock()
    private var engine = ShortcutEngine()
    private var enabled = false
    private var tap: CFMachPort?
    private var loop: CFRunLoop?
    private var originalSpace: CGEvent?
    private let marker: Int64 = 0x5350444F434B
    var onShortcut: ((UInt16) -> Void)?
    var onFailure: ((String) -> Void)?

    var running: Bool { lock.lock(); defer { lock.unlock() }; return tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    func configure(keys: Set<UInt16>, delay: Double, enabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        engine.bindings = keys; engine.threshold = delay
        self.enabled = enabled
    }
    func contextChanged() { lock.lock(); engine.cancelForContextChange(); originalSpace = nil; lock.unlock() }
    func start() -> Bool {
        if running { return true }
        stop()
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { proxy, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeyboardMonitor>.fromOpaque(info).takeUnretainedValue().handle(proxy, type, event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        lock.lock(); tap = port; lock.unlock()
        let ready = DispatchSemaphore(value: 0)
        Thread.detachNewThread { [self] in
            let current = CFRunLoopGetCurrent()!
            lock.lock(); loop = current; lock.unlock()
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)!
            CFRunLoopAddSource(current, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            ready.signal(); CFRunLoopRun()
            CFRunLoopRemoveSource(current, source, .commonModes)
        }
        _ = ready.wait(timeout: .now() + 1)
        return running
    }
    func stop() {
        lock.lock(); let port = tap; let current = loop; tap = nil; loop = nil; enabled = false
        engine.reset(); originalSpace = nil; lock.unlock()
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let current { CFRunLoopStop(current) }
    }
    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == marker { return Unmanaged.passUnretained(event) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock(); engine.reset(); originalSpace = nil; enabled = false; lock.unlock()
            DispatchQueue.main.async { [weak self] in self?.onFailure?("键盘监听已停用，正在尝试恢复。") }
            return Unmanaged.passUnretained(event)
        }
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]
        let key = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let stroke = KeyStroke(type == .flagsChanged ? UInt16.max : key, down: type != .keyUp, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, modified: !event.flags.intersection(modifiers).isEmpty || type == .flagsChanged, time: Double(event.timestamp) / 1_000_000_000)
        lock.lock()
        if key == 49 && type == .keyDown && !stroke.repeated { originalSpace = event.copy() }
        let decision = engine.handle(stroke, enabled: enabled)
        let source = originalSpace?.copy()
        if key == 49 && type == .keyUp { originalSpace = nil }
        lock.unlock()
        for replay in decision.replay {
            guard let copy = source?.copy() ?? CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: replay.down) else { continue }
            copy.type = replay.down ? .keyDown : .keyUp
            copy.setIntegerValueField(.keyboardEventAutorepeat, value: replay.repeated ? 1 : 0)
            copy.setIntegerValueField(.eventSourceUserData, value: marker)
            copy.tapPostEvent(proxy)
        }
        if let key = decision.trigger { DispatchQueue.main.async { [weak self] in self?.onShortcut?(key) } }
        return decision.pass ? Unmanaged.passUnretained(event) : nil
    }
}
