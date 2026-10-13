import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var handledURL = false

    // MARK: - 生命周期

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let loginLaunch = Self.isLoginItemLaunch()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // 由点击链接启动时，系统会很快调用 application(_:open:)；
        // 如果稍后仍没有收到链接，说明是用户直接打开了 App，此时显示设置窗口。
        // 开机自启动时保持安静，只留菜单栏图标。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, !self.handledURL, !loginLaunch else { return }
            SettingsWindowController.shared.show()
        }
    }

    /// 系统把链接（或 .html 文件）交给我们：弹窗或按规则转发。
    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
        URLRouter.shared.handle(urls)
    }

    /// 用户再次点击 App 图标（Finder / Spotlight / Launchpad）时显示设置。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - 菜单栏图标

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch",
                                   accessibilityDescription: "BrowserPicker")
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.isVisible = UserDefaults.standard.bool(forKey: Preferences.Key.showMenuBarIcon)
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        if !DefaultBrowser.isDefault {
            let makeDefault = NSMenuItem(title: "设为默认浏览器…", action: #selector(makeDefault), keyEquivalent: "")
            makeDefault.target = self
            menu.addItem(makeDefault)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 BrowserPicker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func makeDefault() {
        DefaultBrowser.makeDefault()
    }

    @objc private func defaultsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.isVisible = UserDefaults.standard.bool(forKey: Preferences.Key.showMenuBarIcon)
        }
    }

    // MARK: - 辅助

    /// 通过启动 Apple Event 判断是否由“登录项”拉起。
    /// 'oapp' = kAEOpenApplication，'prdt' = keyAEPropData，'lgit' = keyAELaunchedAsLogInItem。
    private static func isLoginItemLaunch() -> Bool {
        func code(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == code("oapp")
            && event.paramDescriptor(forKeyword: code("prdt"))?.enumCodeValue == code("lgit")
    }
}
