import Foundation
import TKBatteryAPI

extension BatteryPurchase {
    init(purchase: Components.Schemas.Purchases.purchasesPayloadPayload) {
        identifier = purchase.purchase_id
        kind = Kind(type: purchase._type)
        isRefunded = purchase.refund_information.map {
            $0.fully_refunded || $0.partially_refunded
        } ?? false
    }
}

private extension BatteryPurchase.Kind {
    init(type: Components.Schemas.Purchases.purchasesPayloadPayload._typePayload) {
        switch type {
        case .ios:
            self = .ios
        case .android:
            self = .android
        case .promo_hyphen_code:
            self = .promocode
        case .crypto:
            self = .crypto
        case .gift:
            self = .gift
        case .on_hyphen_the_hyphen_way_hyphen_gift:
            self = .onTheWayGift
        }
    }
}
