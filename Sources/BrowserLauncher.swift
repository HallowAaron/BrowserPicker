import AppKit

/// 把链接交给选中的浏览器。
enum BrowserLauncher {
    /// 各浏览器开启隐私/无痕窗口所用的命令行参数（Safari、Arc 等没有可用参数，不在表内）。
    private static let privateFlags: [String: String] = [
        "com.google.Chrome": "--incognito",
        "com.google.Chrome.beta": "--incognito",
        "com.google.Chrome.dev": "--incognito",
        "com.google.Chrome.canary": "--incognito",
        "org.chromium.Chromium": "--incognito",
        "com.brave.Browser": "--incognito",
        "com.brave.Browser.beta": "--incognito",
        "com.brave.Browser.nightly": "--incognito",
        "com.microsoft.edgemac": "--inprivate",
        "com.microsoft.edgemac.Beta": "--inprivate",
        "com.microsoft.edgemac.Dev": "--inprivate",
        "com.microsoft.edgemac.Canary": "--inprivate",
        "com.vivaldi.Vivaldi": "--incognito",
        "com.operasoftware.Opera": "--private",
        "org.mozilla.firefox": "--private-window",
        "org.mozilla.firefoxdeveloperedition": "--private-window",
        "org.mozilla.nightly": "--private-window"
    ]

    static func supportsPrivate(_ browserID: String) -> Bool {
        privateFlags[browserID] != nil
    }

    static func open(_ urls: [URL], with browser: Browser, privateMode: Bool = false) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if privateMode, let flag = privateFlags[browser.id] {
            // 隐私窗口只能通过命令行参数开启；
            // 需要新实例，参数才会传给浏览器（浏览器会自行转交给已运行的进程）。
            config.arguments = [flag] + urls.map { $0.absoluteString }
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: browser.url, configuration: config) { _, error in
                if let error = error {
                    NSLog("BrowserPicker: 打开失败（\(browser.name)）：\(error.localizedDescription)")
                }
            }
        } else {
            NSWorkspace.shared.open(urls, withApplicationAt: browser.url, configuration: config) { _, error in
                if let error = error {
                    NSLog("BrowserPicker: 打开失败（\(browser.name)）：\(error.localizedDescription)")
                }
            }
        }
    }
}
