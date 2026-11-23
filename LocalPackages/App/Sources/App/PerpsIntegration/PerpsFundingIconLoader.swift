import Foundation

@MainActor
final class PerpsFundingIconLoader {
    private let loadCatalogIcon: (String) async -> URL?
    private var loads = [String: Task<URL?, Never>]()

    init(loadCatalogIcon: @escaping (String) async -> URL?) {
        self.loadCatalogIcon = loadCatalogIcon
    }

    deinit {
        loads.values.forEach { $0.cancel() }
    }

    func iconURL(assetId: String, walletImage: String?) async -> URL? {
        if let url = Self.walletIconURL(walletImage) { return url }
        let key = assetId.lowercased()
        if let load = loads[key] { return await load.value }
        let load = Task { [loadCatalogIcon] in await loadCatalogIcon(assetId) }
        loads[key] = load
        return await load.value
    }

    static func walletIconURL(_ image: String?) -> URL? {
        guard let image = image?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: image), url.scheme == "https" || url.scheme == "http"
        else { return nil }
        return url
    }
}
