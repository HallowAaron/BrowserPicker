import AppKit

/// 收到链接后的决策：命中规则就直接打开，否则弹出选择面板。
final class URLRouter {
    static let shared = URLRouter()
    private init() {}

    func handle(_ incoming: [URL]) {
        let urls = incoming.filter { ["http", "https", "file"].contains($0.scheme?.lowercased() ?? "") }
        guard !urls.isEmpty else { return }

        let defaults = UserDefaults.standard
        let store = BrowserStore.shared
        store.refresh()   // 应用可能刚安装或卸载

        // 按住 ⌥ 点击链接：忽略规则，强制弹窗
        let forcePicker = defaults.bool(forKey: Preferences.Key.optionForcesPicker)
            && NSEvent.modifierFlags.contains(.option)

        if urls.count == 1,
           defaults.bool(forKey: Preferences.Key.applyRules),
           !forcePicker,
           let rule = RuleStore.shared.rule(for: urls[0]),
           let browser = store.browser(withID: rule.browserID) {
            BrowserLauncher.open(urls, with: browser, privateMode: rule.privateMode)
            return
        }

        let candidates = store.visible
        guard !candidates.isEmpty else {
            showNoBrowserAlert()
            return
        }
        PickerPanelController.shared.present(urls: urls, browsers: candidates)
    }

    private func showNoBrowserAlert() {
        let alert = NSAlert()
        alert.messageText = "没有可用的浏览器"
        alert.informativeText = "请在设置的“浏览器”页检查是否隐藏了全部浏览器，或点击“添加应用…”手动添加。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowController.shared.show()
        }
    }
}
