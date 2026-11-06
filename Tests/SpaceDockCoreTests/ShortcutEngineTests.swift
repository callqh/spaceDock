import Foundation
import Testing
@testable import SpaceDockCore

final class ShortcutEngineTests {
    func engine() -> ShortcutEngine { var e = ShortcutEngine(); e.bindings = [13]; return e }
    @Test func testTapSpaceReplaysOneBalancedPair() {
        var e = engine()
        #expect(!(e.handle(.init(49, down: true, time: 0)).pass))
        let result = e.handle(.init(49, down: false, time: 0.1))
        #expect(result.replay.map(\.down) == [true, false]); #expect(!(result.pass))
    }
    @Test func testFastTypingDoesNotLaunchAndReplaysBeforeLetter() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0))
        let r = e.handle(.init(13, down: true, time: 0.1))
        #expect(r.pass); #expect(r.trigger == nil); #expect(r.replay.map(\.key) == [49])
        #expect(e.handle(.init(49, down: false, time: 0.15)).pass)
    }
    @Test func testLongChordConsumesBothKeyUpsRegardlessOfReleaseOrder() {
        for spaceFirst in [true, false] {
            var e = engine(); _ = e.handle(.init(49, down: true, time: 0))
            #expect(e.handle(.init(13, down: true, time: 0.21)).trigger == 13)
            let keys: [UInt16] = spaceFirst ? [49, 13] : [13, 49]
            for key in keys { #expect(!(e.handle(.init(key, down: false, time: 0.3)).pass)) }
            #expect(e.handle(.init(13, down: true, time: 0.4)).pass)
        }
    }
    @Test func testRepeatedShortcutTriggersOnlyOnce() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0)); _ = e.handle(.init(13, down: true, time: 0.25))
        let r = e.handle(.init(13, down: true, repeated: true, time: 0.5)); #expect(!(r.pass)); #expect(r.trigger == nil)
    }
    @Test func testUnknownKeyRestoresSpace() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0))
        let r = e.handle(.init(8, down: true, time: 1)); #expect(r.pass); #expect(r.replay.count == 1)
    }
    @Test func testCommandSpaceIsUntouched() {
        var e = engine(); #expect(e.handle(.init(49, down: true, modified: true, time: 0)).pass)
        #expect(e.handle(.init(49, down: false, modified: true, time: 0.1)).pass)
    }
    @Test func testModifiersCancelPendingShortcut() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0))
        let r = e.handle(.init(.max, down: true, modified: true, time: 0.2)); #expect(r.replay.count == 1)
        #expect(e.handle(.init(13, down: true, time: 0.3)).trigger == nil)
    }
    @Test func testDisablingMidChordStillConsumesCapturedKeyUp() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0)); _ = e.handle(.init(13, down: true, time: 0.3))
        #expect(!(e.handle(.init(13, down: false, time: 0.4), enabled: false).pass))
        #expect(!(e.handle(.init(49, down: false, time: 0.5), enabled: false).pass))
    }
    @Test func testFocusChangeDoesNotInjectSpaceIntoNewApp() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0)); e.cancelForContextChange()
        let r = e.handle(.init(49, down: false, time: 0.3)); #expect(!(r.pass)); #expect(r.replay.isEmpty)
    }
    @Test func testRepeatSpacesPreservedWithoutShortcut() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0)); _ = e.handle(.init(49, down: true, repeated: true, time: 0.5))
        let r = e.handle(.init(49, down: false, time: 0.6)); #expect(r.replay.count == 3); #expect(r.replay[1].repeated)
    }
    @Test func testBufferIsBoundedAndFallsBackToTyping() {
        var e = engine(); _ = e.handle(.init(49, down: true, time: 0))
        for n in 1..<64 { _ = e.handle(.init(49, down: true, repeated: true, time: Double(n))) }
        let r = e.handle(.init(49, down: true, repeated: true, time: 65)); #expect(r.pass); #expect(r.replay.count == 64)
    }
    @Test func testPausedInputPassesThrough() {
        var e = engine(); #expect(e.handle(.init(49, down: true, time: 0), enabled: false).pass)
        #expect(e.handle(.init(13, down: true, time: 0.3), enabled: false).trigger == nil)
    }
}
final class ConfigurationTests {
    @Test func testRoundTripAndDuplicateValidation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appendingPathComponent("config.json"))
        var config = Configuration(); config.bindings = [.init(name: "A", bundleIdentifier: "test.A", path: "/Applications/A.app", keyCode: 13)]
        try store.save(config); #expect(try store.load() == config)
        config.bindings.append(.init(name: "B", bundleIdentifier: "test.B", path: "/B.app", keyCode: 13))
        #expect(throws: (any Error).self) { try store.save(config) }; #expect(try store.load().bindings.count == 1)
    }
    @Test func testCorruptFileIsPreserved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("invalid json".utf8); try bytes.write(to: url)
        #expect(throws: (any Error).self) { try ConfigurationStore(url: url).load() }; #expect(try Data(contentsOf: url) == bytes)
    }
    @Test func testUnsupportedVersionRejected() { var c = Configuration(); c.schemaVersion = 99; #expect(throws: (any Error).self) { try c.validate() } }
    @Test func testLaunchGenerationAndPauseInvalidation() {
        var ledger = LaunchLedger(); let first = ledger.begin("wechat"); ledger.spaceChanged()
        #expect(ledger.crossedSpace(first)); #expect(ledger.isCurrent(first, for: "wechat"))
        let second = ledger.begin("wechat"); #expect(!(ledger.isCurrent(first, for: "wechat"))); #expect(!(ledger.crossedSpace(second)))
        ledger.invalidate(); #expect(!(ledger.isCurrent(second, for: "wechat")))
    }
}
