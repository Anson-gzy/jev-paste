import SwiftUI
import AppKit

public struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isKeySaved: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String? = nil
    @State private var testSuccess: Bool = false
    @State private var isShowingKey: Bool = false
    
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var historyManager = ClipboardHistoryManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.tint)
                    Text(L("set.title"))
                        .font(.headline)
                }
                
                Divider()
                
                // 1. 语言切换区 (Language Switcher)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("set.lang.section"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(L("set.lang.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { loc.currentLanguage },
                        set: { newLang in loc.setLanguage(newLang) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                
                // 2. 剪贴板历史与时间衰减设置 (Clipboard History & Retention)
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("set.history.section"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(L("set.history.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Text(L("set.history.retentionLabel") + ":")
                            .font(.system(size: 13, weight: .medium))
                        
                        Picker("", selection: Binding(
                            get: { historyManager.retentionPeriod },
                            set: { historyManager.retentionPeriod = $0 }
                        )) {
                            ForEach(HistoryRetentionPeriod.allCases) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .frame(maxWidth: 180)
                        
                        Spacer()
                    }
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentColor)
                            Text("\(historyManager.historyItems.count) \(L("set.history.itemsCount"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            historyManager.clearHistory()
                        }) {
                            Text(L("set.history.clearBtn"))
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(historyManager.historyItems.isEmpty)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                
                // 3. API Key 设置区
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("set.api.section"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(L("set.api.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Group {
                            if isShowingKey {
                                TextField(L("set.api.keyPh"), text: $apiKey)
                            } else {
                                SecureField(L("set.api.keyPh"), text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        
                        Button {
                            isShowingKey.toggle()
                        } label: {
                            Image(systemName: isShowingKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        
                        Button(L("set.api.saveBtn")) {
                            saveKey()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if isKeySaved {
                            Button("Remove", role: .destructive) {
                                removeKey()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if isKeySaved {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                            Text(L("set.api.saved"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 测试连接按钮
                    HStack(spacing: 10) {
                        Button(action: testConnection) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(L("set.api.testBtn"))
                            }
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                        
                        if let result = testResult {
                            HStack(spacing: 4) {
                                Image(systemName: testSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(testSuccess ? .green : .red)
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(testSuccess ? .green : .red)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                
                // 3. 通用与双引擎设置
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("set.engine.section"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("set.engine.jefAi"))
                            .font(.system(size: 13, weight: .medium))
                        Text(L("set.engine.jefAiDesc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                
                // 4. 真实按键行为与集成说明
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("set.keys.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        shortcutRow(key: "Tab", desc: L("set.keys.tab"))
                        shortcutRow(key: "⌘ V", desc: L("set.keys.cmdv"))
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 460)
        .onAppear {
            loadKey()
        }
    }
    
    private func shortcutRow(key: String, desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(4)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private func loadKey() {
        if let saved = KeychainHelper.shared.getApiKey(), !saved.isEmpty {
            self.apiKey = saved
            self.isKeySaved = true
        }
    }
    
    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if KeychainHelper.shared.saveApiKey(trimmed) {
                isKeySaved = true
                testResult = "Saved securely in Keychain"
                testSuccess = true
            }
        }
    }
    
    private func removeKey() {
        _ = KeychainHelper.shared.deleteApiKey()
        apiKey = ""
        isKeySaved = false
        testResult = "API key removed"
        testSuccess = false
    }
    
    private func testConnection() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        
        isTesting = true
        testResult = nil
        
        Task {
            var req = URLRequest(url: URL(string: "https://api.typesafe.ai/v1/systemone")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 6.0
            
            // 发送一个极简探测请求
            let body: [String: Any] = [
                "model": "jev-latest",
                "state": ["test": true],
                "questions": [
                    "ping": [
                        "type": "noul",
                        "instructions": "Is this a test?"
                    ]
                ]
            ]
            
            do {
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: req)
                await MainActor.run {
                    self.isTesting = false
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        self.testSuccess = true
                        self.testResult = "Connected! Jev API is working."
                    } else if let http = response as? HTTPURLResponse {
                        self.testSuccess = false
                        self.testResult = "HTTP Error: \(http.statusCode)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.testSuccess = false
                    self.testResult = "Network error: \(error.localizedDescription)"
                }
            }
        }
    }
}
