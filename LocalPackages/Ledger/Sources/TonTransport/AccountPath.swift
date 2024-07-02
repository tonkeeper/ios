import Foundation
import TonSwift

public struct AccountPath: Codable, Hashable {
  public let index: Int
  public let isTestnet: Bool
  public let workchain: Int8
  
  public init(index: Int, isTestnet: Bool = false, workchain: Int8 = 0) {
    self.index = index
    self.isTestnet = isTestnet
    self.workchain = workchain
  }
  
  public var data: Data {
    let paths = getPath()
    let adjustedPaths = paths.map { $0 + 0x80000000 }
    
    var data = Data(count: 1 + adjustedPaths.count * 4)
    
    data[0] = UInt8(adjustedPaths.count)
    
    // Write each path element as a big-endian 32-bit unsigned integer
    for (index, element) in adjustedPaths.enumerated() {
      let offset = 1 + index * 4
      data[offset] = UInt8((element >> 24) & 0xFF)
      data[offset + 1] = UInt8((element >> 16) & 0xFF)
      data[offset + 2] = UInt8((element >> 8) & 0xFF)
      data[offset + 3] = UInt8(element & 0xFF)
    }
    
    return data
  }
  
  public func contract(publicKey: PublicKey) -> WalletV4R2 {
    return WalletV4R2(workchain: workchain, publicKey: publicKey.data)
  }
  
  private func getPath() -> [Int] {
    let network = isTestnet ? 1 : 0
    let chain = workchain == UInt8.max ? 255 : 0
    return [44, 607, network, chain, index, 0]
  }
}

