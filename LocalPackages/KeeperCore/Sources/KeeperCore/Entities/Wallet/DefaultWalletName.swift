import Foundation

public enum DefaultWalletName {
    public static func suggest(base: String, existingLabels: [String]) -> String {
        let base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return base }

        let usedIndexes = existingLabels.compactMap { index(of: $0, base: base) }
        guard let maxIndex = usedIndexes.max() else { return base }
        guard maxIndex < Int.max else { return base }

        return "\(base) \(maxIndex + 1)"
    }

    private static func index(of label: String, base: String) -> Int? {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.compare(base, options: .caseInsensitive) == .orderedSame {
            return 1
        }

        let prefix = base + " "
        guard label.count > prefix.count,
              label.prefix(prefix.count).compare(prefix, options: .caseInsensitive) == .orderedSame
        else {
            return nil
        }

        let suffix = label.dropFirst(prefix.count)
        guard suffix.first != "0", suffix.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(suffix)
    }
}
