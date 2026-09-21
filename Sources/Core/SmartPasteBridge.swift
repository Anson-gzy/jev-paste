import Foundation
import JavaScriptCore

/// 基于 macOS 内置 JavaScriptCore 框架，高保真无缝运行上游 core.js
public final class SmartPasteBridge {
    private let vm: JSVirtualMachine
    private let context: JSContext
    
    public init(coreJsPath: String? = nil) throws {
        self.vm = JSVirtualMachine()
        guard let ctx = JSContext(virtualMachine: vm) else {
            throw NSError(domain: "SmartPasteBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSContext"])
        }
        self.context = ctx
        
        // 捕获 JS 异常输出到控制台
        ctx.exceptionHandler = { _, exception in
            if let exc = exception {
                NSLog("[SmartPasteBridge JS Error] %@", exc.toString())
            }
        }
        
        // 加载 core.js
        let script: String
        if let customPath = coreJsPath, let content = try? String(contentsOfFile: customPath, encoding: .utf8) {
            script = content
        } else if let bundlePath = Bundle.main.path(forResource: "core", ofType: "js"),
                  let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            script = content
        } else {
            // 尝试从项目相对路径加载（开发与测试环境）
            let currentDir = FileManager.default.currentDirectoryPath
            let possiblePaths = [
                "Resources/core.js",
                "../Resources/core.js",
                "sandboxes/smart-paste-mac/Resources/core.js",
                (currentDir as NSString).appendingPathComponent("sandboxes/smart-paste-mac/Resources/core.js"),
                (currentDir as NSString).appendingPathComponent("Resources/core.js"),
                (currentDir as NSString).appendingPathComponent("vendor/smart-paste/core.js")
            ]
            var foundContent: String?
            for path in possiblePaths {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    foundContent = content
                    break
                }
            }
            guard let validContent = foundContent else {
                throw NSError(domain: "SmartPasteBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "core.js not found in bundle or disk"])
            }
            script = validContent
        }
        
        ctx.evaluateScript(script)
    }
    
    /// 提取候选切片 (Candidates)
    public func extractCandidates(from text: String) throws -> [CandidateSpan] {
        guard let core = context.objectForKeyedSubscript("SmartPasteCore"),
              let candidatesFn = core.objectForKeyedSubscript("candidates") else {
            throw NSError(domain: "SmartPasteBridge", code: 3, userInfo: [NSLocalizedDescriptionKey: "SmartPasteCore.candidates not found"])
        }
        
        let result = candidatesFn.call(withArguments: [text])
        if let exception = context.exception {
            context.exception = nil
            throw NSError(domain: "SmartPasteBridge", code: 4, userInfo: [NSLocalizedDescriptionKey: exception.toString() ?? "Unknown JS exception"])
        }
        
        guard let rawArray = result?.toArray() as? [[String: Any]] else {
            return []
        }
        
        return rawArray.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let start = dict["start"] as? Int,
                  let end = dict["end"] as? Int,
                  let spanText = dict["text"] as? String else {
                return nil
            }
            return CandidateSpan(
                id: id,
                start: start,
                end: end,
                text: spanText,
                destination: dict["destination"] as? String,
                label: dict["label"] as? String
            )
        }
    }
    
    /// 构建向 TypeSafe System One API 发送的第 1 阶段请求体 (Build)
    public func build(text: String, context formContext: FormContext) throws -> (spans: [CandidateSpan], body: [String: Any]) {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let buildFn = core.objectForKeyedSubscript("build") else {
            throw NSError(domain: "SmartPasteBridge", code: 5, userInfo: [NSLocalizedDescriptionKey: "SmartPasteCore.build not found"])
        }
        
        let contextDict: [String: Any] = [
            "heading": formContext.heading,
            "fields": formContext.fields.map { [
                "id": $0.id,
                "kind": $0.kind.rawValue,
                "label": $0.label,
                "focused": $0.focused,
                "occupied": $0.occupied
            ] }
        ]
        
        let res = buildFn.call(withArguments: [text, contextDict])
        if let exception = self.context.exception {
            self.context.exception = nil
            throw NSError(domain: "SmartPasteBridge", code: 6, userInfo: [NSLocalizedDescriptionKey: exception.toString() ?? "JS Exception"])
        }
        
        guard let dict = res?.toDictionary(),
              let rawSpans = dict["spans"] as? [[String: Any]],
              let body = dict["body"] as? [String: Any] else {
            throw NSError(domain: "SmartPasteBridge", code: 7, userInfo: [NSLocalizedDescriptionKey: "Invalid build output"])
        }
        
        let spans: [CandidateSpan] = rawSpans.compactMap { d in
            guard let id = d["id"] as? String,
                  let start = d["start"] as? Int,
                  let end = d["end"] as? Int,
                  let spanText = d["text"] as? String else { return nil }
            return CandidateSpan(id: id, start: start, end: end, text: spanText, destination: d["destination"] as? String, label: d["label"] as? String)
        }
        
        return (spans, body)
    }
    
    /// 解析第一阶段回答
    public func resolve(answers: [String: Any], spans: [CandidateSpan], fields: [FormField]) -> [[String: Any]] {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let resolveFn = core.objectForKeyedSubscript("resolve") else {
            return []
        }
        let fieldsList = fields.map { ["id": $0.id, "kind": $0.kind.rawValue, "label": $0.label] }
        let spansList = spans.map { ["id": $0.id, "start": $0.start, "end": $0.end, "text": $0.text, "destination": $0.destination as Any, "label": $0.label as Any] }
        let res = resolveFn.call(withArguments: [answers, spansList, fieldsList])
        return (res?.toArray() as? [[String: Any]]) ?? []
    }
    
    /// 构建第 2 阶段精确边界提取请求
    public func boundaries(text: String, context formContext: FormContext, rows: [[String: Any]]) -> [String: Any]? {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let boundariesFn = core.objectForKeyedSubscript("boundaries") else {
            return nil
        }
        let contextDict: [String: Any] = [
            "heading": formContext.heading,
            "fields": formContext.fields.map { ["id": $0.id, "kind": $0.kind.rawValue, "label": $0.label] }
        ]
        let res = boundariesFn.call(withArguments: [text, contextDict, rows])
        return res?.toDictionary() as? [String: Any]
    }
    
    /// 提取边界切片
    public func extracted(text: String, stage: [String: Any], answers: [String: Any]) -> [[String: Any]] {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let extractedFn = core.objectForKeyedSubscript("extracted") else {
            return []
        }
        let res = extractedFn.call(withArguments: [text, stage, answers])
        return (res?.toArray() as? [[String: Any]]) ?? []
    }
    
    /// 构建第 3 阶段验证请求
    public func verification(text: String, context formContext: FormContext, values: [[String: Any]]) -> [String: Any]? {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let verificationFn = core.objectForKeyedSubscript("verification") else {
            return nil
        }
        let contextDict: [String: Any] = [
            "heading": formContext.heading,
            "fields": formContext.fields.map { ["id": $0.id, "kind": $0.kind.rawValue, "label": $0.label] }
        ]
        let res = verificationFn.call(withArguments: [text, contextDict, values])
        return res?.toDictionary() as? [String: Any]
    }
    
    /// 验证最终行并返回置信结果
    public func verifiedRows(context formContext: FormContext, values: [[String: Any]], answers: [String: Any]) -> [[String: Any]] {
        guard let core = self.context.objectForKeyedSubscript("SmartPasteCore"),
              let verifiedRowsFn = core.objectForKeyedSubscript("verifiedRows") else {
            return []
        }
        let contextDict: [String: Any] = [
            "heading": formContext.heading,
            "fields": formContext.fields.map { ["id": $0.id, "kind": $0.kind.rawValue, "label": $0.label] }
        ]
        let res = verifiedRowsFn.call(withArguments: [contextDict, values, answers])
        return (res?.toArray() as? [[String: Any]]) ?? []
    }
}
