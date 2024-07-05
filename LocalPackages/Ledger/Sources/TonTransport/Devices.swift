import Foundation
import CoreBluetooth

public struct Devices {
  public enum DeviceModelId {
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
  
  public struct DeviceModel {
    public let id: DeviceModelId
    public let productName: String
    public let productIdMM: Int
    public let legacyUsbProductId: Int
    public let usbOnly: Bool
    public let memorySize: Int
    public let masks: [Int]
    public let bluetoothSpec: [BluetoothSpec]?
    
    init(id: DeviceModelId,
         productName: String,
         productIdMM: Int,
         legacyUsbProductId: Int,
         usbOnly: Bool,
         memorySize: Int,
         masks: [Int],
         bluetoothSpec: [BluetoothSpec]? = nil) {
      self.id = id
      self.productName = productName
      self.productIdMM = productIdMM
      self.legacyUsbProductId = legacyUsbProductId
      self.usbOnly = usbOnly
      self.memorySize = memorySize
      self.masks = masks
      self.bluetoothSpec = bluetoothSpec
    }
  }
  
  static let devices: [DeviceModelId: DeviceModel] = [
    .blue: DeviceModel(
      id: .blue,
      productName: "Ledger Blue",
      productIdMM: 0x00,
      legacyUsbProductId: 0x0000,
      usbOnly: true,
      memorySize: 480 * 1024,
      masks: [0x31000000, 0x31010000]
    ),
    .nanoS: DeviceModel(
      id: .nanoS,
      productName: "Ledger Nano S",
      productIdMM: 0x10,
      legacyUsbProductId: 0x0001,
      usbOnly: true,
      memorySize: 320 * 1024,
      masks: [0x31100000]
    ),
    .nanoX: DeviceModel(
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
    ),
    .nanoSP: DeviceModel(
      id: .nanoSP,
      productName: "Ledger Nano S Plus",
      productIdMM: 0x50,
      legacyUsbProductId: 0x0005,
      usbOnly: true,
      memorySize: 1533 * 1024,
      masks: [0x33100000]
    ),
    .stax: DeviceModel(
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
    ),
    .europa: DeviceModel(
      id: .europa,
      productName: "Ledger Europa",
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
  ]
  
  static func getBluetoothDevices() -> [DeviceModel] {
    return devices.values.filter { $0.bluetoothSpec != nil }
  }
  
  public static func fromServiceUuid(serviceUuid: String) -> DeviceModel {
    let device = devices.values.first { $0.bluetoothSpec?.contains { $0.serviceUuid == serviceUuid } ?? false }
    return device ?? devices[.nanoX].unsafelyUnwrapped
  }
  
  public static func fromServiceUuid(serviceUuid: CBUUID) -> DeviceModel {
    return fromServiceUuid(serviceUuid: serviceUuid.uuidString)
  }
}


