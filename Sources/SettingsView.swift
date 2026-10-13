import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 窗口控制器

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private init() {}

    private var window: NSWindow?

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: controller)
            window.title = "BrowserPicker 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 设置主视图

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gearshape") }
            BrowsersTab()
                .tabItem { Label("浏览器", systemImage: "globe") }
            RulesTab()
                .tabItem { Label("规则", systemImage: "list.bullet.rectangle") }
        }
        .padding(20)
        .frame(width: 680, height: 500)
    }
}

// MARK: - 通用

struct GeneralTab: View {
    @AppStorage(Preferences.Key.applyRules) private var applyRules = true
    @AppStorage(Preferences.Key.optionForcesPicker) private var optionForcesPicker = true
    @AppStorage(Preferences.Key.showMenuBarIcon) private var showMenuBarIcon = true

    @State private var isDefault = DefaultBrowser.isDefault
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "BrowserPicker v\(version)"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: isDefault ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(isDefault ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDefault ? "已是默认浏览器" : "尚未设为默认浏览器")
                            .font(.headline)
                        Text(isDefault
                             ? "所有 http / https 链接都会先经过 BrowserPicker。"
                             : "设为默认浏览器后，点击任何链接才会弹出选择框。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isDefault {
                        Button("设为默认浏览器…") {
                            DefaultBrowser.makeDefault { isDefault = DefaultBrowser.isDefault }
                        }
                    }
                }
            }

            Section("行为") {
                Toggle("自动应用域名规则（命中规则时不弹窗）", isOn: $applyRules)
                Toggle("按住 ⌥ Option 点击链接时，忽略规则并强制弹窗", isOn: $optionForcesPicker)
            }

            Section("应用") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        do {
                            try LaunchAtLogin.set(newValue)
                            launchAtLogin = newValue
                            loginError = nil
                        } catch {
                            launchAtLogin = LaunchAtLogin.isEnabled
                            loginError = "无法更改开机启动：\(error.localizedDescription)"
                        }
                    }
                ))
                if let loginError = loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("在菜单栏显示图标", isOn: $showMenuBarIcon)
                if !showMenuBarIcon {
                    Text("隐藏后，可再次打开 BrowserPicker 应用来进入设置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(versionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isDefault = DefaultBrowser.isDefault
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

// MARK: - 浏览器

struct BrowsersTab: View {
    @ObservedObject private var store = BrowserStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("拖动行可调整弹窗中的顺序（前 9 个对应数字键 1–9）；取消勾选即可在弹窗中隐藏。")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.all) { browser in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { !store.hiddenIDs.contains(browser.id) },
                            set: { store.setHidden(!$0, for: browser.id) }
                        ))
                        .labelsHidden()

                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(browser.name)
                            Text(browser.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if BrowserLauncher.supportsPrivate(browser.id) {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(.secondary)
                                .help("支持隐私窗口")
                        }
                        if browser.isCustom {
                            Button {
                                store.removeCustom(id: browser.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("移除手动添加的应用")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack {
                Button("添加应用…", action: addApp)
                Button("重新扫描") { store.refresh() }
                Spacer()
            }
        }
        .padding(.top, 8)
        .onAppear { store.refresh() }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "选择要加入列表的应用"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            store.addCustom(url)
        }
    }
}

// MARK: - 规则

struct RulesTab: View {
    @ObservedObject private var ruleStore = RuleStore.shared
    @ObservedObject private var browserStore = BrowserStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("规则从上到下匹配，命中第一条后直接用对应浏览器打开，不再弹窗。域名默认包含所有子域名。")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach($ruleStore.rules) { $rule in
                    RuleRow(
                        rule: $rule,
                        browsers: browserStore.all,
                        onDelete: { ruleStore.rules.removeAll { $0.id == rule.id } }
                    )
                }
                .onMove { source, destination in
                    ruleStore.rules.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if ruleStore.rules.isEmpty {
                    Text("还没有规则。\n点击下方“添加规则”，或在弹窗里右键某个浏览器快速创建。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    let first = browserStore.visible.first?.id ?? browserStore.all.first?.id ?? ""
                    ruleStore.rules.append(Rule(browserID: first))
                } label: {
                    Label("添加规则", systemImage: "plus")
                }
                Spacer()
            }
        }
        .padding(.top, 8)
        .onAppear { browserStore.refresh() }
    }
}

struct RuleRow: View {
    @Binding var rule: Rule
    let browsers: [Browser]
    let onDelete: () -> Void

    private var isMissing: Bool {
        !browsers.contains { $0.id == rule.browserID }
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("域名，例如 github.com", text: $rule.pattern)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 170)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("", selection: $rule.browserID) {
                ForEach(browsers) { browser in
                    Text(browser.name).tag(browser.id)
                }
                if isMissing {
                    Text(rule.browserID.isEmpty ? "选择浏览器" : "未安装：\(rule.browserID)")
                        .tag(rule.browserID)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Toggle("仅此域名", isOn: $rule.exactHost)
                .toggleStyle(.checkbox)
            Toggle("隐私窗口", isOn: $rule.privateMode)
                .toggleStyle(.checkbox)

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("删除此规则")
        }
        .padding(.vertical, 2)
    }
}
