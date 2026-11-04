import AppKit
import Foundation
import SwiftUI

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
        case .pro1: return Color(red: 0.18, green: 0.42, blue: 0.96)
        case .pro2: return Color(red: 0.04, green: 0.64, blue: 0.46)
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .pro1: return Color(red: 0.34, green: 0.30, blue: 0.92)
        case .pro2: return Color(red: 0.05, green: 0.56, blue: 0.58)
        }
    }

    var badgeGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, secondaryAccentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var nsAccentColor: NSColor {
        switch self {
        case .pro1: return NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.96, alpha: 1.0)
        case .pro2: return NSColor(calibratedRed: 0.04, green: 0.64, blue: 0.46, alpha: 1.0)
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

// MARK: - Tactile Interactive Button Components

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
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
                    .shadow(color: accent.opacity(isHovered ? 0.34 : 0.18), radius: isHovered ? 7 : 4, x: 0, y: 2)
            )
            .opacity(disabled ? 0.55 : 1.0)
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
                        .font(.system(size: 10.5, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isDestructive && isHovered ? Color.red : Color.primary.opacity(0.88))
            .frame(height: 30)
            .padding(.horizontal, 9)
            .background(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .fill(
                        isDestructive && isHovered
                            ? Color.red.opacity(0.12)
                            : Color.primary.opacity(isHovered ? 0.10 : 0.055)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .strokeBorder(
                                isDestructive && isHovered
                                    ? Color.red.opacity(0.35)
                                    : Color.primary.opacity(isHovered ? 0.16 : 0.09),
                                lineWidth: 0.8
                            )
                    )
            )
            .opacity(disabled ? 0.5 : 1.0)
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
            RadialGradient(
                colors: [
                    store.ambientAccentColor.opacity(0.16),
                    store.ambientAccentColor.opacity(0.04),
                    Color.clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 210
            )
            .frame(height: 185)
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
        .frame(width: 386)
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
        let shieldColors: [Color] = healthy
            ? [Color(red: 0.06, green: 0.72, blue: 0.50), Color(red: 0.04, green: 0.52, blue: 0.44)]
            : [Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.78, green: 0.16, blue: 0.22)]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: shieldColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .shadow(color: shieldColors[0].opacity(0.28), radius: 5, x: 0, y: 2)

                    Image(systemName: healthy ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(healthy ? "\(cfg.regionDisplayName)安全环境舱" : "安全防护异常拦截")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(healthy ? "已锁定" : "阻断中")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(healthy ? Color(red: 0.05, green: 0.65, blue: 0.45) : Color.red)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(healthy ? Color.green.opacity(0.14) : Color.red.opacity(0.15))
                            )
                    }

                    Text("\(cfg.targetTimeZone) · Claude 强制纯英隔离")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1.5) {
                    Text(store.targetClockDigits)
                        .font(.system(size: 15.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(cfg.regionDisplayName)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(store.targetZoneAbbrev)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8.5)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
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
                        .foregroundStyle(store.exitIPResult == nil ? Color.secondary : Color(red: 0.05, green: 0.65, blue: 0.45))

                    if let ipInfo = store.exitIPResult {
                        Text("出口 IP: \(ipInfo.ip)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("· \(ipInfo.country) / \(ipInfo.colo)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("点击校验 \(cfg.proxyEndpointString) 代理出口 IP")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if store.isCheckingIP {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        HStack(spacing: 3) {
                            Text(store.exitIPResult == nil ? "立即检测" : "重新检测")
                                .font(.system(size: 10.5, weight: .semibold))
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 9.5)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(ipRowHovered ? 0.075 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(ipRowHovered ? 0.13 : 0.06), lineWidth: 0.8)
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
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.038))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            healthy ? Color.primary.opacity(0.09) : Color.red.opacity(0.45),
                            lineWidth: healthy ? 1.0 : 1.3
                        )
                )
        )
    }

    private func telemetryTile(ok: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 5.5) {
            Circle()
                .fill(ok ? Color(red: 0.08, green: 0.75, blue: 0.48) : Color.red)
                .frame(width: 6.5, height: 6.5)
                .shadow(color: (ok ? Color.green : Color.red).opacity(0.45), radius: 2.5)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ok ? Color.primary : Color.red)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5.5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ok ? Color.primary.opacity(0.038) : Color.red.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ok ? Color.primary.opacity(0.06) : Color.red.opacity(0.28), lineWidth: 0.8)
                )
        )
    }

    // MARK: 3. Toast & Footer

    private func bannerToast(_ item: BannerMessage) -> some View {
        HStack(spacing: 7) {
            Image(systemName: item.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.isError ? Color.red : Color(red: 0.06, green: 0.70, blue: 0.46))

            Text(item.text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7.5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(item.isError ? Color.red.opacity(0.11) : Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            item.isError ? Color.red.opacity(0.30) : Color.primary.opacity(0.10),
                            lineWidth: 0.8
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
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Text("· 仅组件中文，Claude 锁纯英")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()

            Button {
                store.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(refreshHovered ? .primary : .secondary)
                    .frame(width: 24, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(refreshHovered ? 0.08 : 0.0))
                    )
            }
            .buttonStyle(.plain)
            .help("刷新进程与防火墙状态")
            .onHover { refreshHovered = $0 }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(quitHovered ? .primary : .secondary)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(quitHovered ? 0.08 : 0.0))
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
            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Text(account.shortBadge)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(account.badgeGradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                                )
                                .shadow(color: account.accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
                        )

                    if isDesktopOpen {
                        Circle()
                            .fill(Color(red: 0.10, green: 0.78, blue: 0.48))
                            .frame(width: 9.5, height: 9.5)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.6)
                            )
                            .offset(x: 2.5, y: 2.5)
                    }
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(account.defaultTitle)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.primary)

                        if isCLIActive {
                            HStack(spacing: 3) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 8.5, weight: .bold))
                                Text("终端默认")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(account.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(account.accentColor.opacity(0.14))
                            )
                        }
                    }

                    if store.editingNoteFor == account {
                        HStack(spacing: 5) {
                            TextField("输入账号备注（如：主力号 / 写代码专用）", text: $store.editingNoteDraft)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .font(.system(size: 11))
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
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
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
                            .fill(Color(red: 0.08, green: 0.75, blue: 0.48))
                            .frame(width: 6, height: 6)
                        Text("桌面运行中")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.62, blue: 0.42))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.green.opacity(0.24), lineWidth: 0.8)
                            )
                    )
                    .help("受保护桌面进程正在运行（PID \(runningPID) · \(store.envConfig.targetTimeZone) · 纯英文）")
                } else {
                    Text("桌面未启动")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }

            if let remaining = cooldown {
                let progress = store.cooldownProgress(for: account)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("额度恢复倒计时")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(store.formatDuration(remaining))
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.orange)

                        Text("(\(store.cooldownReadyTimeText(for: account)) 恢复)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Button("清除") {
                            store.clearCooldown(for: account)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.orange.opacity(0.16))
                                .frame(height: 4.5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, account.accentColor],
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
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.22), lineWidth: 0.8)
                        )
                )
            }

            HStack(spacing: 6.5) {
                PrimaryCapsuleButton(
                    title: primaryActionTitle(isDesktopOpen: isDesktopOpen, isOtherDesktopOpen: isOtherDesktopOpen),
                    icon: primaryActionIcon(isDesktopOpen: isDesktopOpen, isOtherDesktopOpen: isOtherDesktopOpen),
                    gradient: account.badgeGradient,
                    accent: account.accentColor,
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
                        .foregroundStyle(cooldown == nil ? Color.secondary : Color.orange)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(
                                    cooldown != nil
                                        ? Color.orange.opacity(0.14)
                                        : Color.primary.opacity(timerHovered ? 0.10 : 0.055)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                        .strokeBorder(
                                            cooldown != nil
                                                ? Color.orange.opacity(0.32)
                                                : Color.primary.opacity(0.09),
                                            lineWidth: 0.8
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
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    isHighlighted
                        ? account.accentColor.opacity(cardHovered ? 0.085 : 0.065)
                        : Color.primary.opacity(cardHovered ? 0.048 : 0.03)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isHighlighted
                                ? account.accentColor.opacity(cardHovered ? 0.55 : 0.42)
                                : Color.primary.opacity(cardHovered ? 0.15 : 0.08),
                            lineWidth: isHighlighted ? 1.25 : 1.0
                        )
                )
                .shadow(
                    color: isHighlighted ? account.accentColor.opacity(0.08) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 2
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

// MARK: - Cached Menu Bar Status Pill Renderer

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
        let dotAreaWidth: CGFloat = dualDots ? 18.5 : 12.0
        let leftPad: CGFloat = 7.5
        let rightPad: CGFloat = 8.0
        let totalWidth = ceil(leftPad + dotAreaWidth + textSize.width + rightPad)
        let totalHeight: CGFloat = 20.0

        let img = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let pillRect = rect.insetBy(dx: 0.6, dy: 1.0)
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2.0, yRadius: pillRect.height / 2.0)

            if healthy {
                NSColor.labelColor.withAlphaComponent(0.08).setFill()
                pillPath.fill()
                NSColor.labelColor.withAlphaComponent(0.16).setStroke()
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
            let dotSize: CGFloat = 7.0

            if !healthy {
                let haloRect = NSRect(x: leftPad - 1.5, y: centerY - (dotSize + 3.0) / 2.0, width: dotSize + 3.0, height: dotSize + 3.0)
                NSColor.systemRed.withAlphaComponent(0.28).setFill()
                NSBezierPath(ovalIn: haloRect).fill()

                let dotRect = NSRect(x: leftPad, y: centerY - dotSize / 2.0, width: dotSize, height: dotSize)
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else if dualDots {
                let r1 = NSRect(x: leftPad, y: centerY - dotSize / 2.0, width: dotSize, height: dotSize)
                AccountID.pro1.nsAccentColor.setFill()
                NSBezierPath(ovalIn: r1).fill()

                let r2 = NSRect(x: leftPad + 6.2, y: centerY - dotSize / 2.0, width: dotSize, height: dotSize)
                AccountID.pro2.nsAccentColor.setFill()
                let p2Path = NSBezierPath(ovalIn: r2)
                p2Path.fill()
                NSColor.windowBackgroundColor.withAlphaComponent(0.75).setStroke()
                p2Path.lineWidth = 0.9
                p2Path.stroke()
            } else if p1Running || p2Running {
                let activeColor = p1Running ? AccountID.pro1.nsAccentColor : AccountID.pro2.nsAccentColor
                let haloRect = NSRect(x: leftPad - 1.6, y: centerY - (dotSize + 3.2) / 2.0, width: dotSize + 3.2, height: dotSize + 3.2)
                activeColor.withAlphaComponent(0.24).setFill()
                NSBezierPath(ovalIn: haloRect).fill()

                let dotRect = NSRect(x: leftPad, y: centerY - dotSize / 2.0, width: dotSize, height: dotSize)
                activeColor.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else {
                let ringSize: CGFloat = 6.6
                let ringRect = NSRect(x: leftPad + 0.2, y: centerY - ringSize / 2.0, width: ringSize, height: ringSize)
                let ringPath = NSBezierPath(ovalIn: ringRect)
                activeCLI.nsAccentColor.withAlphaComponent(0.20).setFill()
                ringPath.fill()
                activeCLI.nsAccentColor.setStroke()
                ringPath.lineWidth = 1.6
                ringPath.stroke()
            }

            let drawAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: healthy ? NSColor.labelColor : NSColor.systemRed
            ]
            let textOrigin = NSPoint(
                x: leftPad + dotAreaWidth,
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
