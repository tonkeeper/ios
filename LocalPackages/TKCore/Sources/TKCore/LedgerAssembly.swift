import UIKit
import BleTransport
import TonTransport

public final class LedgerAssembly {
  
  private weak var _bleTransport: BleTransport?
  public var bleTransport: BleTransport {
    if let _bleTransport {
      return _bleTransport
    }
    
    let devices = LedgerDevice.bluetoothDevices
      .compactMap { $0.bluetoothSpec }
      .flatMap { $0 }
    let bleServices = devices.map {
      return BleService(
        serviceUUID: $0.serviceUuid,
        notifyUUID: $0.notifyUuid,
        writeWithResponseUUID: $0.writeUuid,
        writeWithoutResponseUUID: $0.writeCmdUuid
      )
    }

    let transport = BleTransport(
      configuration: BleTransportConfiguration(services: bleServices),
      debugMode: false
    )
      
    _bleTransport = transport
    return transport
  }
}
