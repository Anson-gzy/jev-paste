import AppKit
import Foundation

@main
struct SmartPasteApp {
    @MainActor
    static func main() {
        // 处理 CLI 诊断与直接测试参数
        if CommandLine.arguments.contains("--status") {
            let key = KeychainHelper.shared.getApiKey()
            let hasKey = key != nil && !key!.isEmpty
            print("=== Smart Paste Status ===")
            print("• API Key Status: \(hasKey ? "Configured & Active (Key length: \(key!.count))" : "Not Set (Using Heuristic Fallback)")")
            exit(0)
        }
        
        if CommandLine.arguments.contains("--test") || CommandLine.arguments.contains("--parse") {
            do {
                let bridge = try SmartPasteBridge()
                let sampleText: String
                if let parseIdx = CommandLine.arguments.firstIndex(of: "--parse"), parseIdx + 1 < CommandLine.arguments.count {
                    sampleText = CommandLine.arguments[parseIdx + 1]
                } else {
                    sampleText = """
                    Can we file “Keep draft text when switching workspaces”? Switching workspaces clears the issue draft. Preserve the title and description until the issue is created or discarded. Also, the address is Ferry Building, 1 Ferry Building, San Francisco, CA 94111. For the tweet use “One clipboard, four destinations. Working on a little experiment that pastes just what you need.” Our Smart Paste demo is on September 24 at 2 pm for 30 minutes at the Ferry Building.
                    """
                }
                
                print("=== Smart Paste CLI Inspector ===")
                print("Input Text length: \(sampleText.count) characters")
                
                // 1. 候选 Span 测试
                let candidates = try bridge.extractCandidates(from: sampleText)
                print("\n[Extracted Candidates: \(candidates.count)]")
                for (i, c) in candidates.prefix(8).enumerated() {
                    print("  [\(i)] (len \(c.text.count)) [\(c.label ?? "no-label")] \"\(c.text.prefix(60))...\"")
                }
                
                // 2. 本地启发式解析测试
                print("\n[Local Heuristic Field Matching - Issue Preset]")
                let issueFields = LocalHeuristicEngine.shared.match(
                    text: sampleText,
                    context: FormPreset.issueTracker.context,
                    spans: candidates
                )
                for f in issueFields {
                    print("  • \(f.label) (\(f.kind.rawValue)): \"\(f.text)\" [Confidence: \(Int(f.confidence * 100))%]")
                }
                
                print("\n[Local Heuristic Field Matching - Calendar Preset]")
                let calendarFields = LocalHeuristicEngine.shared.match(
                    text: sampleText,
                    context: FormPreset.calendarEvent.context,
                    spans: candidates
                )
                for f in calendarFields {
                    print("  • \(f.label) (\(f.kind.rawValue)): \"\(f.text)\" [Confidence: \(Int(f.confidence * 100))%]")
                }
                
                print("\n=== Inspection Completed Successfully ===")
                exit(0)
            } catch {
                print("❌ CLI Error: \(error.localizedDescription)")
                exit(1)
            }
        }

        // 正常启动 macOS 后台感知应用（常驻顶部菜单栏，不在 Dock 程序坞显示图标）
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
