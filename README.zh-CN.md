# jev-paste (macOS 原生智能粘贴)

<p align="center">
  <b>基于 TypeSafe JEF 的原生 macOS 智能内联粘贴工具 · 历史全量时间加权 · 零浮窗内联体验</b>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/语言-Swift%206-orange?style=flat-square" alt="Swift 6">
  <img src="https://img.shields.io/badge/协议-MIT-green?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/引擎-TypeSafe%20JEF-purple?style=flat-square" alt="TypeSafe JEF">
  <img src="https://img.shields.io/badge/状态-纯菜单栏常驻-lightgrey?style=flat-square" alt="Menu Bar Only">
</p>

---

## 项目介绍

**jev-paste** 是一款专为 macOS 设计的智能剪贴板实体提取与内联补全工具。

当你复制大段复杂文本（如会议日程通知、行程单、工单反馈、邮件往来或通讯录名片）时，**jev-paste** 会自动在本地对文本进行实体解构，提炼出独立的**标题、详细描述、活动日期、场馆地点、主讲人、报名截止期限、邮箱与电话**等结构化信息。

当你在 Mac 的任意软件中点击相关输入框时，**jev-paste** 会以内联形式在输入框内部呈现带有 `[Tab ⇥]` 状态徽标的浅色候选字。按下 **Tab 键**即可瞬间填入，并彻底清空覆盖原有的草稿文字；系统的原生 **⌘V** 快捷键完全不受任何干扰。

```
+-------------------------------------------------------------------------+
|  复制长段文本       -> JEF 自动拆分实体并按时间加权存入内存与磁盘         |
|  聚焦目标输入框     -> 输入框首部呈现 [Tab ⇥] 浅色建议，完全遮盖原有占位符|
|  按下 Tab 键        -> 瞬间填入匹配内容，覆盖旧字；打字或 Esc 即刻隐藏   |
|  按下 ⌘V 键         -> 系统原生粘贴完全放行，习惯 100% 保持              |
+-------------------------------------------------------------------------+
```

---

## 核心特性

- **全量历史剪贴板与时间衰减加权推荐**：
  持久化保留所有复制过的剪贴板历史，采用 6 小时半衰期指数衰减模型。越新复制的内容权重越高，即使历史剪贴板中有旧的会议地址，系统也会自动优选推荐最新的地点，同时老历史记录中的特定信息依然可被精准检索。
- **可自定义保留期限（默认 1 天）**：
  默认保留 1 天（24 小时），支持在偏好设置中自由调整为 1小时、12小时、1天、3天、7天、30天或永久保留。条目在 Application Support 目录中原子化落盘，重启不丢。
- **智能推荐决策门禁（先识别是否应该推荐再推荐）**：
  拒绝盲目无脑弹窗打扰！系统会自动识别输入场景：搜索框、浏览器 URL 栏、过滤栏、密码/PIN 框、以及未命名普通空白框自动保持静默；仅在有明确结构化表单需求且语义高置信度（$\ge 0.55$）匹配时才精准呈现。
- **严格非文本输入过滤**：
  针对滑块、复选框、单选钮、列表行、表格单元格、只读文本等 20 余种非文本控件建立底层黑名单与选区能力校验，彻底消除非文本区域误判。
- **100% 占位符遮挡与最左侧 `[Tab ⇥]` 徽标**：
  采用完全不透明自适应文本背景，彻底遮盖输入框底部的自带占位符（如 *Search*、*输入姓名*、*iMessage*），杜绝重合重影；最左侧带有精致紧凑的 `[Tab ⇥]` 快捷键徽标，一目了然。
- **打字瞬间退散 & 鼠标无感穿透**：
  用户只要敲击键盘输入任意字符、退格或按 Esc，浮层在 0ms 内瞬间隐藏，绝不遮挡视线；鼠标事件完全穿透，自由点击定位光标。
- **内置 Schedule Q&A 真实网页 Demo**：
  项目内含基于 Vercel Geist 设计风格的日程问答提取演示工作台（位于 `demo/index.html`），可一键在默认浏览器中打开体验。
- **纯菜单栏常驻（不占程序坞）**：
  配置 `LSUIElement = true`，不占用 Dock 程序坞图标，仅常驻在屏幕右上角菜单栏。
- **稳定代码签名与开箱即用**：
  使用稳定的代码需求绑定（`identifier "ai.typesafe.jev-paste"`），更新或重启应用无需重新授予辅助功能权限，不再反复弹密码框。

---

## 架构与工作机制

```
系统剪贴板复制事件 (⌘C)
       │
       ▼
[ClipboardMonitor 剪贴板监听]
       │ (同步写入 ClipboardHistoryManager 与磁盘持久化)
       ├─────────────────────────────────┐
       ▼                                 ▼
[LocalHeuristicEngine]          [TypeSafe JEF 引擎]
 (离线启发式毫秒级提取)             (后台云端校准)
       │                                 │
       └──────────────┬──────────────────┘
                      ▼
            [时间衰减加权推荐算法]
                      │
   用户在任意 Mac 软件 / 浏览器中点击输入框
                      │
                      ▼
              [AXFocusMonitor]
        (过滤非文本控件，检查选区与可写属性)
                      │
                      ▼
             [shouldRecommend?]
        (智能门禁：拦截搜索框、密码框与弱语义框)
                      │
                      ▼
           [GhostOverlayController]
        (完全不透明内衬，首部 [Tab ⇥] 悬浮建议)
                      │
             用户按下 Tab 键
                      │
                      ▼
             [TabKeyInterceptor]
        (通过 Accessibility API 清空并替换新字)
```

---

## 编译与安装

### 系统要求
- macOS 14.0 或更高版本（支持 Apple Silicon 与 Intel）
- Xcode 命令行工具（终端执行 `xcode-select --install`）

### 编译与安装到 `/Applications`

```bash
# 克隆仓库
git clone https://github.com/Anson-gzy/jev-paste.git
cd jev-paste

# 执行单元测试套件（42 项测试全通）
make test

# 一键编译并安装至系统的 /Applications/jev-paste.app
make install
```

### 授予辅助功能权限
首次启动应用时，macOS 会主动弹出授权对话框：
1. 点击系统弹窗中的 **打开系统设置**（或在应用主面板点击“前往系统设置授权”）；
2. 在列表里找到 **jev-paste** 并打开开关；
3. 切回应用，Jev Paste 会动态自动感知变为绿色“已授权”，即刻可用，无需重启。

---

## 偏好设置

通过菜单栏图标或在主控制台按下 **⌘O** 打开偏好设置：

- **剪贴板历史与保留期**：自定义历史保留期限（1 小时 ~ 永久），查看当前缓存条目数，支持一键清空；
- **界面语言**：支持 **English**（默认主语言）与 **简体中文** 之间即时无缝切换；
- **TypeSafe JEF API**：安全保存在系统 Keychain 中，连接云端 JEF 引擎获取更深度的语义推断；
- **检查更新**：主控制台侧边栏底部提供一键检查 GitHub 最新 Release 功能。

---

## 协议

本项目基于 [MIT 协议](LICENSE) 开源。
