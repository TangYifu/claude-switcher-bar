import AppKit
import CoreText
import Foundation
import SwiftUI

// MARK: - Anthropic Design System (Colors, Typography & Vector Emblem)

enum AnthropicFont {
    private static let registered: Bool = {
        let candidateDirs = [
            Bundle.main.resourceURL?.appendingPathComponent("fonts").path,
            "/Applications/Claude.app/Contents/Resources/fonts"
        ].compactMap { $0 }

        let fontFiles = [
            "AnthropicSerif-Romans-Variable-25x258.ttf",
            "AnthropicSerif-Italics-Variable-25x258.ttf",
            "AnthropicSans-Romans-Variable-25x258.ttf",
            "AnthropicSans-Italics-Variable-25x258.ttf"
        ]

        for dir in candidateDirs {
            for file in fontFiles {
                let path = "\(dir)/\(file)"
                if FileManager.default.fileExists(atPath: path) {
                    let url = URL(fileURLWithPath: path) as CFURL
                    CTFontManagerRegisterFontsForURL(url, .process, nil)
                }
            }
        }
        return true
    }()

    static func serif(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        _ = registered
        let psName: String
        switch weight {
        case .bold, .heavy, .black:
            psName = "AnthropicSerifVariable-DisplayBold"
        case .semibold:
            psName = "AnthropicSerifVariable-DisplaySemibold"
        case .medium:
            psName = "AnthropicSerifVariable-DisplayMedium"
        default:
            psName = "AnthropicSerifVariable-DisplayRegular"
        }
        if NSFont(name: psName, size: size) != nil {
            return .custom(psName, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = registered
        let psName: String
        switch weight {
        case .bold, .heavy, .black:
            psName = "AnthropicSansVariable-TextBold"
        case .semibold:
            psName = "AnthropicSansVariable-TextSemibold"
        case .medium:
            psName = "AnthropicSansVariable-TextMedium"
        default:
            psName = "AnthropicSansVariable-TextRegular"
        }
        if NSFont(name: psName, size: size) != nil {
            return .custom(psName, size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum AnthropicTheme {
    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    static func dynamicNSColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        }
    }

    // Official Claude Desktop (`cds-root`) Warm Surfaces
    // Light: Pampas Parchment (#FAF9F5) / Dark: Warm Coal (#1F1E1D)
    static let canvasBackground = dynamicColor(
        light: (0.980, 0.976, 0.961, 1.0),
        dark:  (0.122, 0.118, 0.114, 1.0)
    )

    // Light: Warm Paper (#FFFFFF) / Dark: Warm Graphite (#262624)
    static let cardSurface = dynamicColor(
        light: (1.000, 0.998, 0.992, 1.0),
        dark:  (0.149, 0.149, 0.141, 1.0)
    )

    // Light: Crisp White (#FFFFFF) / Dark: Elevated Slate (#2C2B28)
    static let cardElevatedSurface = dynamicColor(
        light: (1.000, 1.000, 1.000, 1.0),
        dark:  (0.173, 0.169, 0.157, 1.0)
    )

    // Light: Warm Oat Well (#F3F1E9) / Dark: Recessed Charcoal (#191817)
    static let recessedSurface = dynamicColor(
        light: (0.953, 0.945, 0.914, 1.0),
        dark:  (0.098, 0.094, 0.090, 1.0)
    )

    // Interactive Secondary Controls
    static let controlFill = dynamicColor(
        light: (0.937, 0.929, 0.898, 1.0),
        dark:  (0.192, 0.188, 0.176, 1.0)
    )

    static let controlHoverFill = dynamicColor(
        light: (0.902, 0.890, 0.855, 1.0),
        dark:  (0.235, 0.231, 0.216, 1.0)
    )

    // Warm Stone Hairline Borders (`--border-100`)
    static let borderSubtle = dynamicColor(
        light: (0.122, 0.118, 0.114, 0.09),
        dark:  (0.871, 0.863, 0.820, 0.09)
    )

    static let borderStrong = dynamicColor(
        light: (0.122, 0.118, 0.114, 0.16),
        dark:  (0.871, 0.863, 0.820, 0.17)
    )

    // Editorial Ink Hierarchy (`--text-100`, `--text-200`, `--text-400`)
    static let inkPrimary = dynamicColor(
        light: (0.078, 0.078, 0.075, 1.0), // #141413
        dark:  (0.980, 0.976, 0.961, 1.0)  // #FAF9F5
    )

    static let inkSecondary = dynamicColor(
        light: (0.243, 0.239, 0.227, 1.0), // #3E3D3A
        dark:  (0.761, 0.753, 0.714, 1.0)  // #C2C0B6
    )

    static let inkMuted = dynamicColor(
        light: (0.451, 0.447, 0.424, 1.0), // #73726C
        dark:  (0.612, 0.604, 0.573, 1.0)  // #9C9A92
    )

    // Signature Anthropic Pigments
    // Terracotta Clay (`#D97757` / `#C6613F`)
    static let terracotta = Color(red: 0.851, green: 0.467, blue: 0.341)
    static let terracottaDeep = Color(red: 0.776, green: 0.380, blue: 0.247)
    static let nsTerracotta = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1.0)

    // Warm Book-Cloth Umber & Parchment — Secondary Editorial Account Identity
    static let sandstone = dynamicColor(
        light: (0.235, 0.227, 0.212, 1.0), // #3C3A36 Warm Book-Cloth Charcoal
        dark:  (0.835, 0.788, 0.718, 1.0)  // #D5C9B7 Warm Parchment Sand
    )
    static let sandstoneDeep = Color(red: 0.165, green: 0.161, blue: 0.149)
    static let nsSandstone = dynamicNSColor(
        light: (0.235, 0.227, 0.212, 1.0),
        dark:  (0.835, 0.788, 0.718, 1.0)
    )

    static let pro2BadgeTop = dynamicColor(
        light: (0.255, 0.247, 0.231, 1.0),
        dark:  (0.275, 0.263, 0.243, 1.0)
    )
    static let pro2BadgeBottom = dynamicColor(
        light: (0.165, 0.161, 0.149, 1.0),
        dark:  (0.196, 0.188, 0.173, 1.0)
    )

    // Botanical Sage (`--success-000` / `--success-100`)
    static let sage = dynamicColor(
        light: (0.220, 0.510, 0.255, 1.0),
        dark:  (0.435, 0.725, 0.447, 1.0)
    )
    static let sageFill = dynamicColor(
        light: (0.220, 0.510, 0.255, 0.11),
        dark:  (0.435, 0.725, 0.447, 0.14)
    )
    static let sageBorder = dynamicColor(
        light: (0.220, 0.510, 0.255, 0.26),
        dark:  (0.435, 0.725, 0.447, 0.28)
    )

    // Crimson Danger (`--danger-100`)
    static let danger = dynamicColor(
        light: (0.710, 0.200, 0.200, 1.0),
        dark:  (0.871, 0.345, 0.322, 1.0)
    )
    static let dangerFill = dynamicColor(
        light: (0.710, 0.200, 0.200, 0.10),
        dark:  (0.871, 0.345, 0.322, 0.14)
    )
    static let dangerBorder = dynamicColor(
        light: (0.710, 0.200, 0.200, 0.32),
        dark:  (0.871, 0.345, 0.322, 0.38)
    )
}

struct ClaudeStarburstShape: Shape {
    // Official 24x24 Claude Starburst polygon coordinates
    static let vertices: [(CGFloat, CGFloat)] = [
        (4.709, 15.955), (9.429, 13.308), (9.509, 13.078), (9.429, 12.95), (9.2, 12.95), (8.41, 12.902),
        (5.712, 12.829), (3.373, 12.732), (1.107, 12.61), (0.536, 12.489), (0.0, 11.784), (0.055, 11.432),
        (0.535, 11.111), (1.221, 11.171), (2.741, 11.274), (5.019, 11.432), (6.671, 11.529), (9.12, 11.784),
        (9.509, 11.784), (9.564, 11.627), (9.43, 11.529), (9.327, 11.432), (6.969, 9.836), (4.417, 8.148),
        (3.081, 7.176), (2.357, 6.685), (1.993, 6.223), (1.835, 5.215), (2.491, 4.493), (3.372, 4.553),
        (3.597, 4.614), (4.49, 5.3), (6.398, 6.776), (8.889, 8.609), (9.254, 8.913), (9.399, 8.81),
        (9.418, 8.737), (9.254, 8.463), (7.899, 6.017), (6.453, 3.527), (5.809, 2.495), (5.639, 1.876),
        (5.535, 1.147), (6.283, 0.134), (6.696, 0.0), (7.692, 0.134), (8.112, 0.498), (8.732, 1.912),
        (9.734, 4.141), (11.289, 7.171), (11.745, 8.069), (11.988, 8.901), (12.079, 9.156), (12.237, 9.156),
        (12.237, 9.01), (12.365, 7.304), (12.602, 5.209), (12.832, 2.514), (12.912, 1.754), (13.288, 0.844),
        (14.035, 0.352), (14.619, 0.632), (15.099, 1.317), (15.032, 1.761), (14.746, 3.612), (14.187, 6.515),
        (13.823, 8.457), (14.035, 8.457), (14.278, 8.215), (15.263, 6.909), (16.915, 4.845), (17.645, 4.025),
        (18.495, 3.121), (19.042, 2.69), (20.075, 2.69), (20.835, 3.819), (20.495, 4.985), (19.431, 6.332),
        (18.55, 7.474), (17.286, 9.174), (16.496, 10.534), (16.569, 10.644), (16.757, 10.624), (19.613, 10.018),
        (21.156, 9.738), (22.997, 9.423), (23.83, 9.811), (23.921, 10.206), (23.593, 11.013), (21.624, 11.499),
        (19.315, 11.961), (15.876, 12.774), (15.834, 12.804), (15.883, 12.865), (17.432, 13.011), (18.094, 13.047),
        (19.716, 13.047), (22.736, 13.272), (23.526, 13.794), (24.0, 14.432), (23.921, 14.917), (22.706, 15.537),
        (21.066, 15.148), (17.237, 14.238), (15.925, 13.909), (15.743, 13.909), (15.743, 14.019), (16.836, 15.087),
        (18.842, 16.897), (21.351, 19.227), (21.478, 19.805), (21.156, 20.26), (20.816, 20.211), (18.611, 18.554),
        (17.76, 17.807), (15.834, 16.187), (15.706, 16.187), (15.706, 16.357), (16.15, 17.006), (18.495, 20.527),
        (18.617, 21.607), (18.447, 21.96), (17.839, 22.173), (17.171, 22.051), (15.797, 20.126), (14.382, 17.959),
        (13.239, 16.016), (13.099, 16.096), (12.425, 23.35), (12.109, 23.72), (11.38, 24.0), (10.773, 23.539),
        (10.451, 22.792), (10.773, 21.316), (11.162, 19.392), (11.477, 17.862), (11.763, 15.962), (11.933, 15.33),
        (11.921, 15.288), (11.781, 15.306), (10.347, 17.273), (8.167, 20.218), (6.441, 22.063), (6.027, 22.227),
        (5.31, 21.857), (5.377, 21.195), (5.778, 20.606), (8.166, 17.57), (9.606, 15.688), (10.536, 14.602),
        (10.53, 14.444), (10.475, 14.444), (4.132, 18.56), (3.002, 18.706), (2.515, 18.25), (2.576, 17.504),
        (2.807, 17.261), (4.715, 15.949), (4.709, 15.955)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = Self.vertices.first else { return path }
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        path.move(to: CGPoint(x: rect.minX + first.0 * sx, y: rect.minY + first.1 * sy))
        for pt in Self.vertices.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + pt.0 * sx, y: rect.minY + pt.1 * sy))
        }
        path.closeSubpath()
        return path
    }

    static func drawInAppKit(rect: NSRect, color: NSColor) {
        guard let first = vertices.first else { return }
        let bezier = NSBezierPath()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        // AppKit NSImage(flipped: false) has origin at bottom-left, while SVG has origin at top-left
        bezier.move(to: NSPoint(x: rect.minX + first.0 * sx, y: rect.maxY - first.1 * sy))
        for pt in vertices.dropFirst() {
            bezier.line(to: NSPoint(x: rect.minX + pt.0 * sx, y: rect.maxY - pt.1 * sy))
        }
        bezier.close()
        color.setFill()
        bezier.fill()
    }
}

// MARK: - Externalized Environment Configuration & Models

struct SwitcherEnvironmentConfig: Codable {
    var proxyHost: String = "127.0.0.1"
    var proxyPort: UInt16 = 7890
    var targetTimeZone: String = "America/New_York"
    var regionDisplayName: String = "纽约"
    var tzLauncherPath: String = "~/Applications/Claude Timezone Launcher.app/Contents/MacOS/launcher"
    var firewallCheckScript: String = ""
    var requireFirewallCheck: Bool = false
    var firewallDisplayName: String = "本地防火墙"

    var proxyEndpointString: String {
        "\(proxyHost):\(proxyPort)"
    }

    var proxyURLString: String {
        "http://\(proxyHost):\(proxyPort)"
    }

    var resolvedLauncherPath: String {
        NSString(string: tzLauncherPath).expandingTildeInPath
    }

    var resolvedFirewallScriptPath: String {
        let trimmed = firewallCheckScript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return NSString(string: trimmed).expandingTildeInPath
    }
}

enum AccountID: String, CaseIterable, Codable, Identifiable {
    case pro1
    case pro2

    var id: String { rawValue }

    var shortBadge: String {
        switch self {
        case .pro1: return "P1"
        case .pro2: return "P2"
        }
    }

    var menuName: String {
        switch self {
        case .pro1: return "Pro 1"
        case .pro2: return "Pro 2"
        }
    }

    var defaultTitle: String {
        switch self {
        case .pro1: return "Claude Pro 1"
        case .pro2: return "Claude Pro 2"
        }
    }

    var defaultNote: String {
        switch self {
        case .pro1: return "主力账号 · 默认隔离目录"
        case .pro2: return "备用账号 · 独立隔离目录"
        }
    }

    var accentColor: Color {
        switch self {
        case .pro1: return AnthropicTheme.terracotta
        case .pro2: return AnthropicTheme.sandstone
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .pro1: return AnthropicTheme.terracottaDeep
        case .pro2: return AnthropicTheme.sandstoneDeep
        }
    }

    var badgeGradient: LinearGradient {
        switch self {
        case .pro1:
            return LinearGradient(
                colors: [AnthropicTheme.terracotta, AnthropicTheme.terracottaDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pro2:
            return LinearGradient(
                colors: [AnthropicTheme.pro2BadgeTop, AnthropicTheme.pro2BadgeBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [AnthropicTheme.terracotta, AnthropicTheme.terracottaDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var nsAccentColor: NSColor {
        switch self {
        case .pro1: return AnthropicTheme.nsTerracotta
        case .pro2: return AnthropicTheme.nsSandstone
        }
    }
}

struct SwitcherPreferences: Codable {
    var notes: [String: String] = [
        "pro1": AccountID.pro1.defaultNote,
        "pro2": AccountID.pro2.defaultNote
    ]
    var cooldownUntil: [String: Date] = [:]
    var cooldownDuration: [String: Double]? = [:]
}

struct DesktopInstanceInfo: Equatable {
    let pid: Int32
    let account: AccountID
    let isGuarded: Bool
}

struct ExitIPResult: Equatable {
    let ip: String
    let colo: String
    let country: String
    let checkedAt: Date
}

struct BannerMessage: Equatable {
    let text: String
    let isError: Bool
}

// MARK: - ViewModel

@MainActor
final class SwitcherStore: ObservableObject {
    static let bundleIdentifier = "io.github.claude-switcher-bar"

    @Published var envConfig: SwitcherEnvironmentConfig = SwitcherEnvironmentConfig()
    @Published var activeCLIAccount: AccountID = .pro1
    @Published var runningDesktops: [DesktopInstanceInfo] = []
    @Published var proxyOnline: Bool = false
    @Published var firewallHealthy: Bool = true
    @Published var preferences: SwitcherPreferences = SwitcherPreferences()
    @Published var targetClockDigits: String = "--:--:--"
    @Published var targetZoneAbbrev: String = "EST"
    @Published var now: Date = Date()
    @Published var isBusy: Bool = false
    @Published var banner: BannerMessage? = nil
    @Published var exitIPResult: ExitIPResult? = nil
    @Published var isCheckingIP: Bool = false
    @Published var launchAtLogin: Bool = false
    @Published var editingNoteFor: AccountID? = nil
    @Published var editingNoteDraft: String = ""

    private var isPopoverVisible: Bool = false
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    private var switcherDir: String { "\(homeDir)/Library/Application Support/ClaudeAccountSwitcher" }
    private var envConfigFile: String { "\(switcherDir)/switcher-config.json" }
    private var activeAccountFile: String { "\(switcherDir)/active-account" }
    private var prefsFile: String { "\(switcherDir)/menubar-prefs.json" }
    private var pro2DesktopDir: String { "\(homeDir)/Library/Application Support/Claude-Pro2" }
    private var accountCommonScript: String { "\(switcherDir)/account-common.sh" }
    private var launchAgentPlistPath: String { "\(homeDir)/Library/LaunchAgents/\(Self.bundleIdentifier).plist" }

    private var heartbeatTimer: Timer?
    private var tickCount: Int = 0
    private var notifiedCooldowns: Set<String> = []

    private var clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var zoneFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "zzz"
        return f
    }()

    private let localReadyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    init() {
        loadEnvironmentConfig()
        loadPreferences()
        updateClock()
        refreshAll()

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.tickCount += 1
                self.checkCooldownNotifications(at: Date())

                if self.isPopoverVisible {
                    self.updateClock()
                    if self.tickCount % 3 == 0 {
                        self.refreshSystemState()
                    }
                } else {
                    // Low-power idle polling when popover is closed (0% CPU impact)
                    if self.tickCount % 12 == 0 {
                        self.refreshSystemState()
                    }
                }
            }
        }
    }

    func setPopoverVisible(_ visible: Bool) {
        isPopoverVisible = visible
        if visible {
            loadEnvironmentConfig()
            updateClock()
            refreshAll()
        }
    }

    var allGuardsHealthy: Bool {
        proxyOnline && firewallHealthy && !hasUnguardedInstance
    }

    var hasUnguardedInstance: Bool {
        runningDesktops.contains(where: { !$0.isGuarded })
    }

    var ambientAccentColor: Color {
        if !allGuardsHealthy {
            return Color.red
        }
        if isDesktopRunning(.pro1) && !isDesktopRunning(.pro2) {
            return AccountID.pro1.accentColor
        }
        if isDesktopRunning(.pro2) && !isDesktopRunning(.pro1) {
            return AccountID.pro2.accentColor
        }
        return activeCLIAccount.accentColor
    }

    var shortRegionTag: String {
        if envConfig.targetTimeZone == "America/New_York" {
            return "NY"
        }
        return targetZoneAbbrev
    }

    var menuBarTitle: String {
        if !proxyOnline || !firewallHealthy {
            return "防护离线"
        }
        if hasUnguardedInstance {
            return "未受控!"
        }
        let p1Run = isDesktopRunning(.pro1)
        let p2Run = isDesktopRunning(.pro2)
        if p1Run && p2Run {
            return "双开 · \(activeCLIAccount.shortBadge)"
        } else if p1Run {
            return activeCLIAccount == .pro1 ? "Pro 1 · \(shortRegionTag)" : "桌P1 · 终P2"
        } else if p2Run {
            return activeCLIAccount == .pro2 ? "Pro 2 · \(shortRegionTag)" : "桌P2 · 终P1"
        } else {
            return "\(activeCLIAccount.menuName) · 待机"
        }
    }

    func isDesktopRunning(_ account: AccountID) -> Bool {
        runningDesktops.contains(where: { $0.account == account })
    }

    func desktopPID(_ account: AccountID) -> Int32? {
        runningDesktops.first(where: { $0.account == account })?.pid
    }

    func note(for account: AccountID) -> String {
        preferences.notes[account.rawValue] ?? account.defaultNote
    }

    func remainingCooldown(for account: AccountID) -> TimeInterval? {
        guard let until = preferences.cooldownUntil[account.rawValue] else { return nil }
        let diff = until.timeIntervalSince(now)
        return diff > 0 ? diff : nil
    }

    func cooldownProgress(for account: AccountID) -> Double {
        guard let remaining = remainingCooldown(for: account) else { return 1.0 }
        let total = preferences.cooldownDuration?[account.rawValue] ?? (5.0 * 3600.0)
        guard total > 0 else { return 0.0 }
        let elapsed = max(0, total - remaining)
        return min(1.0, max(0.04, elapsed / total))
    }

    func cooldownReadyTimeText(for account: AccountID) -> String {
        guard let until = preferences.cooldownUntil[account.rawValue] else { return "" }
        return localReadyFormatter.string(from: until)
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func updateClock() {
        let current = Date()
        now = current
        let tz = TimeZone(identifier: envConfig.targetTimeZone) ?? TimeZone(identifier: "America/New_York") ?? .current
        clockFormatter.timeZone = tz
        zoneFormatter.timeZone = tz
        targetClockDigits = clockFormatter.string(from: current)
        targetZoneAbbrev = zoneFormatter.string(from: current)
    }

    func refreshAll() {
        launchAtLogin = FileManager.default.fileExists(atPath: launchAgentPlistPath)
        refreshSystemState()
    }

    func refreshSystemState() {
        let nextCLI: AccountID
        if let raw = try? String(contentsOfFile: activeAccountFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           raw == "pro2" {
            nextCLI = .pro2
        } else {
            nextCLI = .pro1
        }
        if activeCLIAccount != nextCLI {
            activeCLIAccount = nextCLI
        }

        let cfg = self.envConfig
        let pro2Dir = self.pro2DesktopDir

        Task.detached(priority: .utility) {
            let proxyOK = Self.checkTCPPort(host: cfg.proxyHost, port: cfg.proxyPort)
            let fwOK = Self.evaluateFirewallHealth(config: cfg)
            let desktops = Self.scanRunningDesktops(pro2DataDir: pro2Dir)

            await MainActor.run {
                if self.proxyOnline != proxyOK || self.firewallHealthy != fwOK || self.runningDesktops != desktops {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.proxyOnline = proxyOK
                        self.firewallHealthy = fwOK
                        self.runningDesktops = desktops
                    }
                }
            }
        }
    }

    // MARK: - Actions

    func switchCLIAccountOnly(to account: AccountID) {
        ensurePro2DirsIfNeeded(account)
        writeActiveAccount(account)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activeCLIAccount = account
        }
        showBanner("终端与 VSCode 默认账号已切换为 \(account.defaultTitle)")
    }

    func launchOrSwitchDesktop(to target: AccountID, closeOther: Bool) {
        guard !isBusy else { return }
        isBusy = true
        let regionName = envConfig.regionDisplayName
        withAnimation(.easeInOut(duration: 0.18)) {
            banner = BannerMessage(
                text: closeOther
                    ? "正在通过\(regionName)环境启动 \(target.defaultTitle)（纯英文隔离）…"
                    : "正在双开启动 \(target.defaultTitle)（\(regionName)时区 · 纯英文）…",
                isError: false
            )
        }

        let cfg = self.envConfig
        let tzBin = cfg.resolvedLauncherPath
        let pro2Dir = self.pro2DesktopDir
        let commonSh = self.accountCommonScript

        Task.detached(priority: .userInitiated) {
            let proxyOK = Self.checkTCPPort(host: cfg.proxyHost, port: cfg.proxyPort)
            let fwOK = Self.evaluateFirewallHealth(config: cfg)
            guard proxyOK && fwOK else {
                await MainActor.run {
                    self.proxyOnline = proxyOK
                    self.firewallHealthy = fwOK
                    self.isBusy = false
                    self.showBanner("已拦截启动：代理 (\(cfg.proxyPort)) 或\(cfg.firewallDisplayName)未就绪", isError: true)
                }
                return
            }

            guard FileManager.default.isExecutableFile(atPath: tzBin) else {
                await MainActor.run {
                    self.isBusy = false
                    self.showBanner("未找到时区启动器可执行文件，请检查 switcher-config.json", isError: true)
                }
                return
            }

            let currentDesktops = Self.scanRunningDesktops(pro2DataDir: pro2Dir)
            if currentDesktops.contains(where: { !$0.isGuarded }) {
                await MainActor.run {
                    self.isBusy = false
                    self.showBanner("检测到未受控的 Claude 进程，请先按 ⌘Q 退出后再启动", isError: true)
                }
                return
            }

            let otherAccount: AccountID = (target == .pro1) ? .pro2 : .pro1
            let otherPIDs = currentDesktops.filter { $0.account == otherAccount }.map { $0.pid }

            if closeOther && !otherPIDs.isEmpty {
                let targetAlreadyOpen = currentDesktops.contains(where: { $0.account == target })
                if !targetAlreadyOpen {
                    _ = Self.runProcess(
                        executable: "/usr/bin/osascript",
                        args: ["-e", "tell application id \"com.anthropic.claudefordesktop\" to quit"]
                    )
                }
                for pid in otherPIDs {
                    kill(pid, SIGTERM)
                }
                for _ in 0..<50 {
                    let stillAlive = otherPIDs.contains { kill($0, 0) == 0 }
                    if !stillAlive { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }

            if FileManager.default.fileExists(atPath: commonSh) {
                if target == .pro2 {
                    _ = Self.runProcess(
                        executable: "/bin/sh",
                        args: ["-c", ". \"\(commonSh)\" && ensure_pro2_dirs"]
                    )
                } else {
                    _ = Self.runProcess(
                        executable: "/bin/sh",
                        args: ["-c", ". \"\(commonSh)\" && enforce_english_desktop_config \"$PRO1_DESKTOP_DIR\""]
                    )
                }
            }

            await MainActor.run {
                self.writeActiveAccount(target)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self.activeCLIAccount = target
                }
            }

            // Strictly enforce en-US + configured target timezone on child Claude launcher process
            var env = ProcessInfo.processInfo.environment
            env["CLAUDE_ACCOUNT_ID"] = target.rawValue
            env["TZ"] = cfg.targetTimeZone
            env["__XPC_TZ"] = cfg.targetTimeZone
            env["LANG"] = "en_US.UTF-8"
            env["LC_ALL"] = "en_US.UTF-8"
            env["LC_CTYPE"] = "en_US.UTF-8"
            env["LANGUAGE"] = "en_US:en"
            let res = Self.runProcess(executable: tzBin, args: [], env: env)

            try? await Task.sleep(nanoseconds: 700_000_000)
            let updatedDesktops = Self.scanRunningDesktops(pro2DataDir: pro2Dir)

            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self.runningDesktops = updatedDesktops
                    self.isBusy = false
                }
                if res.exitCode == 0 {
                    self.showBanner("\(target.defaultTitle) 已就绪（\(regionName)时区 · 纯英文 · 终端已同步）")
                } else {
                    self.showBanner("启动器返回异常码 \(res.exitCode)，请检查代理与防火墙状态", isError: true)
                }
            }
        }
    }

    func quitDesktopInstance(_ account: AccountID) {
        guard let pid = desktopPID(account) else { return }
        let isSingleInstance = runningDesktops.count == 1
        let pro2Dir = self.pro2DesktopDir
        isBusy = true
        Task.detached(priority: .userInitiated) {
            if isSingleInstance {
                _ = Self.runProcess(
                    executable: "/usr/bin/osascript",
                    args: ["-e", "tell application id \"com.anthropic.claudefordesktop\" to quit"]
                )
            } else {
                kill(pid, SIGTERM)
            }
            for _ in 0..<40 {
                if kill(pid, 0) != 0 { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let updated = Self.scanRunningDesktops(pro2DataDir: pro2Dir)
            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self.runningDesktops = updated
                    self.isBusy = false
                }
                self.showBanner("已安全退出 \(account.defaultTitle) 桌面实例")
            }
        }
    }

    // MARK: - Cooldown Timer (100% Local, Zero Network/Cookie Risk)

    func markCooldown(for account: AccountID, hours: Double) {
        let seconds = hours * 3600.0
        let current = Date()
        now = current
        let targetDate = current.addingTimeInterval(seconds)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            preferences.cooldownUntil[account.rawValue] = targetDate
            var durations = preferences.cooldownDuration ?? [:]
            durations[account.rawValue] = seconds
            preferences.cooldownDuration = durations
        }
        notifiedCooldowns.remove(account.rawValue)
        savePreferences()
        showBanner("已开启 \(account.defaultTitle) 本地 \(Int(hours)) 小时恢复倒计时")
    }

    func clearCooldown(for account: AccountID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            preferences.cooldownUntil.removeValue(forKey: account.rawValue)
            preferences.cooldownDuration?.removeValue(forKey: account.rawValue)
        }
        notifiedCooldowns.remove(account.rawValue)
        savePreferences()
    }

    private func checkCooldownNotifications(at currentTime: Date) {
        for account in AccountID.allCases {
            guard let until = preferences.cooldownUntil[account.rawValue] else { continue }
            if currentTime >= until && !notifiedCooldowns.contains(account.rawValue) {
                notifiedCooldowns.insert(account.rawValue)
                preferences.cooldownUntil.removeValue(forKey: account.rawValue)
                preferences.cooldownDuration?.removeValue(forKey: account.rawValue)
                savePreferences()
                sendNativeNotification(
                    title: "\(account.defaultTitle) 额度已恢复",
                    body: "本地倒计时结束，\(account.defaultTitle) 可以重新切换使用了。"
                )
            }
        }
    }

    // MARK: - Exit IP Verification (Through Configured Local Proxy -> Cloudflare Trace Only)

    func verifyExitIP() {
        guard !isCheckingIP else { return }
        isCheckingIP = true
        let proxyURL = envConfig.proxyURLString
        let proxyPort = envConfig.proxyPort
        Task.detached(priority: .userInitiated) {
            let res = Self.runProcess(
                executable: "/usr/bin/curl",
                args: ["-sS", "--max-time", "5", "-x", proxyURL, "https://www.cloudflare.com/cdn-cgi/trace"]
            )
            var parsed: ExitIPResult? = nil
            if res.exitCode == 0 {
                var dict: [String: String] = [:]
                for line in res.stdout.split(separator: "\n") {
                    let parts = line.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        dict[String(parts[0])] = String(parts[1])
                    }
                }
                if let ip = dict["ip"] {
                    parsed = ExitIPResult(
                        ip: ip,
                        colo: dict["colo"] ?? "?",
                        country: dict["loc"] ?? "?",
                        checkedAt: Date()
                    )
                }
            }
            let finalParsed = parsed
            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self.isCheckingIP = false
                    if let p = finalParsed {
                        self.exitIPResult = p
                    }
                }
                if finalParsed == nil {
                    self.showBanner("端口 \(proxyPort) 代理出口校验超时，请检查节点连接", isError: true)
                }
            }
        }
    }

    // MARK: - Note Editing & Launch At Login

    func startEditingNote(for account: AccountID) {
        editingNoteDraft = note(for: account)
        withAnimation(.easeInOut(duration: 0.16)) {
            editingNoteFor = account
        }
    }

    func saveEditingNote() {
        guard let account = editingNoteFor else { return }
        let trimmed = editingNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.notes[account.rawValue] = trimmed.isEmpty ? account.defaultNote : trimmed
        withAnimation(.easeInOut(duration: 0.16)) {
            editingNoteFor = nil
        }
        savePreferences()
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        let appExec = Bundle.main.executablePath ?? "\(homeDir)/Applications/Claude Switcher.app/Contents/MacOS/ClaudeSwitcherBar"
        if enabled {
            let plist: [String: Any] = [
                "Label": Self.bundleIdentifier,
                "ProgramArguments": [appExec],
                "RunAtLoad": true,
                "KeepAlive": false
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? FileManager.default.createDirectory(
                    atPath: "\(homeDir)/Library/LaunchAgents",
                    withIntermediateDirectories: true
                )
                try? data.write(to: URL(fileURLWithPath: launchAgentPlistPath), options: .atomic)
                launchAtLogin = true
                showBanner("已开启菜单栏组件开机自启")
            }
        } else {
            try? FileManager.default.removeItem(atPath: launchAgentPlistPath)
            launchAtLogin = false
            showBanner("已关闭开机自启")
        }
    }

    // MARK: - Persistence & System Helpers

    private func showBanner(_ msg: String, isError: Bool = false) {
        let item = BannerMessage(text: msg, isError: isError)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            banner = item
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            if self.banner == item {
                withAnimation(.easeOut(duration: 0.22)) {
                    self.banner = nil
                }
            }
        }
    }

    private func loadEnvironmentConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: envConfigFile)),
              let decoded = try? JSONDecoder().decode(SwitcherEnvironmentConfig.self, from: data) else {
            return
        }
        envConfig = decoded
    }

    private func loadPreferences() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: prefsFile)),
              var decoded = try? JSONDecoder().decode(SwitcherPreferences.self, from: data) else {
            return
        }
        if decoded.notes["pro1"] == "Primary · Default Profile" {
            decoded.notes["pro1"] = AccountID.pro1.defaultNote
        }
        if decoded.notes["pro2"] == "Secondary · Isolated Profile" {
            decoded.notes["pro2"] = AccountID.pro2.defaultNote
        }
        preferences = decoded
    }

    private func savePreferences() {
        try? FileManager.default.createDirectory(atPath: switcherDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(preferences) {
            try? data.write(to: URL(fileURLWithPath: prefsFile), options: .atomic)
        }
    }

    private func writeActiveAccount(_ account: AccountID) {
        try? FileManager.default.createDirectory(atPath: switcherDir, withIntermediateDirectories: true)
        try? "\(account.rawValue)\n".write(toFile: activeAccountFile, atomically: true, encoding: .utf8)
    }

    private func ensurePro2DirsIfNeeded(_ account: AccountID) {
        guard account == .pro2 else { return }
        let common = accountCommonScript
        guard FileManager.default.fileExists(atPath: common) else { return }
        Task.detached(priority: .utility) {
            _ = Self.runProcess(executable: "/bin/sh", args: ["-c", ". \"\(common)\" && ensure_pro2_dirs"])
        }
    }

    private func sendNativeNotification(title: String, body: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        Task.detached(priority: .utility) {
            _ = Self.runProcess(
                executable: "/usr/bin/osascript",
                args: ["-e", "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\" sound name \"Glass\""]
            )
        }
    }

    nonisolated static func evaluateFirewallHealth(config: SwitcherEnvironmentConfig) -> Bool {
        let scriptPath = config.resolvedFirewallScriptPath
        if scriptPath.isEmpty {
            return !config.requireFirewallCheck
        }
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            return !config.requireFirewallCheck
        }
        return runProcess(executable: "/usr/bin/python3", args: [scriptPath]).exitCode == 0
    }

    nonisolated static func checkTCPPort(host: String, port: UInt16) -> Bool {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if res == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let pollRes = poll(&pfd, 1, 800)
        guard pollRes > 0 else { return false }

        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
        return soError == 0
    }

    nonisolated static func scanRunningDesktops(pro2DataDir: String) -> [DesktopInstanceInfo] {
        let uid = String(getuid())
        let pgrep = runProcess(
            executable: "/usr/bin/pgrep",
            args: ["-u", uid, "-f", "^/Applications/Claude.app/Contents/MacOS/Claude( |$)"]
        )
        guard pgrep.exitCode == 0 else { return [] }
        var results: [DesktopInstanceInfo] = []
        for line in pgrep.stdout.split(separator: "\n") {
            guard let pid = Int32(line.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            let ps = runProcess(executable: "/bin/ps", args: ["eww", "-p", String(pid), "-o", "command="])
            let cmd = ps.stdout
            guard !cmd.isEmpty else { continue }
            let guarded = cmd.contains("CLAUDE_NETWORK_GUARD=1")
            let acct: AccountID = (cmd.contains("CLAUDE_ACCOUNT_ID=pro2") || cmd.contains("--user-data-dir=\(pro2DataDir)")) ? .pro2 : .pro1
            results.append(DesktopInstanceInfo(pid: pid, account: acct, isGuarded: guarded))
        }
        return results
    }

    nonisolated static func runProcess(
        executable: String,
        args: [String],
        env: [String: String]? = nil
    ) -> (exitCode: Int32, stdout: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        if let env = env {
            proc.environment = env
        }
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, "")
        }
    }
}

// MARK: - Tactile Interactive Button Components (Anthropic Design System)

struct PrimaryCapsuleButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let accent: Color
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5.5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(AnthropicFont.sans(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(red: 0.980, green: 0.976, blue: 0.961))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(isHovered ? 0.08 : 0.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.24 : 0.15), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.18 : 0.10), radius: isHovered ? 4 : 2, x: 0, y: 1)
            )
            .opacity(disabled ? 0.52 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

struct SecondaryPillButton: View {
    let title: String
    let icon: String?
    var isDestructive: Bool = false
    let disabled: Bool
    let helpText: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(AnthropicFont.sans(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isDestructive && isHovered
                    ? AnthropicTheme.danger
                    : (isHovered ? AnthropicTheme.inkPrimary : AnthropicTheme.inkSecondary)
            )
            .frame(height: 30)
            .padding(.horizontal, 9.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isDestructive && isHovered
                            ? AnthropicTheme.dangerFill
                            : (isHovered ? AnthropicTheme.controlHoverFill : AnthropicTheme.controlFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isDestructive && isHovered
                                    ? AnthropicTheme.dangerBorder
                                    : (isHovered ? AnthropicTheme.borderStrong : AnthropicTheme.borderSubtle),
                                lineWidth: 0.75
                            )
                    )
            )
            .opacity(disabled ? 0.48 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Main Popover View

struct SwitcherPopoverView: View {
    @ObservedObject var store: SwitcherStore
    @State private var ipRowHovered = false
    @State private var refreshHovered = false
    @State private var quitHovered = false

    var body: some View {
        ZStack(alignment: .top) {
            AnthropicTheme.canvasBackground

            // Subtle warm terracotta paper wash along top edge
            LinearGradient(
                colors: [
                    (store.allGuardsHealthy ? AnthropicTheme.terracotta : AnthropicTheme.danger).opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 11) {
                securityCockpitCard

                VStack(spacing: 10) {
                    ForEach(AccountID.allCases) { account in
                        AccountCardView(store: store, account: account)
                    }
                }

                if let banner = store.banner {
                    bannerToast(banner)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                footerBar
            }
            .padding(14)
        }
        .frame(width: 406)
        .onAppear {
            store.setPopoverVisible(true)
        }
        .onDisappear {
            store.setPopoverVisible(false)
        }
    }

    // MARK: 1. Security Cockpit Header

    private var securityCockpitCard: some View {
        let healthy = store.allGuardsHealthy
        let cfg = store.envConfig

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10.5) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                        .fill(
                            healthy
                                ? AnthropicTheme.terracotta.opacity(0.14)
                                : AnthropicTheme.dangerFill
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                                .strokeBorder(
                                    healthy
                                        ? AnthropicTheme.terracotta.opacity(0.32)
                                        : AnthropicTheme.dangerBorder,
                                    lineWidth: 0.85
                                )
                        )
                        .frame(width: 35, height: 35)

                    ClaudeStarburstShape()
                        .fill(healthy ? AnthropicTheme.terracotta : AnthropicTheme.danger)
                        .frame(width: 18.5, height: 18.5)
                        .frame(width: 35, height: 35)

                    Circle()
                        .fill(healthy ? AnthropicTheme.sage : AnthropicTheme.danger)
                        .frame(width: 8.5, height: 8.5)
                        .overlay(
                            Circle()
                                .strokeBorder(AnthropicTheme.cardSurface, lineWidth: 1.5)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(healthy ? "\(cfg.regionDisplayName)安全环境舱" : "安全防护异常拦截")
                            .font(AnthropicFont.serif(size: 14.5, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.inkPrimary)

                        Text(healthy ? "已锁定" : "阻断中")
                            .font(AnthropicFont.sans(size: 9.5, weight: .semibold))
                            .foregroundStyle(healthy ? AnthropicTheme.sage : AnthropicTheme.danger)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(healthy ? AnthropicTheme.sageFill : AnthropicTheme.dangerFill)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                healthy ? AnthropicTheme.sageBorder : AnthropicTheme.dangerBorder,
                                                lineWidth: 0.7
                                            )
                                    )
                            )
                    }

                    Text("\(cfg.targetTimeZone) · Claude 强制纯英隔离")
                        .font(AnthropicFont.sans(size: 10, weight: .regular))
                        .foregroundStyle(AnthropicTheme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1.5) {
                    Text(store.targetClockDigits)
                        .font(AnthropicFont.mono(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AnthropicTheme.inkPrimary)

                    HStack(spacing: 4) {
                        Text(cfg.regionDisplayName)
                            .font(AnthropicFont.sans(size: 9.5, weight: .medium))
                            .foregroundStyle(AnthropicTheme.inkMuted)
                        Text(store.targetZoneAbbrev)
                            .font(AnthropicFont.mono(size: 9.5, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.terracotta)
                    }
                }
                .padding(.horizontal, 8.5)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AnthropicTheme.recessedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AnthropicTheme.borderSubtle, lineWidth: 0.75)
                        )
                )
            }

            HStack(spacing: 6) {
                telemetryTile(
                    ok: store.proxyOnline,
                    title: "住宅代理",
                    detail: store.proxyOnline ? "\(cfg.proxyPort) 在线" : "\(cfg.proxyPort) 离线"
                )
                telemetryTile(
                    ok: store.firewallHealthy,
                    title: cfg.firewallDisplayName,
                    detail: store.firewallHealthy ? "规则已锁" : "规则异常"
                )
                telemetryTile(
                    ok: !store.hasUnguardedInstance,
                    title: "客户端语言",
                    detail: store.hasUnguardedInstance ? "含未受控" : "en-US 纯英"
                )
            }

            Button {
                store.verifyExitIP()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: store.exitIPResult == nil ? "globe.americas.fill" : "checkmark.seal.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(store.exitIPResult == nil ? AnthropicTheme.terracotta : AnthropicTheme.sage)

                    if let ipInfo = store.exitIPResult {
                        Text("出口 IP: \(ipInfo.ip)")
                            .font(AnthropicFont.mono(size: 11, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.inkPrimary)
                        Text("· \(ipInfo.country) / \(ipInfo.colo)")
                            .font(AnthropicFont.mono(size: 10.5, weight: .medium))
                            .foregroundStyle(AnthropicTheme.inkMuted)
                    } else {
                        Text("点击校验 \(cfg.proxyEndpointString) 代理出口 IP")
                            .font(AnthropicFont.sans(size: 11, weight: .medium))
                            .foregroundStyle(AnthropicTheme.inkSecondary)
                    }

                    Spacer()

                    if store.isCheckingIP {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        HStack(spacing: 3.5) {
                            Text(store.exitIPResult == nil ? "立即检测" : "重新检测")
                                .font(AnthropicFont.sans(size: 10.5, weight: .semibold))
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundStyle(ipRowHovered ? AnthropicTheme.terracotta : AnthropicTheme.inkMuted)
                    }
                }
                .padding(.horizontal, 9.5)
                .padding(.vertical, 6.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ipRowHovered ? AnthropicTheme.controlFill : AnthropicTheme.recessedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    ipRowHovered ? AnthropicTheme.borderStrong : AnthropicTheme.borderSubtle,
                                    lineWidth: 0.75
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    ipRowHovered = hovering
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AnthropicTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            healthy ? AnthropicTheme.borderSubtle : AnthropicTheme.dangerBorder,
                            lineWidth: healthy ? 0.85 : 1.2
                        )
                )
        )
    }

    private func telemetryTile(ok: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? AnthropicTheme.sage : AnthropicTheme.danger)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(AnthropicFont.sans(size: 9.5, weight: .medium))
                    .foregroundStyle(AnthropicTheme.inkMuted)
                Text(detail)
                    .font(AnthropicFont.sans(size: 10.5, weight: .semibold))
                    .foregroundStyle(ok ? AnthropicTheme.inkPrimary : AnthropicTheme.danger)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8.5)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ok ? AnthropicTheme.recessedSurface : AnthropicTheme.dangerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            ok ? AnthropicTheme.borderSubtle : AnthropicTheme.dangerBorder,
                            lineWidth: 0.75
                        )
                )
        )
    }

    // MARK: 3. Toast & Footer

    private func bannerToast(_ item: BannerMessage) -> some View {
        HStack(spacing: 7.5) {
            Image(systemName: item.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.isError ? AnthropicTheme.danger : AnthropicTheme.terracotta)

            Text(item.text)
                .font(AnthropicFont.sans(size: 11.5, weight: .medium))
                .foregroundStyle(AnthropicTheme.inkPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10.5)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(item.isError ? AnthropicTheme.dangerFill : AnthropicTheme.cardElevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            item.isError ? AnthropicTheme.dangerBorder : AnthropicTheme.terracotta.opacity(0.35),
                            lineWidth: 0.85
                        )
                )
        )
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.toggleLaunchAtLogin($0) }
            )) {
                Text("开机自启")
                    .font(AnthropicFont.sans(size: 11.5, weight: .medium))
                    .foregroundStyle(AnthropicTheme.inkSecondary)
            }
            .toggleStyle(.switch)
            .tint(AnthropicTheme.terracotta)
            .controlSize(.mini)

            Text("· 仅组件中文，Claude 锁纯英")
                .font(AnthropicFont.sans(size: 10.5, weight: .regular))
                .foregroundStyle(AnthropicTheme.inkMuted)
                .lineLimit(1)

            Spacer()

            Button {
                store.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(refreshHovered ? AnthropicTheme.inkPrimary : AnthropicTheme.inkSecondary)
                    .frame(width: 24, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(refreshHovered ? AnthropicTheme.controlFill : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("刷新进程与防火墙状态")
            .onHover { refreshHovered = $0 }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .font(AnthropicFont.sans(size: 11.5, weight: .medium))
                    .foregroundStyle(quitHovered ? AnthropicTheme.inkPrimary : AnthropicTheme.inkSecondary)
                    .padding(.horizontal, 7.5)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(quitHovered ? AnthropicTheme.controlFill : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("仅退出顶部菜单栏切换组件（不影响运行中的 Claude）")
            .onHover { quitHovered = $0 }
        }
        .padding(.top, 1)
    }
}

// MARK: - Individual Account Card View

struct AccountCardView: View {
    @ObservedObject var store: SwitcherStore
    let account: AccountID

    @State private var cardHovered = false
    @State private var timerHovered = false

    var body: some View {
        let isCLIActive = store.activeCLIAccount == account
        let pid = store.desktopPID(account)
        let isDesktopOpen = pid != nil
        let otherAccount: AccountID = (account == .pro1) ? .pro2 : .pro1
        let isOtherDesktopOpen = store.isDesktopRunning(otherAccount)
        let cooldown = store.remainingCooldown(for: account)
        let isHighlighted = isCLIActive || isDesktopOpen

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10.5) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                            .fill(account.badgeGradient)
                            .overlay(
                                ClaudeStarburstShape()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 24, height: 24)
                                    .offset(x: 6, y: -5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 9.5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                            )

                        Text(account.shortBadge)
                            .font(AnthropicFont.serif(size: 13.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.980, green: 0.976, blue: 0.961))
                    }
                    .frame(width: 35, height: 35)

                    if isDesktopOpen {
                        Circle()
                            .fill(AnthropicTheme.sage)
                            .frame(width: 9.5, height: 9.5)
                            .overlay(
                                Circle()
                                    .strokeBorder(AnthropicTheme.cardSurface, lineWidth: 1.6)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(account.defaultTitle)
                            .font(AnthropicFont.serif(size: 14.5, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.inkPrimary)

                        if isCLIActive {
                            HStack(spacing: 3.5) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("终端默认")
                                    .font(AnthropicFont.sans(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(account.accentColor)
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(account.accentColor.opacity(0.13))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(account.accentColor.opacity(0.28), lineWidth: 0.7)
                                    )
                            )
                        }
                    }

                    if store.editingNoteFor == account {
                        HStack(spacing: 5) {
                            TextField("输入账号备注（如：主力号 / 写代码专用）", text: $store.editingNoteDraft)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .font(AnthropicFont.sans(size: 11))
                                .onSubmit {
                                    store.saveEditingNote()
                                }
                            Button("保存") {
                                store.saveEditingNote()
                            }
                            .controlSize(.small)
                        }
                    } else {
                        Button {
                            store.startEditingNote(for: account)
                        } label: {
                            HStack(spacing: 4) {
                                Text(store.note(for: account))
                                    .font(AnthropicFont.sans(size: 11, weight: .regular))
                                    .foregroundStyle(AnthropicTheme.inkMuted)
                                    .lineLimit(1)
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(AnthropicTheme.inkMuted.opacity(0.75))
                            }
                        }
                        .buttonStyle(.plain)
                        .help("点击修改账号备注")
                    }
                }

                Spacer(minLength: 4)

                if let runningPID = pid {
                    HStack(spacing: 4.5) {
                        Circle()
                            .fill(AnthropicTheme.sage)
                            .frame(width: 5.5, height: 5.5)
                        Text("桌面运行中")
                            .font(AnthropicFont.sans(size: 10.5, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.sage)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AnthropicTheme.sageFill)
                            .overlay(
                                Capsule()
                                    .strokeBorder(AnthropicTheme.sageBorder, lineWidth: 0.75)
                            )
                    )
                    .help("受保护桌面进程正在运行（PID \(runningPID) · \(store.envConfig.targetTimeZone) · 纯英文）")
                } else {
                    Text("桌面未启动")
                        .font(AnthropicFont.sans(size: 10.5, weight: .medium))
                        .foregroundStyle(AnthropicTheme.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AnthropicTheme.recessedSurface)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AnthropicTheme.borderSubtle, lineWidth: 0.7)
                                )
                        )
                }
            }

            if let remaining = cooldown {
                let progress = store.cooldownProgress(for: account)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AnthropicTheme.terracotta)
                        Text("额度恢复倒计时")
                            .font(AnthropicFont.sans(size: 11, weight: .medium))
                            .foregroundStyle(AnthropicTheme.inkSecondary)
                        Text(store.formatDuration(remaining))
                            .font(AnthropicFont.mono(size: 11.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(AnthropicTheme.terracotta)

                        Text("(\(store.cooldownReadyTimeText(for: account)) 恢复)")
                            .font(AnthropicFont.sans(size: 10.5))
                            .foregroundStyle(AnthropicTheme.inkMuted)

                        Spacer()

                        Button("清除") {
                            store.clearCooldown(for: account)
                        }
                        .buttonStyle(.plain)
                        .font(AnthropicFont.sans(size: 10.5, weight: .medium))
                        .foregroundStyle(AnthropicTheme.inkSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AnthropicTheme.terracotta.opacity(0.15))
                                .frame(height: 4.5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AnthropicTheme.terracotta, AnthropicTheme.terracottaDeep],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * progress), height: 4.5)
                        }
                    }
                    .frame(height: 4.5)
                }
                .padding(.horizontal, 9.5)
                .padding(.vertical, 7.5)
                .background(
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .fill(AnthropicTheme.terracotta.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .strokeBorder(AnthropicTheme.terracotta.opacity(0.24), lineWidth: 0.75)
                        )
                )
            }

            HStack(spacing: 6.5) {
                PrimaryCapsuleButton(
                    title: primaryActionTitle(isDesktopOpen: isDesktopOpen, isOtherDesktopOpen: isOtherDesktopOpen),
                    icon: primaryActionIcon(isDesktopOpen: isDesktopOpen, isOtherDesktopOpen: isOtherDesktopOpen),
                    gradient: account.primaryButtonGradient,
                    accent: AnthropicTheme.terracotta,
                    disabled: store.isBusy
                ) {
                    store.launchOrSwitchDesktop(to: account, closeOther: true)
                }

                if !isDesktopOpen && isOtherDesktopOpen {
                    SecondaryPillButton(
                        title: "双开共存",
                        icon: "plus.rectangle.on.rectangle",
                        disabled: store.isBusy,
                        helpText: "不关闭另一个账号窗口，同时启动两个独立隔离桌面"
                    ) {
                        store.launchOrSwitchDesktop(to: account, closeOther: false)
                    }
                } else if isDesktopOpen {
                    SecondaryPillButton(
                        title: "关闭桌面",
                        icon: "power",
                        isDestructive: true,
                        disabled: store.isBusy,
                        helpText: "优雅退出当前账号的 Claude 桌面窗口"
                    ) {
                        store.quitDesktopInstance(account)
                    }
                }

                if !isCLIActive {
                    SecondaryPillButton(
                        title: "仅切终端",
                        icon: "terminal",
                        disabled: false,
                        helpText: "仅将终端 claude 与 VSCode 默认账号切到此号，不改动桌面窗口"
                    ) {
                        store.switchCLIAccountOnly(to: account)
                    }
                }

                Menu {
                    Button("⏱ 开启 5 小时限流倒计时") {
                        store.markCooldown(for: account, hours: 5)
                    }
                    Button("⏱ 开启 3 小时恢复提醒") {
                        store.markCooldown(for: account, hours: 3)
                    }
                    Button("⏱ 开启 1 小时恢复提醒") {
                        store.markCooldown(for: account, hours: 1)
                    }
                    if cooldown != nil {
                        Divider()
                        Button("清除倒计时", role: .destructive) {
                            store.clearCooldown(for: account)
                        }
                    }
                } label: {
                    Image(systemName: cooldown == nil ? "clock.badge" : "timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(cooldown == nil ? AnthropicTheme.inkSecondary : AnthropicTheme.terracotta)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    cooldown != nil
                                        ? AnthropicTheme.terracotta.opacity(0.14)
                                        : (timerHovered ? AnthropicTheme.controlHoverFill : AnthropicTheme.controlFill)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            cooldown != nil
                                                ? AnthropicTheme.terracotta.opacity(0.32)
                                                : (timerHovered ? AnthropicTheme.borderStrong : AnthropicTheme.borderSubtle),
                                            lineWidth: 0.75
                                        )
                                )
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("纯本地限流恢复倒计时（零网络请求、不触碰 Cookie，绝对安全）")
                .onHover { timerHovered = $0 }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? AnthropicTheme.cardElevatedSurface : AnthropicTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isHighlighted
                                ? account.accentColor.opacity(cardHovered ? 0.055 : 0.038)
                                : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isHighlighted
                                ? account.accentColor.opacity(cardHovered ? 0.56 : 0.42)
                                : (cardHovered ? AnthropicTheme.borderStrong : AnthropicTheme.borderSubtle),
                            lineWidth: isHighlighted ? 1.15 : 0.85
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                cardHovered = hovering
            }
        }
    }

    private func primaryActionTitle(isDesktopOpen: Bool, isOtherDesktopOpen: Bool) -> String {
        if isDesktopOpen {
            return isOtherDesktopOpen ? "仅保留此窗口" : "激活窗口 · 同步终端"
        } else {
            return isOtherDesktopOpen ? "切换至此账号" : "安全启动桌面端"
        }
    }

    private func primaryActionIcon(isDesktopOpen: Bool, isOtherDesktopOpen: Bool) -> String {
        if isDesktopOpen {
            return isOtherDesktopOpen ? "macwindow" : "sparkles.rectangle.stack"
        } else {
            return isOtherDesktopOpen ? "arrow.left.arrow.right" : "bolt.shield.fill"
        }
    }
}

// MARK: - Cached Menu Bar Status Pill Renderer (Anthropic Starburst Capsule)

private struct MenuBarCapsuleKey: Equatable {
    let healthy: Bool
    let p1Running: Bool
    let p2Running: Bool
    let activeCLI: AccountID
    let title: String
}

@MainActor
enum MenuBarCapsuleRenderer {
    private static var cachedKey: MenuBarCapsuleKey?
    private static var cachedImage: NSImage?

    static func makeImage(
        healthy: Bool,
        p1Running: Bool,
        p2Running: Bool,
        activeCLI: AccountID,
        title: String
    ) -> NSImage {
        let key = MenuBarCapsuleKey(
            healthy: healthy,
            p1Running: p1Running,
            p2Running: p2Running,
            activeCLI: activeCLI,
            title: title
        )
        if let existing = cachedImage, cachedKey == key {
            return existing
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        let measureAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (title as NSString).size(withAttributes: measureAttrs)

        let dualDots = healthy && p1Running && p2Running
        let iconAreaWidth: CGFloat = dualDots ? 21.0 : 15.0
        let leftPad: CGFloat = 7.0
        let rightPad: CGFloat = 8.0
        let totalWidth = ceil(leftPad + iconAreaWidth + textSize.width + rightPad)
        let totalHeight: CGFloat = 20.0

        let img = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let pillRect = rect.insetBy(dx: 0.6, dy: 1.0)
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2.0, yRadius: pillRect.height / 2.0)

            if healthy {
                AnthropicTheme.nsTerracotta.withAlphaComponent(0.11).setFill()
                pillPath.fill()
                AnthropicTheme.nsTerracotta.withAlphaComponent(0.28).setStroke()
                pillPath.lineWidth = 0.8
                pillPath.stroke()
            } else {
                NSColor.systemRed.withAlphaComponent(0.16).setFill()
                pillPath.fill()
                NSColor.systemRed.withAlphaComponent(0.48).setStroke()
                pillPath.lineWidth = 0.9
                pillPath.stroke()
            }

            let centerY = rect.midY
            let starSize: CGFloat = 11.0

            if !healthy {
                let starRect = NSRect(x: leftPad, y: centerY - starSize / 2.0, width: starSize, height: starSize)
                ClaudeStarburstShape.drawInAppKit(rect: starRect, color: NSColor.systemRed)
            } else if dualDots {
                let starRect = NSRect(x: leftPad, y: centerY - starSize / 2.0, width: starSize, height: starSize)
                ClaudeStarburstShape.drawInAppKit(rect: starRect, color: AccountID.pro1.nsAccentColor)

                let dotSize: CGFloat = 6.2
                let r2 = NSRect(x: leftPad + 11.2, y: centerY - dotSize / 2.0, width: dotSize, height: dotSize)
                AccountID.pro2.nsAccentColor.setFill()
                NSBezierPath(ovalIn: r2).fill()
            } else if p1Running || p2Running {
                let activeColor = p1Running ? AccountID.pro1.nsAccentColor : AccountID.pro2.nsAccentColor
                let starRect = NSRect(x: leftPad, y: centerY - starSize / 2.0, width: starSize, height: starSize)
                ClaudeStarburstShape.drawInAppKit(rect: starRect, color: activeColor)
            } else {
                let starRect = NSRect(x: leftPad, y: centerY - starSize / 2.0, width: starSize, height: starSize)
                ClaudeStarburstShape.drawInAppKit(
                    rect: starRect,
                    color: activeCLI.nsAccentColor.withAlphaComponent(0.85)
                )
            }

            let drawAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: healthy ? NSColor.labelColor : NSColor.systemRed
            ]
            let textOrigin = NSPoint(
                x: leftPad + iconAreaWidth,
                y: floor((totalHeight - textSize.height) / 2.0) + 0.5
            )
            (title as NSString).draw(at: textOrigin, withAttributes: drawAttrs)
            return true
        }
        img.isTemplate = false
        cachedKey = key
        cachedImage = img
        return img
    }
}

// MARK: - App Entry

@main
struct ClaudeSwitcherBarApp: App {
    @StateObject private var store = SwitcherStore()

    var body: some Scene {
        MenuBarExtra {
            SwitcherPopoverView(store: store)
        } label: {
            Image(nsImage: MenuBarCapsuleRenderer.makeImage(
                healthy: store.allGuardsHealthy,
                p1Running: store.isDesktopRunning(.pro1),
                p2Running: store.isDesktopRunning(.pro2),
                activeCLI: store.activeCLIAccount,
                title: store.menuBarTitle
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
