import Foundation
import KeeperCore

struct RampPaymentMethodRow: Identifiable, Equatable {
    let type: String
    let title: String
    let image: String
    let isP2P: Bool

    var id: String {
        type
    }

    var imageURL: URL? {
        guard !image.isEmpty else { return nil }
        return URL(string: image)
    }
}

extension RampPaymentMethodRow {
    static func rows(from assetDetail: OnRampAssetDetail, fiat: String) -> [RampPaymentMethodRow] {
        let methods = assetDetail.paymentMethods.filter { method in
            method.providers.contains { $0.fiat == fiat }
        }

        return methods.map { method in
            RampPaymentMethodRow(
                type: method.type,
                title: method.name,
                image: method.image,
                isP2P: method.isP2P
            )
        }
    }
}
