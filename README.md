# BrowserPicker

一个 macOS 小工具：把自己设为**默认浏览器**，之后每次点击链接（来自微信、Slack、邮件、终端……）都会先在鼠标旁弹出选择框，让你决定用哪个浏览器打开。

- 语言与框架：Swift 5 · SwiftUI + AppKit
- 系统要求：macOS 13 Ventura 及以上
- 构建要求：Xcode 15+ 或 Command Line Tools

## 功能

- **弹窗选择**：在鼠标位置弹出浮动面板，显示所有已安装的浏览器；数字键 `1–9` 直接选择，`Esc` 取消，点击别处自动关闭
- **隐私窗口**：弹窗里按 `P`（或按住 `⇧` 点击浏览器）以隐私/无痕窗口打开
- **域名规则**：为某些网站固定浏览器（例如 `github.com` 总用 Chrome），命中规则时不再弹窗
- **右键记住**：在弹窗里右键某个浏览器 →「总是用 X 打开 xxx.com」，自动创建规则
- **按住 ⌥ 强制弹窗**：点击链接时按住 Option，忽略规则，强制弹出选择框
- **复制链接**：弹窗里按 `C`
- **浏览器管理**：可调整顺序、隐藏不需要的应用、手动添加任意 App
- **菜单栏图标 / 开机自启 / 默认浏览器状态检测**

## 工作原理

```
点击链接 ──► 系统交给默认浏览器（BrowserPicker）
                  │
                  ▼
        application(_:open:) 收到 URL
                  │
        ┌─────────┴──────────┐
   命中规则且未按 ⌥        否则
        │                    │
        ▼                    ▼
   直接打开指定浏览器     弹出选择面板 ──► 用户选择 ──► NSWorkspace 交给真正的浏览器
```

关键点：

1. `Info.plist` 里声明 `CFBundleURLTypes`（`http` / `https`），App 才会出现在「默认网页浏览器」列表中
2. 用 `NSWorkspace.urlsForApplications(toOpen:)` 枚举能打开 https 的应用，并**排除自己**（否则会死循环）
3. 用 `NSWorkspace.open(_:withApplicationAt:)` 把链接转交给选中的浏览器；隐私窗口则通过命令行参数启动

## 构建与运行

三种方式任选其一。

### 方式 A：脚本构建（最简单，不需要 Xcode 工程）

```bash
cd BrowserPicker
./build.sh install          # 构建 → 安装到 /Applications → 启动
```

其他用法：

```bash
./build.sh                  # 只构建，产物在 build/BrowserPicker.app
./build.sh run              # 构建并直接运行
UNIVERSAL=1 ./build.sh      # 通用二进制（arm64 + x86_64）
BUNDLE_ID=com.yourname.BrowserPicker ./build.sh install   # 自定义 Bundle ID
```

### 方式 B：用 XcodeGen 生成 Xcode 工程

```bash
brew install xcodegen
cd BrowserPicker
xcodegen generate
open BrowserPicker.xcodeproj
```

在 Xcode 里选 `My Mac` 运行即可。建议在 `project.yml` 里把 `PRODUCT_BUNDLE_IDENTIFIER` 改成你自己的，并在 Signing & Capabilities 中选择自己的 Team。

### 方式 C：手动新建 Xcode 工程

1. Xcode → File → New → Project → macOS → App（Interface 选 SwiftUI，Language 选 Swift），Product Name 填 `BrowserPicker`
2. 删除模板自带的 `*App.swift` 和 `ContentView.swift`
3. 把 `Sources/` 里的所有 `.swift` 文件拖进工程
4. 把 `Resources/Assets.xcassets` 里的 `AppIcon` 替换进工程的资源目录
5. 用 `Config/Info.plist` 里的 `CFBundleURLTypes`、`CFBundleDocumentTypes`、`LSUIElement` 这几项补充到工程的 Info 设置里
6. Signing & Capabilities 里**删除 App Sandbox**（需要枚举应用并带参数启动浏览器）

## 使用

1. 运行一次 App（首次直接打开会显示设置窗口）
2. 设置 → 通用 → 点「设为默认浏览器…」，在系统弹出的确认框里点「使用 BrowserPicker」
   - 也可以手动设置：系统设置 → 桌面与程序坞 → 默认网页浏览器
3. 点击任意链接，就会看到选择框

> 如果「默认网页浏览器」列表里找不到 BrowserPicker：先把 App 放进 `/Applications` 并打开一次，让系统登记它。

### 域名规则怎么写

| 写法 | 含义 |
| --- | --- |
| `github.com` | 匹配 `github.com` 及所有子域名（`gist.github.com` 等） |
| `github.com` + 勾选「仅此域名」 | 只匹配 `github.com` 本身 |
| `*.example.com` | 匹配 `example.com` 及所有子域名 |
| `https://github.com/foo` | 会自动提取域名部分 |

规则**从上到下**匹配，命中第一条即生效，可拖动调整顺序。

### 隐私窗口支持情况

| 浏览器 | 支持 |
| --- | --- |
| Chrome（含 Beta / Dev / Canary）、Chromium、Brave、Vivaldi | ✅ `--incognito` |
| Microsoft Edge | ✅ `--inprivate` |
| Firefox（含 Developer Edition / Nightly） | ✅ `--private-window` |
| Opera | ✅ `--private` |
| Safari、Arc 及其他 | ❌ 没有可用的命令行参数；开启隐私模式时这些浏览器会置灰 |

## 项目结构

```
BrowserPicker/
├── build.sh                    # 命令行构建脚本（swiftc）
├── project.yml                 # XcodeGen 工程描述
├── Config/
│   └── Info.plist              # URL scheme、LSUIElement、文档类型
├── Resources/
│   └── Assets.xcassets/        # 应用图标
└── Sources/
    ├── BrowserPickerApp.swift  # @main 入口
    ├── AppDelegate.swift       # 接收链接、菜单栏图标、生命周期
    ├── URLRouter.swift         # 决策：按规则直开 or 弹窗
    ├── PickerPanel.swift       # 浮动选择面板（NSPanel + SwiftUI）
    ├── BrowserLauncher.swift   # 调用 NSWorkspace 打开，含隐私窗口参数表
    ├── Browser.swift           # 浏览器模型 + 检测/排序/隐藏
    ├── Rules.swift             # 域名规则模型 + 持久化
    ├── Preferences.swift       # UserDefaults 键与默认值
    ├── SettingsView.swift      # 设置窗口（通用 / 浏览器 / 规则）
    └── SystemIntegration.swift # 默认浏览器设置、开机自启
```

## 常见问题

**点了浏览器，链接又回到选择框？**
说明把自己也列进了候选。代码里已用 Bundle ID 排除；如果你改过 Bundle ID，确认 `Bundle.main.bundleIdentifier` 与实际一致。

**开机自启动开关报错？**
`SMAppService` 要求 App 位于 `/Applications` 且已签名（ad-hoc 一般也可）。请先用 `./build.sh install` 安装后再开启。

**Firefox 隐私窗口打不开？**
Firefox 对「已运行实例 + 新实例」的处理因版本而异；如遇问题，先关闭 Firefox 再试，或在浏览器列表中取消对它的隐私模式依赖。

**菜单栏图标被我隐藏了，怎么回设置？**
再次打开 BrowserPicker 应用（Finder / Spotlight / Launchpad）即可显示设置窗口。

**想改回原来的默认浏览器？**
系统设置 → 桌面与程序坞 → 默认网页浏览器，选回 Safari / Chrome 即可。BrowserPicker 不修改任何系统文件，卸载只需删除 App。

**数据存在哪里？**
`UserDefaults`（偏好设置域为你的 Bundle ID），包含规则、浏览器顺序、隐藏列表。不联网，不收集任何数据。

## 进阶想法

- 去除链接跟踪参数（`utm_*`、`fbclid` 等）后再打开：在 `URLRouter.handle` 中先处理 URL
- 按来源 App 决定浏览器：可通过 `NSWorkspace.shared.frontmostApplication` 获取点击链接时的前台应用
- 浏览器 Profile 支持：Chrome 可传 `--profile-directory="Profile 1"`，参考 `BrowserLauncher`
- 本地化：目前界面文案为中文，可迁移到 String Catalog
