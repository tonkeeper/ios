import Foundation
import CoreBluetooth

public struct LedgerDevice {
  public enum Model {
    case blue
    case nanoS
    case nanoSP
    case nanoX
    case stax
    case europa
  }
  
  public struct BluetoothSpec {
    public let serviceUuid: String
    public let notifyUuid: String
    public let writeUuid: String
    public let writeCmdUuid: String
  }
  
  public let id: Model
  public let productName: String
  public let productIdMM: Int
  public let legacyUsbProductId: Int
  public let usbOnly: Bool
  public let memorySize: Int
  public let masks: [Int]
  public let bluetoothSpec: [BluetoothSpec]
  
  static var devices: [LedgerDevice] {
    [
      blue,
      nanoS,
      nanoX,
      nanoSP,
      stax,
      europa
    ]
  }
  
  static var blue: LedgerDevice {
    LedgerDevice(
      id: .blue,
      productName: "Ledger Blue",
      productIdMM: 0x00,
      legacyUsbProductId: 0x0000,
      usbOnly: true,
      memorySize: 480 * 1024,
      masks: [0x31000000, 0x31010000],
      bluetoothSpec: []
    )
  }
  
  static var nanoS: LedgerDevice {
    LedgerDevice(
      id: .nanoS,
      productName: "Ledger Nano S",
      productIdMM: 0x10,
      legacyUsbProductId: 0x0001,
      usbOnly: true,
      memorySize: 320 * 1024,
      masks: [0x31100000],
      bluetoothSpec: []
    )
  }
  
  static var nanoX: LedgerDevice {
    LedgerDevice(
      id: .nanoX,
      productName: "Ledger Nano X",
      productIdMM: 0x40,
      legacyUsbProductId: 0x0004,
      usbOnly: false,
      memorySize: 2 * 1024 * 1024,
      masks: [0x33000000],
      bluetoothSpec: [
        BluetoothSpec(
          serviceUuid: "13d63400-2c97-0004-0000-4c6564676572",
          notifyUuid: "13d63400-2c97-0004-0001-4c6564676572",
          writeUuid: "13d63400-2c97-0004-0002-4c6564676572",
          writeCmdUuid: "13d63400-2c97-0004-0003-4c6564676572"
        )
      ]
    )
  }
  
  static var nanoSP: LedgerDevice {
    LedgerDevice(
      id: .nanoSP,
      productName: "Ledger Nano S Plus",
      productIdMM: 0x50,
      legacyUsbProductId: 0x0005,
      usbOnly: true,
      memorySize: 1533 * 1024,
      masks: [0x33100000],
      bluetoothSpec: []
    )
  }
  
  static var stax: LedgerDevice {
    LedgerDevice(
      id: .stax,
      productName: "Ledger Stax",
      productIdMM: 0x60,
      legacyUsbProductId: 0x0006,
      usbOnly: false,
      memorySize: 1533 * 1024,
      masks: [0x33200000],
      bluetoothSpec: [
        BluetoothSpec(
          serviceUuid: "13d63400-2c97-6004-0000-4c6564676572",
          notifyUuid: "13d63400-2c97-6004-0001-4c6564676572",
          writeUuid: "13d63400-2c97-6004-0002-4c6564676572",
          writeCmdUuid: "13d63400-2c97-6004-0003-4c6564676572"
        )
      ]
    )
  }
  
  static var europa: LedgerDevice {
    LedgerDevice(
      id: .europa,
      productName: "Ledger Flex",
      productIdMM: 0x70,
      legacyUsbProductId: 0x0007,
      usbOnly: false,
      memorySize: 1533 * 1024,
      masks: [0x33300000],
      bluetoothSpec: [
        BluetoothSpec(
          serviceUuid: "13d63400-2c97-3004-0000-4c6564676572",
          notifyUuid: "13d63400-2c97-3004-0001-4c6564676572",
          writeUuid: "13d63400-2c97-3004-0002-4c6564676572",
          writeCmdUuid: "13d63400-2c97-3004-0003-4c6564676572"
        )
      ]
    )
  }
  
  public static var bluetoothDevices: [LedgerDevice] {
    devices.filter { !$0.bluetoothSpec.isEmpty }
  }
  
  public static func getDeviceWith(serviceUUID: String) -> LedgerDevice {
    let lowercasedServiceUUID = serviceUUID.lowercased()
    return devices.first(where: {
      $0.bluetoothSpec.contains(where: { $0.serviceUuid.lowercased() == lowercasedServiceUUID })
    }) ?? .nanoX
  }
  
  public static func getDeviceWith(serviceUUID: CBUUID) -> LedgerDevice {
    getDeviceWith(serviceUUID: serviceUUID.uuidString)
  }
}
