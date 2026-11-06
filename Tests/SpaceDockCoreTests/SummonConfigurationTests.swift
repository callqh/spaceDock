import Foundation
import Testing
@testable import SpaceDockCore
struct SummonConfigurationTests {
    @Test func legacyBindingDoesNotEnableMovingWindows() throws {
        let data = Data(#"{"id":"871A779D-7B50-4B74-AD4E-7D71657C7023","name":"微信","bundleIdentifier":"com.tencent.xinWeChat","path":"/Applications/WeChat.app","keyCode":13,"autoHide":true}"#.utf8)
        let binding = try JSONDecoder().decode(AppBinding.self, from: data)
        #expect(binding.summonHere == nil)
    }
    @Test func summonChoiceSurvivesConfigurationRoundTrip() throws {
        var binding = AppBinding(name: "微信", bundleIdentifier: "com.tencent.xinWeChat", path: "/Applications/WeChat.app", keyCode: 13)
        binding.summonHere = true
        var config = Configuration(); config.bindings = [binding]
        let restored = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
        #expect(restored.bindings[0].summonHere == true)
    }
    @Test func obsoleteFieldsAreIgnoredAndNotWrittenBack() throws {
        let data = Data(#"{"schemaVersion":1,"bindings":[{"id":"871A779D-7B50-4B74-AD4E-7D71657C7023","name":"微信","bundleIdentifier":"com.tencent.xinWeChat","path":"/Applications/WeChat.app","keyCode":13,"autoHide":true,"summonHere":true}],"holdMilliseconds":200,"predictiveHide":true,"excludedBundleIDs":[]}"#.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        try config.validate()
        #expect(config.bindings[0].summonHere == true)
        #expect(config.bindings[0].keyCode == 13)
        let encoded = try JSONEncoder().encode(config)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let bindings = try #require(json["bindings"] as? [[String: Any]])
        #expect(json["predictiveHide"] == nil)
        #expect(bindings[0]["autoHide"] == nil)
    }

}
