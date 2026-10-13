import SwiftUI

@main
struct BrowserPickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 占位场景：应用没有常规窗口。
        // 设置窗口由 SettingsWindowController 管理，选择弹窗由 PickerPanelController 管理。
        Settings { EmptyView() }
    }
}
