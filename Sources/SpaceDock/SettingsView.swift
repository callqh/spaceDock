import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpaceDockCore

private enum Page: String, CaseIterable, Identifiable {
    case bindings = "应用快捷键", preferences = "偏好设置"
    var id: String { rawValue }
    var symbol: String { switch self { case .bindings: return "command"; case .preferences: return "gearshape" } }
    var tint: Color { switch self { case .bindings: return .blue; case .preferences: return .gray } }
}
struct MaterialSidebar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .sidebar; view.blendingMode = .behindWindow; view.state = .followsWindowActiveState; return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var page: Page = .bindings
    @State private var editor: AppBinding?
    @State private var showEditor = false
    @State private var resetConfirm = false
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) { icon("space", .blue, size: 29); Text("SpaceDock").font(.system(size: 13, weight: .semibold)) }.padding(.bottom, 22).padding(.horizontal, 8)
                ForEach(Page.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 8) { icon(item.symbol, item.tint, size: 23); Text(item.rawValue).font(.system(size: 13)); Spacer() }.padding(.horizontal, 8).padding(.vertical, 7).contentShape(Rectangle())
                    }.buttonStyle(.plain).background(page == item ? Color.primary.opacity(0.08) : Color.clear).cornerRadius(7)
                }
                Spacer()
                HStack(spacing: 6) { Circle().fill(model.effectiveEnabled ? Color.green : Color.orange).frame(width: 6, height: 6); Text(model.status).font(.system(size: 12)) }
                Button(model.paused ? "恢复快捷键" : "暂停快捷键") { model.paused.toggle() }.buttonStyle(.link).font(.system(size: 12)).disabled(!model.trusted || model.configBlocked)
            }.padding(.horizontal, 12).padding(.vertical, 20).frame(width: 184).background(MaterialSidebar())
            Divider()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) { icon(page.symbol, page.tint, size: 48); VStack(alignment: .leading, spacing: 4) { Text(page.rawValue).font(.system(size: 20, weight: .semibold)); Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) } }
                        if model.configBlocked { configurationWarning }
                        if !model.trusted { permissionBanner }
                        if let error = model.error {
                            HStack(alignment: .top) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(error).font(.system(size: 12)).textSelection(.enabled); Spacer(); Button { model.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("关闭错误提示") }.padding(12).background(Color.orange.opacity(0.09)).cornerRadius(9)
                        }
                        switch page { case .bindings: bindingsPage; case .preferences: preferencesPage }
                    }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack { Text("配置仅保存在本机"); Spacer(); Text(model.notice ?? "SpaceDock 1.0") }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
            }.background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 760, minHeight: 560)
        .sheet(isPresented: $showEditor, onDismiss: { model.recording = false }) { BindingEditor(model: model, original: editor).onAppear { model.recording = true } }
        .alert("备份并重置配置？", isPresented: $resetConfirm) { Button("取消", role: .cancel) {}; Button("备份并重置", role: .destructive) { model.resetConfiguration() } } message: { Text("会保留原文件副本，然后建立空配置。") }
    }
    var subtitle: String { switch page { case .bindings: return "设置用于打开和切换应用的快捷键。"; case .preferences: return "调到适合你的打字节奏。" } }
    private var configurationWarning: some View {
        group { VStack(alignment: .leading, spacing: 10) { Text("配置文件需要修复").fontWeight(.semibold); Text("为保护已有配置，暂时停用快捷键和设置保存。").font(.caption); HStack { Button("查看配置文件") { NSWorkspace.shared.activateFileViewerSelecting([model.store.url]) }; Button("备份并重置…") { resetConfirm = true } } } }
    }
    private var permissionBanner: some View {
        group { VStack(alignment: .leading, spacing: 10) {
            Label("允许 SpaceDock 识别快捷键", systemImage: "hand.raised.fill").fontWeight(.semibold)
            Text("在辅助功能中开启 SpaceDock。只识别配置的按键，不保存输入内容。").font(.system(size: 12)).foregroundStyle(.secondary)
            HStack { Button("授权辅助功能") { model.requestPermission() }.buttonStyle(.borderedProminent); Button("打开系统设置") { model.openPermissionSettings() }; Button("重新检查") { model.refreshHealth() } }
        } }
    }
    private var bindingsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            group { HStack(spacing: 18) { HStack(spacing: 6) { keycap("space"); Text("+").foregroundStyle(.secondary); keycap(model.config.bindings.first.flatMap { KeyMap.labels[$0.keyCode] } ?? "W") }; VStack(alignment: .leading, spacing: 3) { Text("按住空格，再按一个键").font(.system(size: 12, weight: .medium)); Text("再按一次，隐藏当前应用。").font(.system(size: 11)).foregroundStyle(.secondary) } } }
            VStack(spacing: 0) {
                HStack { Text("我的应用").fontWeight(.semibold); Text("\(model.config.bindings.count)").foregroundStyle(.secondary); Spacer(); Button { editor = nil; showEditor = true } label: { Label("添加应用", systemImage: "plus") }.buttonStyle(.borderedProminent).disabled(model.configBlocked) }.padding(14)
                Divider().padding(.horizontal, 14)
                if model.config.bindings.isEmpty {
                    VStack(spacing: 10) { Image(systemName: "space").font(.system(size: 30)).foregroundStyle(.secondary); Text("给常用应用留一个键"); Text("添加后，按住空格就能随时叫出它。").font(.caption).foregroundStyle(.secondary) }.padding(28).frame(maxWidth: .infinity)
                } else {
                    HStack { Text("应用"); Spacer(); Text("快捷键").frame(width: 112, alignment: .leading); Text("在当前桌面唤起").frame(width: 118) }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.top, 10)
                    ForEach(model.config.bindings) { binding in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: binding.path)).resizable().frame(width: 30, height: 30)
                            Text(binding.name).lineLimit(2); Spacer(minLength: 5)
                            HStack(spacing: 5) { keycap("space"); Text("+").font(.caption).foregroundStyle(.secondary); keycap(KeyMap.labels[binding.keyCode] ?? "?") }.frame(width: 112, alignment: .leading)
                            Toggle("在当前桌面唤起\(binding.name)", isOn: Binding(get: { binding.summonHere == true }, set: { model.setSummonHere(binding, $0) })).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(model.preparingAssignment || model.configBlocked)
                            Menu { Button("编辑快捷键…") { editor = binding; showEditor = true }; Button("移除绑定", role: .destructive) { model.remove(binding) } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22).accessibilityLabel("\(binding.name)更多操作")
                        }.padding(.horizontal, 14).frame(minHeight: 64)
                        if binding.id != model.config.bindings.last?.id { Divider().padding(.horizontal, 14) }
                    }
                }
            }.background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
            Text(model.preparingAssignment ? "正在设置应用的桌面分配…" : "开启后，主窗口会来到当前普通桌面，切走时留在原处。开启时会尝试将 Dock 的“分配给”设为“无”。全屏窗口暂不支持。")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            group { HStack(spacing: 12) { icon("space", .orange, size: 28); VStack(alignment: .leading, spacing: 3) { Text("输入不受打扰").font(.system(size: 12, weight: .medium)); Text("短按输入空格。快速输入时不触发应用快捷键。").font(.system(size: 11)).foregroundStyle(.secondary) } } }.padding(.top, 10)
        }.font(.system(size: 13))
    }
    private var preferencesPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            group { VStack(alignment: .leading, spacing: 12) { HStack { Text("长按空格的等待时间").fontWeight(.medium); Spacer(); Text("\(model.config.holdMilliseconds) ms").monospacedDigit().foregroundStyle(.secondary) }; Slider(value: Binding(get: { Double(model.config.holdMilliseconds) }, set: { model.setDelay($0) }), in: 150...600, step: 50); HStack { Text("更快唤起"); Spacer(); Text("更少误触") }.font(.caption).foregroundStyle(.secondary) } }
            Text("按键按物理键位识别；非美式键盘请使用录入按钮。单独长按空格的重复输入会在松开时补发。").font(.system(size: 11)).foregroundStyle(.secondary)
            group { Toggle("登录时启动 SpaceDock", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).toggleStyle(.switch).controlSize(.small) }
            group { VStack(alignment: .leading, spacing: 10) { HStack { Text("辅助功能权限").fontWeight(.medium); Spacer(); Text(model.trusted ? "已授权" : "未授权").foregroundStyle(.secondary) }; Text(model.monitoring ? "键盘监听正常。" : "监听未启用；授权后点击重新检查。").font(.caption).foregroundStyle(.secondary); HStack { Button("打开系统设置") { model.openPermissionSettings() }; Button("重新检查") { model.refreshHealth() } }; if model.secureInput { Text("系统正在使用安全输入，快捷键暂时透传。").font(.caption).foregroundStyle(.orange) } } }
            group { VStack(alignment: .leading, spacing: 12) { HStack { Text("在这些应用中暂停快捷键").fontWeight(.medium); Spacer(); Button("添加…") { if let url = selectApplication() { model.addExcluded(url) } } }; ForEach(model.config.excludedBundleIDs, id: \.self) { id in HStack { Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { FileManager.default.displayName(atPath: $0.path) } ?? id).lineLimit(2); Spacer(); Button { model.removeExcluded(id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("移除排除应用\(id)") } }; if model.config.excludedBundleIDs.isEmpty { Text("可添加游戏、远程桌面等应用。").font(.caption).foregroundStyle(.secondary) } } }
            Button("在访达中显示配置") { NSWorkspace.shared.selectFile(model.store.url.path, inFileViewerRootedAtPath: model.store.url.deletingLastPathComponent().path) }
        }.font(.system(size: 13))
    }

}
private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content().frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
}
private func icon(_ symbol: String, _ color: Color, size: CGFloat) -> some View {
    Image(systemName: symbol).font(.system(size: size * 0.60, weight: .medium)).foregroundStyle(.white).frame(width: size, height: size).background(color).cornerRadius(size * 0.24)
}
private func keycap(_ label: String) -> some View {
    Text(label).font(.system(size: 11, design: .monospaced)).padding(.horizontal, 7).frame(minWidth: 24, minHeight: 24).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.7)))
}
func selectApplication() -> URL? {
    let panel = NSOpenPanel(); panel.title = "选择应用"; panel.prompt = "选择"; panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
}
struct BindingEditor: View {
    @ObservedObject var model: AppModel
    let original: AppBinding?
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var key: UInt16 = 13
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(original == nil ? "添加应用" : "编辑快捷键").font(.system(size: 20, weight: .semibold))
            Text("选择应用，为它分配一个按键。").font(.system(size: 12)).foregroundStyle(.secondary)
            HStack { if let url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 32, height: 32); Text(FileManager.default.displayName(atPath: url.path)).lineLimit(2) } else { Text("尚未选择应用").foregroundStyle(.secondary) }; Spacer(); Button("选择应用…") { if let selected = selectApplication() { url = selected } } }
            HStack(spacing: 10) { Text("快捷键"); Spacer(); keycap("space"); Text("+"); KeyRecorder(key: $key).frame(width: 110, height: 30) }
            Text("点击按键框，再按一个字母或数字。Esc 取消录入。").font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).foregroundStyle(.red).font(.caption) }
            HStack { Spacer(); Button("取消") { dismiss() }.keyboardShortcut(.cancelAction); Button("保存快捷键") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(url == nil) }
        }.padding(24).frame(width: 420).onAppear { if let original { url = URL(fileURLWithPath: original.path); key = original.keyCode } }
    }
    private func save() {
        guard let url, let id = Bundle(url: url)?.bundleIdentifier else { message = "无法读取应用，请重新选择。"; return }
        guard id != Bundle.main.bundleIdentifier else { message = "不能为 SpaceDock 自身设置启动快捷键。"; return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        var binding = AppBinding(id: original?.id ?? UUID(), name: name, bundleIdentifier: id, path: url.path, keyCode: key)
        binding.summonHere = original?.bundleIdentifier == id ? original?.summonHere : false
        if model.upsert(binding) { dismiss() } else { message = model.error }
    }
}
struct KeyRecorder: NSViewRepresentable {
    @Binding var key: UInt16
    func makeNSView(context: Context) -> RecorderButton { let button = RecorderButton(); button.bezelStyle = .rounded; button.onKey = { key = $0 }; return button }
    func updateNSView(_ button: RecorderButton, context: Context) { button.onKey = { key = $0 }; if !button.recording { button.title = "\(KeyMap.labels[key] ?? "?")  · 点击录入" } }
}
final class RecorderButton: NSButton {
    var onKey: ((UInt16) -> Void)?
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { recording = true; title = "请按一个键…"; window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { recording = false; title = "点击录入"; window?.makeFirstResponder(nil); return }
        if !recording { recording = true; title = "请按一个键…"; return }
        guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty, let label = KeyMap.labels[event.keyCode] else { NSSound.beep(); return }
        onKey?(event.keyCode); recording = false; title = "\(label)  · 点击录入"; window?.makeFirstResponder(nil)
    }
}
