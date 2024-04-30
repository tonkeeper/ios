//
//  KeeperInfoMockRepository.swift
//
//
//  Created by Grigory Serebryanyy on 18.11.2023.
//

import Foundation
import WalletCoreCore

final class KeeperInfoMockRepository: KeeperInfoRepository {
    
    enum Error: Swift.Error {
        case noKeeperInfo
    }
    
    var keeperInfo: KeeperInfo?
    
    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo = keeperInfo else { throw Error.noKeeperInfo }
        return keeperInfo
    }
    
    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }
    
    func removeKeeperInfo() throws {
        self.keeperInfo = nil
    }
    
    func reset() {
        self.keeperInfo = nil
    }
}
