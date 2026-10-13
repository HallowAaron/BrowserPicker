import AppKit
import ServiceManagement

/// 默认浏览器的查询与设置。
enum DefaultBrowser {
    private static let probe = URL(string: "https://example.com")!

    static var isDefault: Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe),
              let id = Bundle(url: appURL)?.bundleIdentifier else { return false }
        return id == Bundle.main.bundleIdentifier
    }

    /// 系统会弹出确认框，由用户最终决定。
    static func makeDefault(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        for scheme in ["http", "https"] {
            group.enter()
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL,
                                                     toOpenURLsWithScheme: scheme) { error in
                if let error = error {
                    NSLog("BrowserPicker: 设置默认浏览器失败（\(scheme)）：\(error.localizedDescription)")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion?() }
    }
}

/// 开机自启动（macOS 13+，需要 App 位于 /Applications 并正常签名）。
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
