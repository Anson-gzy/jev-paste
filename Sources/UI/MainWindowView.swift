import SwiftUI
import AppKit

@MainActor
public enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case playground = "playground"
    case settings = "settings"
    
    nonisolated public static var allCases: [NavigationSection] {
        [.dashboard, .playground, .settings]
    }

    nonisolated public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dashboard: return L("nav.dashboard")
        case .playground: return L("nav.playground")
        case .settings: return L("nav.settings")
        }
    }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.needle"
        case .playground: return "sparkles.rectangle.stack"
        case .settings: return "gearshape"
        }
    }
}

/// 主控制台 ViewModel
@MainActor
public final class MainAppViewModel: ObservableObject {
    public static let shared = MainAppViewModel()
    
    @Published public var isServiceRunning: Bool = true
    @Published public var hasAccessibilityPermission: Bool = false
    @Published public var currentClipboardText: String = ""
    @Published public var pasteCount: Int = 0
    
    // 互动实验室中的测试状态
    @Published public var labClipboardInput: String = """
    Can we file “Keep draft text when switching workspaces”? Switching workspaces clears the issue draft. Preserve the title and description until the issue is created or discarded. Also, the address is Ferry Building, 1 Ferry Building, San Francisco, CA 94111.
    """
    @Published public var labTitle: String = ""
    @Published public var labDescription: String = ""
    @Published public var labLocation: String = ""
    @Published public var labActiveGhostField: String? = nil
    @Published public var labGhostText: String = ""
    
    private var permissionPollTimer: Timer?
    
    private init() {
        refreshStatus()
        startPermissionPolling()
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshStatus()
            }
        }
    }
    
    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshStatus()
            }
        }
    }
    
    public func refreshStatus() {
        let granted = AXFocusMonitor.shared.checkAccessibilityPermission()
        let previouslyMissing = !self.hasAccessibilityPermission
        self.hasAccessibilityPermission = granted
        self.currentClipboardText = ClipboardMonitor.shared.readCurrent() ?? ""
        
        // 关键：一旦用户从系统设置完成授权，立即自动重新拉起按键拦截与焦点监控，无需重启 App！
        if granted && previouslyMissing {
            NSLog("[MainAppViewModel] Accessibility permission newly granted! Restarting coordinator and interceptor.")
            TabKeyInterceptor.shared.start()
            AXFocusMonitor.shared.start()
        }
    }
    
    public func toggleService() {
        isServiceRunning.toggle()
        if isServiceRunning {
            SmartPasteCoordinator.shared.start()
        } else {
            ClipboardMonitor.shared.stop()
            AXFocusMonitor.shared.stop()
            TabKeyInterceptor.shared.stop()
            GhostOverlayController.shared.hide()
        }
    }
    
    public func copyLabTextToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(labClipboardInput, forType: .string)
        self.currentClipboardText = labClipboardInput
        SmartPasteCoordinator.shared.precomputeClipboard(labClipboardInput)
    }
    
    public func suggestedValue(for kind: FieldKind, defaultVal: String) -> String {
        let clip = currentClipboardText.isEmpty ? labClipboardInput : currentClipboardText
        let targetField = FormField(id: "f0", kind: kind, label: kind.displayName)
        let ctx = FormContext(heading: "Form", fields: [targetField])
        let spans = (try? SmartPasteBridge().extractCandidates(from: clip)) ?? []
        let matched = LocalHeuristicEngine.shared.match(text: clip, context: ctx, spans: spans)
        if let first = matched.first(where: { $0.kind == kind && !$0.text.isEmpty }) {
            return first.text
        }
        return defaultVal
    }
}

/// 主控制台视图
public struct MainWindowView: View {
    @StateObject private var viewModel = MainAppViewModel.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var historyManager = ClipboardHistoryManager.shared
    @State private var selectedSection: NavigationSection = .dashboard
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // 左侧导航栏
            List(NavigationSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.iconName)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, idealWidth: 200)
            
            // 底部运行指示与检查更新 (位于 Active 正上方)
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                // 检查更新区域
                updateCheckSection
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isServiceRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isServiceRunning ? (loc.currentLanguage == .zhHans ? "服务运行中" : "Active") : (loc.currentLanguage == .zhHans ? "已暂停" : "Paused"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        } detail: {
            // 右侧内容区
            Group {
                switch selectedSection {
                case .dashboard:
                    dashboardView
                case .playground:
                    playgroundView
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 500, minHeight: 480)
        }
        .onAppear {
            viewModel.refreshStatus()
        }
    }
    
    // MARK: - Dashboard
    private var dashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 顶部 Banner
                HStack(spacing: 16) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("dash.title"))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(L("dash.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // 启停大开关
                    Toggle("", isOn: Binding(
                        get: { viewModel.isServiceRunning },
                        set: { _ in viewModel.toggleService() }
                    ))
                    .toggleStyle(.switch)
                }
                .padding(18)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                
                // 系统状态卡片网格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    statusCard(
                        title: L("dash.perm.title"),
                        status: viewModel.hasAccessibilityPermission ? L("dash.perm.granted") : L("dash.perm.missing"),
                        icon: "hand.raised.fill",
                        color: viewModel.hasAccessibilityPermission ? .green : .orange,
                        actionTitle: viewModel.hasAccessibilityPermission ? nil : L("dash.perm.btn"),
                        action: {
                            _ = AXFocusMonitor.shared.requestAccessibilityPermission()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                    
                    statusCard(
                        title: loc.currentLanguage == .zhHans ? "触发快捷键" : "Paste Trigger",
                        status: loc.currentLanguage == .zhHans ? "按住 Tab 键 ⇥" : "Press Tab ⇥",
                        icon: "keyboard.fill",
                        color: .blue,
                        actionTitle: nil,
                        action: nil
                    )
                }
                
                // 剪贴板实时监视器
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label(L("dash.clip.title"), systemImage: "waveform.path.ecg")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Text("\(historyManager.historyItems.count) \(loc.currentLanguage == .zhHans ? "条历史" : "items") (\(historyManager.retentionPeriod.displayName))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                            
                            Text("\(viewModel.currentClipboardText.count) \(L("dash.stat.charsCaptured"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if viewModel.currentClipboardText.isEmpty {
                        Text(L("dash.clip.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(8)
                    } else {
                        ScrollView {
                            Text(viewModel.currentClipboardText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(maxHeight: 120)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                
                // 快捷指南 (克制去 AI 味)
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .zhHans ? "使用说明：" : "How to Use:")
                        .font(.headline)
                    
                    if loc.currentLanguage == .zhHans {
                        guideRow(step: "1", text: "复制任意包含标题、描述、日期、地点或联系方式的文本。")
                        guideRow(step: "2", text: "在任意 Mac 应用（微信、邮件、备忘录、浏览器等）中点击输入框。")
                        guideRow(step: "3", text: "输入框内部将以浅色半透明自动显示匹配的候选内容。")
                        guideRow(step: "4", text: "按下 Tab 键完成填入（原有旧字自动清空替换，系统的 ⌘V 完全不受影响）。")
                    } else {
                        guideRow(step: "1", text: "Copy any text containing tasks, dates, contacts, or addresses.")
                        guideRow(step: "2", text: "Click to focus into any text input in any Mac app.")
                        guideRow(step: "3", text: "Smart Paste displays an inline semi-transparent ghost hint.")
                        guideRow(step: "4", text: "Press Tab to paste and replace existing text. Native ⌘V is 100% untouched.")
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
    
    // MARK: - Update Check Section (位于侧边栏底部 Active 正上方)
    private var updateCheckSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("v\(UpdateChecker.currentVersion)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                switch updateChecker.status {
                case .idle:
                    Button(action: {
                        updateChecker.checkForUpdates()
                    }) {
                        Text(loc.currentLanguage == .zhHans ? "检查更新" : "Check Updates")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    
                case .checking:
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(loc.currentLanguage == .zhHans ? "检查中..." : "Checking...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                case .upToDate:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(loc.currentLanguage == .zhHans ? "已是最新" : "Up to date")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                case .updateAvailable(let ver, let url):
                    Button(action: {
                        updateChecker.openUpdateURL(url)
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(loc.currentLanguage == .zhHans ? "发现新版本 \(ver)" : "Update \(ver)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    
                case .failed:
                    Button(action: {
                        updateChecker.checkForUpdates()
                    }) {
                        Text(loc.currentLanguage == .zhHans ? "重试" : "Retry")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }
    
    // MARK: - Web Demo View (跳转 Demo 网页)
    private var playgroundView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("play.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(L("play.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // 网页 Demo 启动卡片
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schedule Q&A Extraction Workbench")
                                .font(.headline)
                            Text(loc.currentLanguage == .zhHans ? "基于真实网页 DOM 与 Accessibility 树的高精度测试环境" : "High-fidelity workbench powered by real Web DOM & Accessibility trees.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc.currentLanguage == .zhHans ? "演示文件：" : "Demo Asset:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("demo/index.html")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            openWebDemo()
                        }) {
                            Label(L("play.sample.copyBtn"), systemImage: "arrow.up.right.square.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(18)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                
                // 操作引导步骤
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.currentLanguage == .zhHans ? "体验流程与操作说明：" : "Interactive Instructions:")
                        .font(.headline)
                    
                    if loc.currentLanguage == .zhHans {
                        guideRow(step: "1", text: "点击上方按钮在 Safari 或系统默认浏览器中打开演示工作台。")
                        guideRow(step: "2", text: "直接复制左侧日程文档（如 Global AI Summit 或 Silicon Valley Tour）中的全部文本。")
                        guideRow(step: "3", text: "依次点击右侧的 4 个问答输入框（Location、Dates、Keynote、Deadline）。")
                        guideRow(step: "4", text: "输入框内将即时显示 0ms 匹配的浅色建议，按住 Tab 键即可瞬间覆盖填入！")
                    } else {
                        guideRow(step: "1", text: "Click the button above to launch the demo workbench in your browser.")
                        guideRow(step: "2", text: "Copy the complete schedule text from the left pane (Summit or Tour itinerary).")
                        guideRow(step: "3", text: "Click into each of the 4 QA input fields (Location, Dates, Keynote, Deadline).")
                        guideRow(step: "4", text: "Watch the 0ms ghost prediction appear, and press Tab to paste and replace instantly.")
                    }
                }
                .padding(18)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
    
    /// 在默认浏览器中打开 Demo 网页
    private func openWebDemo() {
        if let demoUrl = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "demo") ??
                         Bundle.main.url(forResource: "index", withExtension: "html") {
            NSWorkspace.shared.open(demoUrl)
            return
        }
        
        let candidatePaths = [
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("demo/index.html"),
            URL(fileURLWithPath: "/Users/guziyang/projects/playground/sandboxes/smart-paste-mac/demo/index.html")
        ]
        
        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p.path) {
                NSWorkspace.shared.open(p)
                return
            }
        }
    }
    
    private func statusCard(title: String, status: String, icon: String, color: Color, actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if let actTitle = actionTitle, let act = action {
                Button(actTitle, action: act)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(10)
    }
    
    private func guideRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
