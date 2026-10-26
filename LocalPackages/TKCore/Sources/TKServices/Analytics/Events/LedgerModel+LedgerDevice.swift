import TonTransport

public extension LedgerModel {
    init(ledgerDevice: LedgerDevice.Model) {
        switch ledgerDevice {
        case .nanoS:
            self = .nanoS
        case .nanoSP:
            self = .nanoSPlus
        case .nanoX:
            self = .nanoX
        case .stax:
            self = .stax
        case .europa:
            self = .flex
        case .apex:
            self = .nanoGen5
        case .blue:
            self = .unknown
        }
    }

    init(deviceProductName: String) {
        let device = LedgerDevice.bluetoothDevices.first { $0.productName == deviceProductName }
        self = device.map { LedgerModel(ledgerDevice: $0.id) } ?? .unknown
    }
}
