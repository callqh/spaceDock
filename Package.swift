// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "SpaceDock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SpaceDock", targets: ["SpaceDock"])],
    targets: [
        .target(name: "SpaceDockCore"),
        .target(name: "SpaceDockWindowBridge", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-fobjc-arc"])], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ApplicationServices")]),
        .executableTarget(name: "SpaceDock", dependencies: ["SpaceDockCore", "SpaceDockWindowBridge"]),
        .testTarget(name: "SpaceDockCoreTests", dependencies: ["SpaceDockCore"])
    ]
)
