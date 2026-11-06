import AppKit
import ApplicationServices
import SpaceDockCore

/// Uses the application's own Dock menu; never edits the Dock plist or restarts Dock.
@MainActor
enum DockAssignment {
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func find(_ root: AXUIElement, depth: Int = 5, matching: (AXUIElement) -> Bool) -> AXUIElement? {
        if matching(root) { return root }
        guard depth > 0 else { return nil }
        for child in children(root) {
            if let result = find(child, depth: depth - 1, matching: matching) { return result }
        }
        return nil
    }

    private static func menuItem(_ root: AXUIElement, titles: Set<String>) -> AXUIElement? {
        find(root) {
            (attribute($0, kAXRoleAttribute) as? String) == kAXMenuItemRole &&
            titles.contains(attribute($0, kAXTitleAttribute) as? String ?? "")
        }
    }

    private static func checked(_ item: AXUIElement) -> Bool {
        !(attribute(item, kAXMenuItemMarkCharAttribute) as? String ?? "").isEmpty
    }

    // Read only: a missing app entry in a successfully loaded assignment dictionary
    // means None. A missing/unreadable dictionary is unknown, not success.
    private static func hasNoAssignment(_ bundleID: String) -> Bool {
        let domain = "com.apple.spaces" as CFString
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard let bindings = CFPreferencesCopyValue("app-bindings" as CFString, domain,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] else { return false }
        return bindings[bundleID] == nil
    }

    static func setNone(for binding: AppBinding) async -> String? {
        let guidance = "请在 Dock 中右键点击\(binding.name)，选择“选项 → 分配给 → 无”，然后重新开启此开关。"
        if hasNoAssignment(binding.bundleIdentifier) { return nil }
        guard AXIsProcessTrusted() else { return "请先授权辅助功能。\n" + guidance }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return "无法连接 Dock。\n" + guidance
        }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let path = (NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.bundleIdentifier) ?? URL(fileURLWithPath: binding.path)).standardizedFileURL.path
        guard let appItem = find(root, matching: { element in
            guard (attribute(element, kAXSubroleAttribute) as? String) == "AXApplicationDockItem",
                  let url = attribute(element, kAXURLAttribute) as? URL else { return false }
            return url.standardizedFileURL.path == path
        }) else { return "未找到\(binding.name)的 Dock 图标，请先打开该应用。\n" + guidance }
        guard AXUIElementPerformAction(appItem, kAXShowMenuAction as CFString) == .success else {
            return "系统未允许打开应用的 Dock 菜单。\n" + guidance
        }
        // Close only the menu opened by this operation, including on unsupported languages.
        defer {
            if let menu = find(appItem, matching: { (attribute($0, kAXRoleAttribute) as? String) == kAXMenuRole }) {
                AXUIElementPerformAction(menu, kAXCancelAction as CFString)
            }
        }
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let options = menuItem(appItem, titles: ["选项", "選項", "Options"]) else { continue }
            if let none = menuItem(options, titles: ["无", "無", "None"]) {
                if checked(none) { return nil }
                guard AXUIElementPerformAction(none, kAXPressAction as CFString) == .success else { break }
                // Reopen and verify the checkmark; an accepted AX action alone is not success.
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard AXUIElementPerformAction(appItem, kAXShowMenuAction as CFString) == .success else { break }
                for _ in 0..<8 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if hasNoAssignment(binding.bundleIdentifier) { return nil }
                    if let options = menuItem(appItem, titles: ["选项", "選項", "Options"]) {
                        if let none = menuItem(options, titles: ["无", "無", "None"]), checked(none) { return nil }
                        AXUIElementPerformAction(options, kAXPressAction as CFString)
                    }
                }
                break
            }
            AXUIElementPerformAction(options, kAXPressAction as CFString)
        }
        return "未能确认桌面分配已设为“无”，开关尚未开启。\n" + guidance
    }
}
