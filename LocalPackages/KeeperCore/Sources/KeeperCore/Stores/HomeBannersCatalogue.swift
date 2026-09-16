import Foundation

public struct HomeBannersCatalogue: Equatable {
    static let empty = HomeBannersCatalogue(banners: [:])

    private let banners: [String?: [HomeBanner]]

    func banners(forWalletId walletId: String?) -> [HomeBanner] {
        banners[walletId] ?? []
    }

    func setting(_ banners: [HomeBanner], forWalletId walletId: String?) -> HomeBannersCatalogue {
        var updated = self.banners
        updated[walletId] = banners
        return HomeBannersCatalogue(banners: updated)
    }
}
