# Claude Switcher Bar

一款轻量的原生 macOS 顶部菜单栏双账号切换组件（Swift + SwiftUI，无 Electron / WebView 依赖，常驻物理内存仅 ~35 MB，静置 CPU 接近 0%），用于在受控时区与代理环境下安全管理两个独立的 **Claude Desktop** 与 **Claude Code (CLI / VSCode)** 账号环境。

## 核心特性

- **原生轻量架构**：单文件纯 SwiftUI + AppKit 编译，支持 macOS 14.0+（Apple Silicon / Intel），收起弹窗时自动进入零功耗休眠轮询并缓存菜单栏胶囊图像。
- **组件中文界面 · 客户端强制纯英隔离**：
  - 菜单栏组件自身采用清晰的原生中文界面。
  - 启动子进程时严格注入 `LANG=en_US.UTF-8`、`LC_ALL=en_US.UTF-8` 与指定时区（如 `America/New_York`），确保 Claude 客户端本体保持 100% 纯英文环境，不暴露宿主机语言指纹。
- **双账号完全隔离（`Pro 1` / `Pro 2`）**：
  - 支持**一键单窗口切换**、**双窗口隔离共存（Dual-Open）**，以及**仅切换终端 / VSCode 默认账号**。
  - 自动检测进程是否携带 `CLAUDE_NETWORK_GUARD=1` 受控标记，发现未受控裸奔进程时主动阻断启动。
- **安全环境遥测舱**：
  - 实时显示目标时区时钟、本地代理端口在线状态、可选本地防火墙规则巡检状态，以及基于 `cloudflare.com/cdn-cgi/trace` 的一键代理出口 IP 节点检测。
- **100% 纯本地限流恢复倒计时**：
  - 内置 5h / 3h / 1h 可视化额度恢复进度条与系统通知提醒。
  - **零风控隐患**：绝不读取任何客户端 Cookie / OAuth Token，也不请求任何非公开接口。

## 编译与安装

确保已安装 Xcode 或 Xcode Command Line Tools，直接运行构建脚本即可生成签名后的 `.app` 到 `~/Applications/Claude Switcher.app`：

```bash
chmod +x build.sh
./build.sh
open "$HOME/Applications/Claude Switcher.app"
```

## 本地环境配置（可选）

组件运行时会读取本地配置目录 `~/Library/Application Support/ClaudeAccountSwitcher/switcher-config.json`（未创建时使用内置通用默认值）。可参考仓库中的 [`config.example.json`](./config.example.json) 按需自定义：

```bash
mkdir -p "$HOME/Library/Application Support/ClaudeAccountSwitcher"
cp config.example.json "$HOME/Library/Application Support/ClaudeAccountSwitcher/switcher-config.json"
```

| 字段 | 说明 | 默认值 |
| --- | --- | --- |
| `proxyHost` | 本地代理监听地址 | `"127.0.0.1"` |
| `proxyPort` | 本地代理端口 | `7890` |
| `targetTimeZone` | 启动子进程注入的 IANA 时区 | `"America/New_York"` |
| `regionDisplayName` | 界面顶部环境舱区域显示名 | `"纽约"` |
| `tzLauncherPath` | 受控时区启动器可执行文件路径 | `"~/Applications/Claude Timezone Launcher.app/Contents/MacOS/launcher"` |
| `firewallCheckScript` | 可选防火墙健康检查脚本路径（返回 `0` 视为正常） | `""` |
| `requireFirewallCheck` | 是否强制要求防火墙检查通过才允许启动（Fail-Closed） | `false` |
| `firewallDisplayName` | 防火墙状态卡片标题 | `"本地防火墙"` |

## License

[MIT](./LICENSE)
