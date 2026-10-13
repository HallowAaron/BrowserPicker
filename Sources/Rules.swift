import Foundation

/// 一条域名规则：域名命中后直接用指定浏览器打开。
struct Rule: Identifiable, Codable, Hashable {
    var id = UUID()
    var pattern: String = ""        // 例如 github.com 或 *.example.com
    var browserID: String = ""      // 目标浏览器的 bundle identifier
    var exactHost: Bool = false     // true：仅匹配该域名本身，不含子域名
    var privateMode: Bool = false   // 用隐私/无痕窗口打开

    /// 规整用户输入：去掉空白、协议和路径，转小写。
    var normalizedPattern: String {
        var p = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = p.range(of: "://") { p = String(p[range.upperBound...]) }
        if let slash = p.firstIndex(of: "/") { p = String(p[..<slash]) }
        return p
    }

    func matches(host: String) -> Bool {
        var p = normalizedPattern
        guard !p.isEmpty else { return false }
        let h = host.lowercased()

        // 通配写法 *.example.com：匹配 example.com 及其所有子域名
        if p.hasPrefix("*.") {
            p = String(p.dropFirst(2))
            guard !p.isEmpty else { return false }
            return h == p || h.hasSuffix("." + p)
        }
        if exactHost { return h == p }
        return h == p || h.hasSuffix("." + p)
    }
}

final class RuleStore: ObservableObject {
    static let shared = RuleStore()

    @Published var rules: [Rule] {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Preferences.Key.rules),
           let decoded = try? JSONDecoder().decode([Rule].self, from: data) {
            rules = decoded
        } else {
            rules = []
        }
    }

    /// 返回第一条命中的规则（从上到下匹配）。
    func rule(for url: URL) -> Rule? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return rules.first { $0.matches(host: host) }
    }

    /// 弹窗里右键“总是用它打开”时调用：已有同域名规则则更新，否则插入到最前面。
    func upsert(host: String, browserID: String, privateMode: Bool) {
        let pattern = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if let index = rules.firstIndex(where: { $0.normalizedPattern == pattern && !$0.exactHost }) {
            rules[index].browserID = browserID
            rules[index].privateMode = privateMode
        } else {
            rules.insert(Rule(pattern: pattern, browserID: browserID, privateMode: privateMode), at: 0)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: Preferences.Key.rules)
        }
    }
}
