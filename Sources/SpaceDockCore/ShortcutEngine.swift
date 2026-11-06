import Foundation

public struct KeyStroke: Equatable {
    public var key: UInt16
    public var down: Bool
    public var repeated: Bool
    public var modified: Bool
    public var time: TimeInterval
    public init(_ key: UInt16, down: Bool, repeated: Bool = false, modified: Bool = false, time: TimeInterval) {
        self.key = key; self.down = down; self.repeated = repeated; self.modified = modified; self.time = time
    }
}
public struct KeyDecision {
    public var pass = true
    public var replay: [KeyStroke] = []
    public var trigger: UInt16?
}

/// Pure event reducer. Buffers only space events, never arbitrary input text.
public struct ShortcutEngine {
    enum Phase { case idle, pending(TimeInterval), consumed, passthrough }
    var phase: Phase = .idle
    var spaces: [KeyStroke] = []
    var swallowed: Set<UInt16> = []
    public var threshold: TimeInterval = 0.2
    public var bindings: Set<UInt16> = []
    public init() {}
    public mutating func handle(_ event: KeyStroke, enabled: Bool = true) -> KeyDecision {
        var result = KeyDecision()
        if swallowed.contains(event.key) {
            result.pass = false
            if !event.down { swallowed.remove(event.key) }
            return result
        }
        if !enabled || event.modified {
            if case .pending = phase { result.replay = spaces; spaces.removeAll(); phase = .passthrough }
            if case .consumed = phase, event.key == 49 { result.pass = false; if !event.down { phase = .idle }; return result }
            if event.key == 49 && !event.down { phase = .idle }
            return result
        }
        switch phase {
        case .idle:
            if event.key == 49 && event.down && !event.repeated {
                spaces = [event]; phase = .pending(event.time); result.pass = false
            }
        case .pending(let start):
            if event.key == 49 {
                result.pass = false
                if !event.down {
                    result.replay = spaces + [event]; spaces.removeAll(); phase = .idle
                } else if spaces.count < 64 { spaces.append(event) }
                else { result.replay = spaces; spaces.removeAll(); phase = .passthrough; result.pass = true }
            } else if event.down && !event.repeated && bindings.contains(event.key) && event.time - start >= threshold {
                result.pass = false; result.trigger = event.key
                swallowed.insert(event.key); spaces.removeAll(); phase = .consumed
            } else if event.down {
                result.replay = spaces; spaces.removeAll(); phase = .passthrough
            }
        case .consumed:
            if event.key == 49 { result.pass = false; if !event.down { phase = .idle } }
            // One action per space hold. Other keys remain normal input.
        case .passthrough:
            if event.key == 49 && !event.down { phase = .idle }
        }
        return result
    }
    /// Called before focus changes. Do not inject delayed spaces into a different app.
    public mutating func cancelForContextChange() {
        spaces.removeAll()
        if case .pending = phase { phase = .consumed }
    }
    public mutating func reset() { phase = .idle; spaces.removeAll(); swallowed.removeAll() }
}
