import Foundation

/// TypeSafe Jev System One API 客户端，封装 3-step 智能判定流程
public final class TypeSafeClient {
    private let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    private let bridge: SmartPasteBridge
    private let heuristic: LocalHeuristicEngine
    
    public init(bridge: SmartPasteBridge, heuristic: LocalHeuristicEngine = .shared) {
        self.bridge = bridge
        self.heuristic = heuristic
    }
    
    /// 执行智能解析全流程：优先使用 TypeSafe AI，如果无 Key 或失败则回退至启发式规则
    public func parse(text: String, context: FormContext, apiKey: String?) async -> [VerifiedField] {
        guard let key = apiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // 无 Key，直接使用本地启发式匹配引擎
            return parseLocally(text: text, context: context)
        }
        
        do {
            // 步骤 1：Build
            let (spans, body) = try bridge.build(text: text, context: context)
            let stage1Response = try await request(payload: body, apiKey: key)
            
            guard let answers1 = stage1Response["answers"] as? [String: Any] else {
                return parseLocally(text: text, context: context, spans: spans)
            }
            
            // 解析初始判定
            let initial = bridge.resolve(answers: answers1, spans: spans, fields: context.fields)
            
            // 提取 Stage 1 高置信度候选字段，作为稳固兜底
            var stage1FallbackFields: [VerifiedField] = []
            for row in initial {
                let rowId = row["id"] as? String ?? ""
                guard let fieldDef = context.fields.first(where: { $0.id == rowId }) else { continue }
                if let options = row["options"] as? [[String: Any]], let firstOpt = options.first {
                    let optText = firstOpt["text"] as? String ?? ""
                    let prob = firstOpt["probability"] as? Double ?? 0.0
                    let start = firstOpt["start"] as? Int ?? 0
                    let end = firstOpt["end"] as? Int ?? 0
                    if !optText.isEmpty && prob >= 0.5 {
                        stage1FallbackFields.append(VerifiedField(
                            fieldId: fieldDef.id,
                            kind: fieldDef.kind,
                            label: fieldDef.label,
                            text: optText,
                            confidence: max(prob, 0.85),
                            sourceStart: start,
                            sourceEnd: end,
                            isAiVerified: true
                        ))
                    }
                }
            }
            
            // 步骤 2：Boundaries
            guard let stage2 = bridge.boundaries(text: text, context: context, rows: initial),
                  let stage2Body = stage2["body"] as? [String: Any],
                  let stage2Questions = stage2Body["questions"] as? [String: Any],
                  !stage2Questions.isEmpty else {
                // 若没有细分边界问题，直接使用 Stage 1 Jev 的判定结果
                if !stage1FallbackFields.isEmpty {
                    return stage1FallbackFields
                }
                return parseLocally(text: text, context: context, spans: spans)
            }
            
            let stage2Response = try await request(payload: stage2Body, apiKey: key)
            guard let answers2 = stage2Response["answers"] as? [String: Any] else {
                return stage1FallbackFields.isEmpty ? parseLocally(text: text, context: context, spans: spans) : stage1FallbackFields
            }
            
            let values = bridge.extracted(text: text, stage: stage2, answers: answers2)
            if values.isEmpty {
                return stage1FallbackFields.isEmpty ? parseLocally(text: text, context: context, spans: spans) : stage1FallbackFields
            }
            
            // 步骤 3：Verification
            guard let stage3 = bridge.verification(text: text, context: context, values: values),
                  let stage3Questions = stage3["questions"] as? [String: Any],
                  !stage3Questions.isEmpty else {
                return stage1FallbackFields.isEmpty ? parseLocally(text: text, context: context, spans: spans) : stage1FallbackFields
            }
            
            let stage3Response = try await request(payload: stage3, apiKey: key)
            let answers3 = stage3Response["answers"] as? [String: Any] ?? [:]
            
            let verifiedRows = bridge.verifiedRows(context: context, values: values, answers: answers3)
            
            var verifiedFields: [VerifiedField] = []
            for row in verifiedRows {
                let rowId = row["id"] as? String ?? ""
                let fieldDef = context.fields.first(where: { $0.id == rowId })
                
                if let options = row["options"] as? [[String: Any]], let firstOpt = options.first {
                    let optText = firstOpt["text"] as? String ?? ""
                    let start = firstOpt["start"] as? Int ?? 0
                    let end = firstOpt["end"] as? Int ?? 0
                    let prob = firstOpt["probability"] as? Double ?? 0.95
                    
                    if !optText.isEmpty, let f = fieldDef {
                        verifiedFields.append(VerifiedField(
                            fieldId: f.id,
                            kind: f.kind,
                            label: f.label,
                            text: optText,
                            confidence: prob,
                            sourceStart: start,
                            sourceEnd: end,
                            isAiVerified: true
                        ))
                    }
                }
            }
            
            if !verifiedFields.isEmpty {
                return verifiedFields
            } else if !stage1FallbackFields.isEmpty {
                return stage1FallbackFields
            } else {
                return parseLocally(text: text, context: context, spans: spans)
            }
            
        } catch {
            NSLog("[TypeSafeClient] AI matching failed or offline: %@. Falling back to local heuristics.", error.localizedDescription)
            return parseLocally(text: text, context: context)
        }
    }
    
    /// 本地启发式解析快速路径
    public func parseLocally(text: String, context: FormContext, spans: [CandidateSpan]? = nil) -> [VerifiedField] {
        let validSpans: [CandidateSpan]
        if let s = spans {
            validSpans = s
        } else if let extracted = try? bridge.extractCandidates(from: text) {
            validSpans = extracted
        } else {
            validSpans = []
        }
        return heuristic.match(text: text, context: context, spans: validSpans)
    }
    
    /// 发送 POST JSON 请求到 TypeSafe System One
    private func request(payload: [String: Any], apiKey: String) async throws -> [String: Any] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8.0
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "TypeSafeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "TypeSafeClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "TypeSafeClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        return json
    }
}
