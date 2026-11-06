import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model = AppModel()
    var item: NSStatusItem!
    var settings: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent two independent event taps from consuming the same space sequence.
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 { NSApp.terminate(nil); return }
        if let iconURL = Bundle.main.url(forResource: "SpaceDockPortal", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) { NSApp.applicationIconImage = icon }
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(); mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(); appMenuItem.submenu = appMenu
        let quitItem = NSMenuItem(title: "退出 SpaceDock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self; appMenu.addItem(quitItem)
        let fileMenuItem = NSMenuItem(); mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "文件"); fileMenuItem.submenu = fileMenu
        let closeItem = NSMenuItem(title: "关闭窗口", action: #selector(closeSettings), keyEquivalent: "w")
        closeItem.target = self; fileMenu.addItem(closeItem)
        NSApp.mainMenu = mainMenu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menuIcon = NSApp.applicationIconImage.copy() as! NSImage
        menuIcon.size = NSSize(width: 19, height: 19)
        menuIcon.isTemplate = false
        item.button?.image = menuIcon
        item.button?.toolTip = "SpaceDock"
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        model.onStateChanged = { [weak self] in self?.updateStatusItem() }
        updateStatusItem()
        if !model.trusted || model.config.bindings.isEmpty || ProcessInfo.processInfo.arguments.contains("--settings") { showSettings() }
    }
    private func updateStatusItem() {
        item?.isVisible = model.config.menuBarIconVisible
        item?.button?.toolTip = "SpaceDock · \(model.status)"
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "SpaceDock · \(model.status)", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        menu.addItem(.separator())
        let pause = NSMenuItem(title: model.paused ? "恢复快捷键" : "暂停快捷键", action: #selector(togglePause), keyEquivalent: ""); pause.target = self; pause.isEnabled = model.trusted; menu.addItem(pause)
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 SpaceDock", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    @objc func togglePause() { model.paused.toggle() }
    @objc func showSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 630), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "SpaceDock"; window.isReleasedWhenClosed = false; window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.closeButton)?.target = self
            window.standardWindowButton(.closeButton)?.action = #selector(closeSettings)
            window.contentView = NSHostingView(rootView: SettingsView(model: model)); window.minSize = NSSize(width: 780, height: 590); window.center(); settings = window
        }
        NSApp.activate(ignoringOtherApps: true); settings?.makeKeyAndOrderFront(nil)
    }
    @objc func closeSettings() {
        guard settings?.attachedSheet == nil else { return }
        model.recording = false
        settings?.orderOut(nil)
        NSApp.hide(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
