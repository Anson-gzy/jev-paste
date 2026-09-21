import AppKit
import SwiftUI

/// 纯文本半透明灰色候选建议视图（带自适应背景遮挡，彻底盖住原有占位符与底层旧字，防止重叠）
public struct GhostSuggestionView: View {
    public let suggestionText: String
    
    public var body: some View {
        HStack(spacing: 6) {
            // 最左侧小巧的 Tab 提示微标，明确提示用户可以按 Tab 自动填入
            HStack(spacing: 3) {
                Text("Tab")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.secondary.opacity(0.75))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
            )
            
            Text(suggestionText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.55)) // 清晰的灰色半透明建议
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            // 采用完全不透明自适应文本背景色，100% 彻底遮挡底部的占位符（Placeholder），杜绝笔画重叠
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .allowsHitTesting(false)
    }
}

/// 负责在当前获得焦点的输入框内部以半透明灰色文本呈现候选内容的控制器（完全零浮窗）
@MainActor
public final class GhostOverlayController: NSObject {
    public static let shared = GhostOverlayController()
    
    private var panel: NSPanel?
    public private(set) var currentSuggestion: String?
    public private(set) var isShowing: Bool = false
    
    private override init() {
        super.init()
    }
    
    /// 在输入框内部以纯半透明灰色文字展示候选内容，完全遮挡原本的占位符文字
    public func show(suggestion: String, label: String = "", at frame: NSRect) {
        self.currentSuggestion = suggestion
        self.isShowing = true
        
        if panel == nil {
            setupPanel()
        }
        
        guard let p = panel else { return }
        
        let view = GhostSuggestionView(suggestionText: suggestion)
        p.contentView = NSHostingView(rootView: view)
        
        // 精确对齐到输入框内部区域，完全贴合内胆遮挡原有 Placeholder
        let paddingX: CGFloat = 2
        let isMultiLine = frame.height > 52
        let height: CGFloat = isMultiLine ? 30 : max(frame.height - 4, 18)
        let width = max(frame.width - paddingX * 2, 60)
        let x = frame.origin.x + paddingX
        let y = isMultiLine ? (frame.origin.y + frame.height - height - 3) : (frame.origin.y + (frame.height - height) / 2)
        
        p.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        p.orderFrontRegardless()
    }
    
    /// 隐藏半透明候选
    public func hide() {
        self.currentSuggestion = nil
        self.isShowing = false
        panel?.orderOut(nil)
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 22),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.ignoresMouseEvents = true // 鼠标完全穿透，不阻碍用户在输入框打字、点击
        p.hidesOnDeactivate = false // 确保在外部应用聚焦时仍能稳定展示幽灵文本
        
        self.panel = p
    }
}
