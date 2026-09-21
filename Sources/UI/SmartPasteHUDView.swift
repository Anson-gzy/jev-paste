import SwiftUI
import AppKit

/// 智能粘贴主面板 ViewModel
@MainActor
public final class HUDViewModel: ObservableObject {
    @Published public var rawText: String = ""
    @Published public var selectedPreset: FormPreset = .smartDetect
    @Published public var fields: [VerifiedField] = []
    @Published public var selectedFieldIndex: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var isAiVerified: Bool = false
    @Published public var isShowingRawText: Bool = false
    @Published public var editingFieldId: String? = nil
    
    public var previousApp: NSRunningApplication?
    
    private var bridge: SmartPasteBridge?
    private var typeSafeClient: TypeSafeClient?
    
    public init() {
        do {
            let b = try SmartPasteBridge()
            self.bridge = b
            self.typeSafeClient = TypeSafeClient(bridge: b)
        } catch {
            NSLog("[HUDViewModel] Failed to initialize bridge: %@", error.localizedDescription)
        }
    }
    
    /// 当浮窗被唤起时加载并分析当前剪贴板
    public func loadAndAnalyze(text: String, targetApp: NSRunningApplication? = nil) {
        self.rawText = text
        self.previousApp = targetApp
        self.selectedFieldIndex = 0
        self.editingFieldId = nil
        analyze()
    }
    
    /// 触发解析
    public func analyze() {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fields = []
            statusMessage = "Clipboard is empty"
            return
        }
        
        isLoading = true
        statusMessage = "Analyzing passages…"
        
        let currentText = self.rawText
        let context = self.selectedPreset.context
        let apiKey = KeychainHelper.shared.getApiKey()
        
        Task {
            let matchedFields: [VerifiedField]
            if let client = self.typeSafeClient {
                matchedFields = await client.parse(text: currentText, context: context, apiKey: apiKey)
            } else {
                matchedFields = LocalHeuristicEngine.shared.match(
                    text: currentText,
                    context: context,
                    spans: []
                )
            }
            
            await MainActor.run {
                self.fields = matchedFields
                self.isAiVerified = matchedFields.contains(where: { $0.isAiVerified })
                self.isLoading = false
                if matchedFields.isEmpty {
                    self.statusMessage = "No confident field matches found"
                } else {
                    let aiTag = self.isAiVerified ? "TypeSafe AI" : "Local Rules"
                    self.statusMessage = "Extracted \(matchedFields.count) fields (\(aiTag))"
                }
            }
        }
    }
    
    /// 粘贴选定字段到前台目标应用
    public func pasteField(_ field: VerifiedField, dismissHUD: @escaping () -> Void) {
        dismissHUD()
        PasteSimulator.shared.paste(text: field.text, to: previousApp)
    }
    
    /// 连续分步粘贴（按 Tab 键逐一注入表单）
    public func pasteAllSequence(dismissHUD: @escaping () -> Void) {
        let values = fields.map { $0.text }
        dismissHUD()
        PasteSimulator.shared.pasteSequence(fields: values, to: previousApp)
    }
    
    /// 粘贴原始完整文本
    public func pasteOriginal(dismissHUD: @escaping () -> Void) {
        dismissHUD()
        PasteSimulator.shared.paste(text: rawText, to: previousApp)
    }
    
    /// 复制字段内容到剪贴板
    public func copyField(_ field: VerifiedField) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(field.text, forType: .string)
        statusMessage = "Copied to clipboard"
    }
}

/// HUD 浮动主界面
public struct SmartPasteHUDView: View {
    @ObservedObject public var viewModel: HUDViewModel
    public var onClose: () -> Void
    public var onOpenSettings: () -> Void
    
    public init(viewModel: HUDViewModel, onClose: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            headerView
            
            Divider()
                .opacity(0.4)
            
            // 剪贴板原文本概览（可折叠）
            if viewModel.isShowingRawText {
                rawTextPreview
                Divider()
                    .opacity(0.3)
            }
            
            // 主体内容区：提取出的字段列表
            contentView
            
            Divider()
                .opacity(0.4)
            
            // 底部操作与快捷提示栏
            footerView
        }
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // 应用标识与模式
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tint)
                Text("Smart Paste")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Spacer()
            
            // 表单预设选择器
            Picker("", selection: $viewModel.selectedPreset) {
                ForEach(FormPreset.allCases) { preset in
                    Label(preset.rawValue, systemImage: preset.iconName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 170)
            .onChange(of: viewModel.selectedPreset) { _, _ in
                viewModel.analyze()
            }
            
            // 引擎指示 Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isAiVerified ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(viewModel.isAiVerified ? "Jev AI" : "Local")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
            
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Raw Text Preview
    private var rawTextPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Original Clipboard (\(viewModel.rawText.count) chars)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.rawText, forType: .string)
                }
                .font(.system(size: 11))
                .buttonStyle(.borderless)
            }
            ScrollView {
                Text(viewModel.rawText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 90)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
        }
        .padding(12)
    }
    
    // MARK: - Main Content
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else if viewModel.fields.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No structured fields detected")
                        .font(.system(size: 13, weight: .medium))
                    Text("Try copying text with clearer labels, dates, or titles.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Paste Raw Text Directly") {
                        viewModel.pasteOriginal(dismissHUD: onClose)
                    }
                    .padding(.top, 4)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.fields.enumerated()), id: \.element.id) { index, field in
                            fieldCard(field: field, index: index)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 280)
            }
        }
    }
    
    // MARK: - Field Card
    private func fieldCard(field: VerifiedField, index: Int) -> some View {
        let isSelected = viewModel.selectedFieldIndex == index
        
        return HStack(alignment: .top, spacing: 10) {
            // 序号 & 图标
            VStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Image(systemName: field.kind.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .frame(width: 22)
            .padding(.top, 2)
            
            // 字段信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(field.label)
                        .font(.system(size: 12, weight: .bold))
                    
                    Spacer()
                    
                    // 置信度
                    Text("\(Int(field.confidence * 100))% match")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(field.confidence >= 0.9 ? .green : .orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                }
                
                Text(field.text)
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            
            // 操作按钮
            VStack(spacing: 6) {
                Button {
                    viewModel.pasteField(field, dismissHUD: onClose)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                        Text("Paste")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .help("Paste into active application")
                
                Button {
                    viewModel.copyField(field)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedFieldIndex = index
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 12) {
            // 切换原文本预览
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isShowingRawText.toggle()
                }
            } label: {
                Label(viewModel.isShowingRawText ? "Hide Source" : "Source", systemImage: "text.quote")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            
            // 连续填充多字段模式
            if viewModel.fields.count > 1 {
                Button {
                    viewModel.pasteAllSequence(dismissHUD: onClose)
                } label: {
                    Label("Batch Fill Form (Tab)", systemImage: "arrow.right.to.line.compact")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Pastes all fields sequentially with Tab keys between them")
            }
            
            Spacer()
            
            // 设置按钮
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Settings & API Key")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
