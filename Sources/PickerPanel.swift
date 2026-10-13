import AppKit
import SwiftUI

// MARK: - 布局

struct PickerLayout {
    static let cellWidth: CGFloat = 84
    static let cellHeight: CGFloat = 80
    static let minColumns = 4
    static let maxColumns = 6

    let columns: Int
    let rows: Int

    init(count: Int) {
        let cols = min(max(count, PickerLayout.minColumns), PickerLayout.maxColumns)
        self.columns = cols
        self.rows = max(1, Int(ceil(Double(count) / Double(cols))))
    }

    var width: CGFloat {
        CGFloat(columns) * PickerLayout.cellWidth + 32
    }

    var height: CGFloat {
        let grid = CGFloat(rows) * PickerLayout.cellHeight + CGFloat(rows - 1) * 4
        // 上下内边距 32 + 标题栏 36 + 间距 10 + 网格 + 间距 10 + 页脚 14
        return 32 + 36 + 10 + grid + 10 + 14
    }
}

// MARK: - 面板

final class PickerPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onResign: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {        // Esc
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func resignKey() {
        super.resignKey()
        onResign?()
    }
}

// MARK: - 控制器

final class PickerPanelController {
    static let shared = PickerPanelController()
    private init() {}

    private var panel: PickerPanel?
    private var previousApp: NSRunningApplication?

    func present(urls: [URL], browsers: [Browser]) {
        dismiss(restoreFocus: false)

        let front = NSWorkspace.shared.frontmostApplication
        previousApp = (front?.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : front

        let layout = PickerLayout(count: browsers.count)
        let size = NSSize(width: layout.width, height: layout.height)

        let view = PickerView(
            urls: urls,
            browsers: browsers,
            layout: layout,
            onPick: { [weak self] browser, privateMode in
                self?.dismiss(restoreFocus: false)
                BrowserLauncher.open(urls, with: browser, privateMode: privateMode)
            },
            onCancel: { [weak self] in
                self?.dismiss(restoreFocus: true)
            }
        )

        let panel = PickerPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onCancel = { [weak self] in self?.dismiss(restoreFocus: true) }
        panel.onResign = { [weak self] in self?.dismiss(restoreFocus: false) }   // 点击别处时自动关闭
        panel.setFrameOrigin(origin(for: size))

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss(restoreFocus: Bool) {
        guard let panel = panel else { return }
        self.panel = nil
        panel.onCancel = nil
        panel.onResign = nil
        panel.orderOut(nil)
        if restoreFocus {
            previousApp?.activate(options: [])
        }
        previousApp = nil
    }

    /// 面板出现在鼠标下方；靠近屏幕边缘时自动调整。
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = mouse.x - size.width / 2
        var y = mouse.y - size.height - 16
        if y < area.minY + 8 { y = mouse.y + 16 }

        x = min(max(x, area.minX + 8), area.maxX - size.width - 8)
        y = min(max(y, area.minY + 8), area.maxY - size.height - 8)
        return NSPoint(x: x, y: y)
    }
}

// MARK: - 视图

struct PickerView: View {
    let urls: [URL]
    let browsers: [Browser]
    let layout: PickerLayout
    let onPick: (Browser, Bool) -> Void
    let onCancel: () -> Void

    @State private var privateMode = false
    @State private var copied = false

    private var host: String? {
        urls.count == 1 ? urls[0].host?.lowercased() : nil
    }

    private var primaryTitle: String {
        if urls.count > 1 { return "\(urls.count) 个链接" }
        guard let url = urls.first else { return "" }
        if url.isFileURL { return url.lastPathComponent }
        return url.host ?? url.absoluteString
    }

    private var secondaryTitle: String {
        guard let url = urls.first else { return "" }
        return url.isFileURL ? url.path : url.absoluteString
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(PickerLayout.cellWidth), spacing: 0),
                               count: layout.columns),
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                    BrowserCell(
                        browser: browser,
                        index: index,
                        privateMode: privateMode,
                        host: host,
                        onSelect: { shiftHeld in onPick(browser, privateMode || shiftHeld) },
                        onAlways: { always(browser) }
                    )
                }
            }

            Spacer(minLength: 0)

            Text("数字键选择 · P 隐私窗口 · 右键记住此网站 · Esc 取消")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(width: layout.width, height: layout.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .onExitCommand(perform: onCancel)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(secondaryTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)

            Button(action: copyLinks) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("复制链接 (C)")
            .keyboardShortcut("c", modifiers: [])

            Button {
                privateMode.toggle()
            } label: {
                Image(systemName: privateMode ? "eye.slash.fill" : "eye.slash")
                    .foregroundStyle(privateMode ? Color.accentColor : Color.primary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("用隐私窗口打开 (P)")
            .keyboardShortcut("p", modifiers: [])
        }
        .frame(height: 36)
    }

    private func copyLinks() {
        let text = urls.map { $0.isFileURL ? $0.path : $0.absoluteString }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onCancel() }
    }

    private func always(_ browser: Browser) {
        guard let host = host else { return }
        RuleStore.shared.upsert(host: host, browserID: browser.id, privateMode: privateMode)
        onPick(browser, privateMode)
    }
}

struct BrowserCell: View {
    let browser: Browser
    let index: Int
    let privateMode: Bool
    let host: String?
    let onSelect: (Bool) -> Void
    let onAlways: () -> Void

    @State private var hovering = false

    var body: some View {
        let unavailable = privateMode && !BrowserLauncher.supportsPrivate(browser.id)

        Button {
            onSelect(NSEvent.modifierFlags.contains(.shift))
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: browser.icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                    if index < 9 {
                        Text("\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.accentColor))
                            .offset(x: 6, y: -4)
                    }
                }
                Text(browser.name)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 74)
            }
            .frame(width: PickerLayout.cellWidth, height: PickerLayout.cellHeight)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering && !unavailable ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(unavailable)
        .opacity(unavailable ? 0.35 : 1)
        .help(unavailable ? "\(browser.name) 不支持从这里打开隐私窗口" : browser.name)
        .onHover { hovering = $0 }
        .digitShortcut(index)
        .contextMenu {
            if let host = host {
                Button("总是用 \(browser.name) 打开 \(host)") { onAlways() }
            }
        }
    }
}

private extension View {
    /// 前 9 个浏览器绑定数字键 1–9。
    @ViewBuilder
    func digitShortcut(_ index: Int) -> some View {
        if index < 9 {
            self.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
        } else {
            self
        }
    }
}
