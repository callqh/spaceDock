import Foundation

public struct AppBinding: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var path: String
    public var keyCode: UInt16
    public var summonHere: Bool? = nil
    public init(id: UUID = UUID(), name: String, bundleIdentifier: String, path: String, keyCode: UInt16) {
        self.id = id; self.name = name; self.bundleIdentifier = bundleIdentifier; self.path = path; self.keyCode = keyCode
    }
}
public struct Configuration: Codable, Equatable {
    public var schemaVersion = 1
    public var bindings: [AppBinding] = []
    public var holdMilliseconds = 200
    public var excludedBundleIDs: [String] = []
    public var showMenuBarIcon: Bool? = nil
    public var menuBarIconVisible: Bool { showMenuBarIcon != false }
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw ConfigError.invalid("配置版本不受支持，原文件已保留。") }
        guard (150...600).contains(holdMilliseconds) else { throw ConfigError.invalid("长按时间必须在 150–600 ms 之间。") }
        guard Set(bindings.map(\.keyCode)).count == bindings.count,
              Set(bindings.map(\.bundleIdentifier)).count == bindings.count,
              Set(bindings.map(\.id)).count == bindings.count else { throw ConfigError.invalid("配置中存在重复的应用或快捷键。") }
        guard bindings.allSatisfy({ !$0.bundleIdentifier.isEmpty && !$0.path.isEmpty && KeyMap.labels[$0.keyCode] != nil }) else { throw ConfigError.invalid("配置包含无效的应用或按键。") }
    }
}
public enum ConfigError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public struct ConfigurationStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return Configuration() }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
        try config.validate(); return config
    }
    public func save(_ config: Configuration) throws {
        try config.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }
}
public enum KeyMap {
    public static let labels: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",25:"9",26:"7",28:"8",29:"0",31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M"]
    public static var sorted: [UInt16] { labels.keys.sorted { labels[$0]! < labels[$1]! } }
}

/// Generation tickets keep stale launch completions from winning over newer requests.
public struct LaunchLedger {
    public struct Ticket: Equatable { public let sequence: Int; public let generation: Int }
    public private(set) var generation = 0
    private var sequence = 0
    private var latest: [String: Ticket] = [:]
    public init() {}
    public mutating func begin(_ bundle: String) -> Ticket {
        sequence += 1; let ticket = Ticket(sequence: sequence, generation: generation); latest[bundle] = ticket; return ticket
    }
    public func isCurrent(_ ticket: Ticket, for bundle: String) -> Bool { latest[bundle] == ticket }
    public func crossedSpace(_ ticket: Ticket) -> Bool { ticket.generation != generation }
    public mutating func spaceChanged() { generation += 1 }
    public mutating func invalidate() { latest.removeAll(); generation += 1 }
}
