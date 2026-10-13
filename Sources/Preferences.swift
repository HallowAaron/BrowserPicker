import Foundation

/// UserDefaults 键名与默认值。
enum Preferences {
    enum Key {
        static let applyRules = "applyRules"
        static let optionForcesPicker = "optionForcesPicker"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let rules = "rules.v1"
        static let hiddenBrowsers = "browsers.hidden"
        static let browserOrder = "browsers.order"
        static let customBrowserPaths = "browsers.custom"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.applyRules: true,          // 命中规则时直接打开，不弹窗
            Key.optionForcesPicker: true,  // 按住 ⌥ 点击链接时强制弹窗
            Key.showMenuBarIcon: true
        ])
    }
}
