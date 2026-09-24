import Foundation

public struct LabeledValueMatcher {
    public static func parsePairs(from text: String) -> [(key: String, value: String)] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var pairs: [(key: String, value: String)] = [], i = 0
        while i < lines.count {
            let l = lines[i]
            if let c = l.firstIndex(where: { $0 == ":" || $0 == "：" }) {
                let k = String(l[..<c]).trimmingCharacters(in: .whitespaces), v = String(l[l.index(after: c)...]).trimmingCharacters(in: .whitespaces)
                let val = !v.isEmpty ? v : (i + 1 < lines.count ? lines[i + 1] : "")
                if !val.isEmpty && !val.hasPrefix("//") && k.contains(where: { $0.isLetter }) { pairs.append((k, val)) }
                i += v.isEmpty ? 2 : 1
            } else { i += 1 }
        }
        return pairs
    }

    public static func similarity(_ s1: String, _ s2: String) -> Double {
        let a = normalize(s1), b = normalize(s2)
        if a == b { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        let (minL, maxL) = (min(a.count, b.count), max(a.count, b.count))
        if minL >= 2 && (a.contains(b) || b.contains(a)) { return 0.7 + 0.3 * (Double(minL) / Double(maxL)) }
        if s1.allSatisfy({ $0.isASCII }) && s2.allSatisfy({ $0.isASCII }) {
            let w1 = Set(s1.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            let w2 = Set(s2.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            let u = w1.union(w2); return u.isEmpty ? 0.0 : Double(w1.intersection(w2).count) / Double(u.count)
        }
        let c1 = Set(a), c2 = Set(b), u = c1.union(c2)
        return u.isEmpty ? 0.0 : Double(c1.intersection(c2).count) / Double(u.count)
    }

    public static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols).contains($0) }.map(String.init).joined()
    }
}
