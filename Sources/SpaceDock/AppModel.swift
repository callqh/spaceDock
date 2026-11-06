import AppKit
import SwiftUI
import Carbon
import ServiceManagement
import UniformTypeIdentifiers
import SpaceDockCore
import SpaceDockWindowBridge

final class AppModel: ObservableObject {
    @Published private(set) var config = Configuration()
    @Published var paused = false { didSet { if paused { requestedHides.removeAll(); ledger.invalidate() }; updateKeyboard() } }
    @Published private(set) var trusted = false
    @Published private(set) var monitoring = false
    @Published private(set) var secureInput = false
    @Published var error: String?
    @Published var notice: String?
    @Published var recording = false { didSet { keyboard.contextChanged(); updateKeyboard() } }
    @Published private(set) var loginEnabled = false
    @Published private(set) var configBlocked = false
    private let keyboard = KeyboardMonitor()
    let store: ConfigurationStore
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    @Published private(set) var preparingAssignment = false
    private var ledger = LaunchLedger()
    private var requestedHides: [String: UUID] = [:]
    private var sleeping = false
    private var frontBundle: String?
    var onStateChanged: (() -> Void)?
    var status: String {
        if configBlocked { return "配置需要修复" }
        if !trusted { return "需要授权" }
        if paused { return "已暂停" }
        if secureInput { return "安全输入中" }
        if !monitoring { return "监听不可用" }
        return "已启用"
    }
    var effectiveEnabled: Bool { trusted && monitoring && !paused && !secureInput && !configBlocked && !sleeping }
    init() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SpaceDock/config.json")
        store = ConfigurationStore(url: url)
        do {
            config = try store.load()
        }
        catch { configBlocked = true; self.error = "读取配置失败，原文件已保留。\n\(error.localizedDescription)" }
        if !configBlocked && !FileManager.default.fileExists(atPath: url.path), let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.tencent.xinWeChat") {
            config.bindings = [AppBinding(name: "微信", bundleIdentifier: "com.tencent.xinWeChat", path: appURL.path, keyCode: 13)]
            do { try store.save(config) } catch { self.error = error.localizedDescription }
        }
        keyboard.onShortcut = { [weak self] key in self?.trigger(key) }
        keyboard.onFailure = { [weak self] message in self?.notice = message; self?.refreshHealth() }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.spaceChanged() })
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            self.frontBundle = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            if let id = self.frontBundle { self.requestedHides.removeValue(forKey: id) }
            self.keyboard.contextChanged(); self.updateKeyboard()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, let id = app.bundleIdentifier, app.isHidden {

                self?.requestedHides.removeValue(forKey: id)
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.sleeping = true; self?.keyboard.stop(); self?.requestedHides.removeAll(); self?.ledger.invalidate() })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.sleeping = false; self?.refreshHealth() })
        frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        refreshHealth()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshHealth() }
    }
    func refreshHealth() {
        trusted = AXIsProcessTrusted()
        let secure = IsSecureEventInputEnabled()
        if secure != secureInput { keyboard.contextChanged() }
        secureInput = secure
        if trusted && !sleeping && !configBlocked {
            if !keyboard.running { monitoring = keyboard.start() } else { monitoring = true }
        } else { keyboard.stop(); monitoring = false; requestedHides.removeAll(); ledger.invalidate() }
        loginEnabled = SMAppService.mainApp.status == .enabled
        updateKeyboard(); onStateChanged?()
    }
    private func updateKeyboard() {
        let excluded = frontBundle.map { config.excludedBundleIDs.contains($0) || $0 == Bundle.main.bundleIdentifier } ?? false
        keyboard.configure(keys: Set(config.bindings.map(\.keyCode)), delay: Double(config.holdMilliseconds) / 1000, enabled: effectiveEnabled && !recording && !excluded)
        onStateChanged?()
    }
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshHealth()
    }
    func openPermissionSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func save(_ next: Configuration) -> Bool {
        guard !configBlocked else { error = "请先修复或备份重置配置。"; return false }
        do {
            try store.save(next); config = next
            ledger.invalidate(); requestedHides.removeAll(); updateKeyboard(); notice = "更改已保存到本机"; return true
        } catch { self.error = "保存失败，设置未变更。\n\(error.localizedDescription)"; return false }
    }
    func upsert(_ binding: AppBinding) -> Bool {
        var next = config
        if next.bindings.contains(where: { $0.id != binding.id && $0.keyCode == binding.keyCode }) { error = "这个按键已分配给其他应用，请换一个键。"; return false }
        if next.bindings.contains(where: { $0.id != binding.id && $0.bundleIdentifier == binding.bundleIdentifier }) { error = "这个应用已有快捷键，请编辑原有绑定。"; return false }
        if let i = next.bindings.firstIndex(where: { $0.id == binding.id }) { next.bindings[i] = binding } else { next.bindings.append(binding) }
        return save(next)
    }
    func remove(_ binding: AppBinding) { var next = config; next.bindings.removeAll { $0.id == binding.id }; _ = save(next) }
    func setSummonHere(_ binding: AppBinding, _ value: Bool) {
        guard !preparingAssignment else { return }
        if !value { var updated = binding; updated.summonHere = false; _ = upsert(updated); return }
        preparingAssignment = true
        Task { @MainActor in
            defer { preparingAssignment = false }
            let failure = await DockAssignment.setNone(for: binding)
            guard var updated = config.bindings.first(where: { $0.id == binding.id && $0.bundleIdentifier == binding.bundleIdentifier }) else { return }
            if let failure { error = failure; return }
            updated.summonHere = true
            if upsert(updated) { notice = "已设置为在当前桌面唤起" }
        }
    }
    func setDelay(_ value: Double) { var next = config; next.holdMilliseconds = Int(value); _ = save(next) }
    func setMenuBarIconVisible(_ visible: Bool) {
        var next = config; next.showMenuBarIcon = visible; _ = save(next)
    }
    func addExcluded(_ url: URL) {
        guard let bundle = Bundle(url: url)?.bundleIdentifier else { error = "无法读取应用标识。"; return }
        var next = config; if !next.excludedBundleIDs.contains(bundle) { next.excludedBundleIDs.append(bundle); _ = save(next) }
    }
    func removeExcluded(_ id: String) { var next = config; next.excludedBundleIDs.removeAll { $0 == id }; _ = save(next) }
    func resetConfiguration() {
        do {
            if FileManager.default.fileExists(atPath: store.url.path) {
                let backup = store.url.deletingPathExtension().appendingPathExtension("backup-\(Int(Date().timeIntervalSince1970)).json")
                try FileManager.default.copyItem(at: store.url, to: backup)
            }
            let fresh = Configuration(); try store.save(fresh); config = fresh; configBlocked = false; error = nil; refreshHealth()
        } catch { self.error = "重置失败：\(error.localizedDescription)" }
    }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { notice = "请在系统设置的登录项中允许 SpaceDock。"; SMAppService.openSystemSettingsLoginItems() }
        } catch { self.error = "更改开机启动失败：\(error.localizedDescription)" }
    }
    func trigger(_ key: UInt16) {

        guard effectiveEnabled, !recording, frontBundle != Bundle.main.bundleIdentifier, !config.excludedBundleIDs.contains(frontBundle ?? ""), let binding = config.bindings.first(where: { $0.keyCode == key }) else { return }
        let id = binding.bundleIdentifier
        requestedHides.removeValue(forKey: id)
        let ticket = ledger.begin(id)
        let targetSpace = binding.summonHere == true ? SDWindowMover.currentSpace() : nil
        if binding.summonHere == true && targetSpace == nil {
            notice = "当前桌面不支持窗口搬移；请在普通桌面重试。"; return
        }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first, app.isActive, SDWindowMover.mainWindowIsVisible(forPID: app.processIdentifier), targetSpace == nil || SDWindowMover.mainWindow(forPID: app.processIdentifier, isOnSpace: targetSpace!.uint64Value) {
            requestHide(app)
            return
        }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) ?? URL(fileURLWithPath: binding.path)
        guard FileManager.default.fileExists(atPath: url.path) else { error = "找不到\(binding.name)，请重新选择应用。"; return }
        // Launch without activation first, so a stale completion cannot steal focus.
        let options = NSWorkspace.OpenConfiguration(); options.activates = false
        let handleApplication: (NSRunningApplication?, Error?) -> Void = { [weak self] app, failure in
            DispatchQueue.main.async {
                guard let self, self.ledger.isCurrent(ticket, for: id), self.effectiveEnabled else { return }
                guard let app, failure == nil else { self.error = "无法打开\(binding.name)：\(failure?.localizedDescription ?? "未知错误")"; return }
                let activate = { [weak self] in
                    guard let self, self.ledger.isCurrent(ticket, for: id), self.effectiveEnabled else { return }
                    if let targetSpace {
                        guard !self.ledger.crossedSpace(ticket), SDWindowMover.currentSpace() == targetSpace,
                              SDWindowMover.mainWindow(forPID: app.processIdentifier, isOnSpace: targetSpace.uint64Value) else { return }
                    }
                    // Reopen like a Dock click, after any required move has been verified.
                    // Activating a process alone does not restore a closed/minimized window.
                    let show = NSWorkspace.OpenConfiguration(); show.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: show) { [weak self] reopened, failure in
                        DispatchQueue.main.async {
                            guard let self, self.ledger.isCurrent(ticket, for: id), self.effectiveEnabled else { return }
                            if let failure {
                                self.error = "无法显示\(binding.name)：\(failure.localizedDescription)"
                                return
                            }
                            reopened?.unhide()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        guard let self, self.ledger.isCurrent(ticket, for: id) else { return }
                        if !app.isActive || !SDWindowMover.mainWindowIsVisible(forPID: app.processIdentifier) {
                            self.notice = "尚未确认\(binding.name)的窗口已显示，请再次按快捷键。"
                        }
                    }
                }
                if let targetSpace {
                    guard !self.ledger.crossedSpace(ticket), SDWindowMover.currentSpace() == targetSpace else { return }
                    SDWindowMover.moveMainWindow(forPID: app.processIdentifier, toSpace: targetSpace.uint64Value, isCurrent: { [weak self] in
                        guard let self else { return false }
                        return self.effectiveEnabled && self.ledger.isCurrent(ticket, for: id) && !self.ledger.crossedSpace(ticket)
                    }, completion: { [weak self] failure in
                        guard let self, self.ledger.isCurrent(ticket, for: id), !self.ledger.crossedSpace(ticket) else { return }
                        if let failure { self.notice = failure; return }
                        activate()
                    })
                } else { activate() }
            }
        }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
            handleApplication(running, nil)
        } else {
            NSWorkspace.shared.openApplication(at: url, configuration: options, completionHandler: handleApplication)
        }
    }

    private func spaceChanged() {

        ledger.spaceChanged(); keyboard.contextChanged()
    }
    private func requestHide(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, requestedHides[id] == nil else { return }
        if app.isHidden || app.isTerminated { return }
        let request = UUID()
        requestedHides[id] = request
        // On this macOS build hide() can return false even when hiding succeeds.
        // Send immediately; defer only the failure message, never the hide itself.
        _ = app.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.requestedHides[id] == request else { return }
            self.requestedHides.removeValue(forKey: id)
            if !app.isHidden && !app.isTerminated && self.effectiveEnabled {
                self.notice = "尚未确认\(app.localizedName ?? id)已隐藏，可再次按快捷键重试。"
            }
        }
    }
    func shutdown() { timer?.invalidate(); keyboard.stop(); observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) } }
}
