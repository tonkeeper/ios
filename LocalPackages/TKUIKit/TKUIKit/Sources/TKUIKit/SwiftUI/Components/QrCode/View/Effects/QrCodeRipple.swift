import UIKit

struct QrCodeRipple: Identifiable, Equatable {
    var id: UUID
    var origin: CGPoint
    var startDate: Date

    init(
        id: UUID = UUID(),
        origin: CGPoint,
        startDate: Date = Date()
    ) {
        self.id = id
        self.origin = origin
        self.startDate = startDate
    }
}
