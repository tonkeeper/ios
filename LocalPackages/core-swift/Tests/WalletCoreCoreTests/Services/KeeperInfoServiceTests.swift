//
//  KeeperInfoServiceTests.swift
//  
//
//  Created by Grigory Serebryanyy on 18.11.2023.
//

import XCTest
import TonSwift
@testable import WalletCoreCore

final class KeeperInfoServiceTests: XCTestCase {
    
    let mockKeeperInfoRepository = KeeperInfoMockRepository()
    lazy var keeperInfoService = KeeperInfoService(keeperInfoRepository: mockKeeperInfoRepository)
    
    override func setUp() {
        mockKeeperInfoRepository.reset()
    }
    
    func test_throws_error_if_no_keeper_info() throws {
        XCTAssertThrowsError(try keeperInfoService.getKeeperInfo())
    }
    
    func test_save_keeper_info() throws {
        let keeperInfo = KeeperInfo.keeperInfo(with: .wallet(with: String(repeating: "1", count: 32)))
        try keeperInfoService.saveKeeperInfo(keeperInfo)
        let getKeeperInfo = try keeperInfoService.getKeeperInfo()
        XCTAssertEqual(keeperInfo.wallets, getKeeperInfo.wallets)
        XCTAssertEqual(keeperInfo.currentWallet, getKeeperInfo.currentWallet)
    }
    
    func test_delete_keeper_info() throws {
        let keeperInfo = KeeperInfo.keeperInfo(with: .wallet(with: String(repeating: "1", count: 32)))
        try keeperInfoService.saveKeeperInfo(keeperInfo)
        XCTAssertNoThrow(try keeperInfoService.getKeeperInfo())
        try keeperInfoService.deleteKeeperInfo()
        XCTAssertThrowsError(try keeperInfoService.getKeeperInfo())
    }
    
    func test_update_keeper_info_with_wallet_if_keeper_info_empty() throws {
        let wallet = Wallet.wallet(with: String(repeating: "1", count: 32))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet))
        let keeperInfo = try keeperInfoService.getKeeperInfo()
        XCTAssertEqual(keeperInfo.wallets, [wallet])
        XCTAssertEqual(keeperInfo.currentWallet, wallet.identity)
    }
    
    func test_update_keeper_info_with_existed_wallet_that_is_active() throws {
        let wallet1 = Wallet.wallet(with: String(repeating: "1", count: 32))
        let wallet2 = Wallet.wallet(with: String(repeating: "2", count: 32))
        let wallet3 = Wallet.wallet(with: String(repeating: "1", count: 32))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet1))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet2))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet3))
        let keeperInfo = try keeperInfoService.getKeeperInfo()
        XCTAssertEqual(keeperInfo.wallets.count, 2)
        XCTAssertEqual(keeperInfo.wallets, [wallet3, wallet2])
        XCTAssertEqual(keeperInfo.currentWallet, wallet3.identity)
    }
    
    func test_update_keeper_info_with_existed_wallet_that_is_not_active() throws {
        let wallet1 = Wallet.wallet(with: String(repeating: "1", count: 32))
        let wallet2 = Wallet.wallet(with: String(repeating: "2", count: 32))
        let wallet3 = Wallet.wallet(with: String(repeating: "2", count: 32))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet1))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet2))
        XCTAssertNoThrow(try keeperInfoService.updateKeeperInfo(with: wallet3))
        let keeperInfo = try keeperInfoService.getKeeperInfo()
        XCTAssertEqual(keeperInfo.wallets.count, 2)
        XCTAssertEqual(keeperInfo.wallets, [wallet1, wallet3])
        XCTAssertEqual(keeperInfo.currentWallet, wallet1.identity)
    }
}

extension Wallet {
    static func wallet(with publicKeyString: String) -> Wallet {
        let publicKeyData = publicKeyString.data(using: .utf8)!
        let publicKey = TonSwift.PublicKey(data: publicKeyData)
        return Wallet(identity: .init(network: .mainnet, kind: .Regular(publicKey)))
    }
}

extension KeeperInfo {
    static func keeperInfo(with wallet: Wallet) -> KeeperInfo {
        KeeperInfo(wallets: [wallet],
                   currentWallet: wallet.identity,
                   securitySettings: .init(isBiometryEnabled: false),
                   assetsPolicy: .init(policies: [:], ordered: []),
                   appCollection: .init(connected: [:], recent: [], pinned: []))
    }
}
