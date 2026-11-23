import Foundation

/// Token logos the app saves for the widget extension, which cannot load a URL while it renders an
/// activity. Compiled into the widget extension too.
enum TransactionLiveActivityIcons {
    static var directory: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String)
            .flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }?
            .appendingPathComponent("LiveActivityIcons", isDirectory: true)
    }

    /// Only a bare file name resolves: the name comes from the content state, which a push can carry.
    static func url(named name: String) -> URL? {
        guard !name.isEmpty, name.count <= 80, !name.hasPrefix("."),
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "." || $0 == "_") })
        else { return nil }
        return directory?.appendingPathComponent(name, isDirectory: false)
    }
}
