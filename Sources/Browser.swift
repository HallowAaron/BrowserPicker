import AppKit
import SwiftUI

/// 一个可用于打开链接的浏览器（或任何声明可处理 http/https 的应用）。
struct Browser: Identifiable, Hashable {
    let id: String          // bundle identifier
    let name: String
    let url: URL            // .app 的路径
    let icon: NSImage
    let isCustom: Bool      // 用户手动添加

    init?(appURL: URL, isCustom: Bool = false) {
        guard let bundle = Bundle(url: appURL),
              let bundleID = bundle.bundleIdentifier else { return nil }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 64, height: 64)

        self.id = bundleID
        self.name = displayName
        self.url = appURL
        self.icon = image
        self.isCustom = isCustom
    }

    static func == (lhs: Browser, rhs: Browser) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 已安装浏览器的列表、排序、隐藏与手动添加。
final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()

    /// 全部浏览器（已按用户顺序排序，包含被隐藏的）
    @Published private(set) var all: [Browser] = []
    @Published private(set) var hiddenIDs: Set<String>
    @Published private(set) var order: [String]
    @Published private(set) var customPaths: [String]

    private init() {
        let defaults = UserDefaults.standard
        self.hiddenIDs = Set(defaults.stringArray(forKey: Preferences.Key.hiddenBrowsers) ?? [])
        self.order = defaults.stringArray(forKey: Preferences.Key.browserOrder) ?? []
        self.customPaths = defaults.stringArray(forKey: Preferences.Key.customBrowserPaths) ?? []
        refresh()
    }

    /// 弹窗里显示的浏览器
    var visible: [Browser] {
        all.filter { !hiddenIDs.contains($0.id) }
    }

    func browser(withID id: String) -> Browser? {
        all.first { $0.id == id }
    }

    // MARK: - 刷新

    /// 重新扫描系统中声明可打开 https 链接的应用，并合并用户手动添加的应用。
    func refresh() {
        let myID = Bundle.main.bundleIdentifier
        let probe = URL(string: "https://example.com")!
        var found: [String: Browser] = [:]

        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            // 必须排除自己，否则选中后链接又会回到本 App，形成死循环
            guard let browser = Browser(appURL: appURL),
                  browser.id != myID,
                  found[browser.id] == nil else { continue }
            found[browser.id] = browser
        }

        for path in customPaths {
            guard let browser = Browser(appURL: URL(fileURLWithPath: path), isCustom: true),
                  browser.id != myID,
                  found[browser.id] == nil else { continue }
            found[browser.id] = browser
        }

        let order = self.order
        all = found.values.sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.id) ?? Int.max
            let r = order.firstIndex(of: rhs.id) ?? Int.max
            if l != r { return l < r }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - 修改

    func setHidden(_ hidden: Bool, for id: String) {
        if hidden { hiddenIDs.insert(id) } else { hiddenIDs.remove(id) }
        UserDefaults.standard.set(Array(hiddenIDs), forKey: Preferences.Key.hiddenBrowsers)
    }

    func move(from source: IndexSet, to destination: Int) {
        var ids = all.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        order = ids
        UserDefaults.standard.set(ids, forKey: Preferences.Key.browserOrder)
        refresh()
    }

    func addCustom(_ appURL: URL) {
        let path = appURL.path
        guard !customPaths.contains(path) else { return }
        customPaths.append(path)
        UserDefaults.standard.set(customPaths, forKey: Preferences.Key.customBrowserPaths)
        refresh()
    }

    func removeCustom(id: String) {
        guard let path = all.first(where: { $0.id == id && $0.isCustom })?.url.path else { return }
        customPaths.removeAll { $0 == path }
        UserDefaults.standard.set(customPaths, forKey: Preferences.Key.customBrowserPaths)
        refresh()
    }
}
