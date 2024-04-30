//
//  WalletsControllerTests.swift
//  
//
//  Created by Grigory Serebryanyy on 18.11.2023.
//

import XCTest
import TonSwift
@testable import WalletCoreCore

final class WalletsControllerTests: XCTestCase {
    let mockKeeperInfoRepository = KeeperInfoMockRepository()
    let mockWalletMnemonicRepository = WalletMnemonicMockRepository()
    lazy var keeperInfoService = KeeperInfoService(keeperInfoRepository: mockKeeperInfoRepository)
    lazy var walletsController = WalletsController(keeperInfoService: keeperInfoService,
                                                   walletMnemonicRepository: mockWalletMnemonicRepository)
    
    override func setUp() {
        mockKeeperInfoRepository.reset()
        mockWalletMnemonicRepository.reset()
    }
    
    func test_has_no_wallets_if_no_keeper_info() throws {
        XCTAssertFalse(walletsController.hasWallets)
    }
    
    func test_has_no_wallets_if_has_regular_wallet_but_no_mnemonic() throws {
        let wallet = Wallet.wallet(with: "1")
        try keeperInfoService.updateKeeperInfo(with: wallet)
        XCTAssertFalse(walletsController.hasWallets)
    }
    
    func test_has_wallets_if_has_regular_wallet_and_mnemonic() throws {
        let wallet = Wallet.wallet(with: "1")
        let mockMnemonic = TonSwift.Mnemonic.mnemonicNew()
        let mnemonic = try Mnemonic(mnemonicWords: mockMnemonic)
        try keeperInfoService.updateKeeperInfo(with: wallet)
        try mockWalletMnemonicRepository.saveMnemonic(mnemonic, for: wallet)
        XCTAssertTrue(walletsController.hasWallets)
    }
    
    func test_has_wallets_if_has_regular_wallet_and_mnemonic_and_external_wallet() throws {
        let wallet = Wallet.wallet(with: "1")
        let mockMnemonic = TonSwift.Mnemonic.mnemonicNew()
        let mnemonic = try Mnemonic(mnemonicWords: mockMnemonic)
        try keeperInfoService.updateKeeperInfo(with: wallet)
        try mockWalletMnemonicRepository.saveMnemonic(mnemonic, for: wallet)
        
        let publicKey = TonSwift.PublicKey(data: String(repeating: "2", count: 32).data(using: .utf8)!)
        try walletsController.addExternalWallet(with: publicKey)
        
        XCTAssertTrue(walletsController.hasWallets)
        XCTAssertEqual(mockKeeperInfoRepository.keeperInfo?.wallets.count, 2)
    }
    
    func test_add_regular_wallet_updates_keeper_info_and_save_mnemonic() throws {
        let mockMnemonic = TonSwift.Mnemonic.mnemonicNew()
        let mnemonic = try Mnemonic(mnemonicWords: mockMnemonic)
        try walletsController.addWallet(with: mnemonic)
        XCTAssertEqual(mockKeeperInfoRepository.keeperInfo?.wallets.count, 1)
        XCTAssertEqual(mockWalletMnemonicRepository.mnemonics.count, 1)
        
        let wallet = mockKeeperInfoRepository.keeperInfo!.wallets[0]
        XCTAssertEqual(mockWalletMnemonicRepository.mnemonics[try wallet.identity.id()], mnemonic)
    }
    
    func test_add_external_wallet_updates_keeper_info() throws {
        let publicKey = TonSwift.PublicKey(data: String(repeating: "2", count: 32).data(using: .utf8)!)
        try walletsController.addExternalWallet(with: publicKey)
        XCTAssertEqual(mockKeeperInfoRepository.keeperInfo?.wallets.count, 1)
    }
    
    func test_add_regular_wallet_notify_observers() throws {
        let observer = Observer()
        walletsController.addObserver(observer)
        XCTAssertTrue(observer.addedWallets.isEmpty)
        
        let mnemonic1 = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew())
        try walletsController.addWallet(with: mnemonic1)
        XCTAssertEqual(observer.addedWallets.count, 1)
        
        let mnemonic2 = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew())
        try walletsController.addWallet(with: mnemonic2)
        XCTAssertEqual(observer.addedWallets.count, 2)
    }
    
    func test_add_external_wallet_notify_observers() throws {
        let observer = Observer()
        walletsController.addObserver(observer)
        XCTAssertTrue(observer.addedWallets.isEmpty)
        
        let publicKey1 = TonSwift.PublicKey(data: String(repeating: "2", count: 32).data(using: .utf8)!)
        try walletsController.addExternalWallet(with: publicKey1)
        XCTAssertEqual(observer.addedWallets.count, 1)
        
        let publicKey2 = TonSwift.PublicKey(data: String(repeating: "3", count: 32).data(using: .utf8)!)
        try walletsController.addExternalWallet(with: publicKey2)
        XCTAssertEqual(observer.addedWallets.count, 2)
    }
    
    func test_add_wallet_not_notify_after_remove_observer() throws {
        let observer = Observer()
        walletsController.addObserver(observer)
        XCTAssertTrue(observer.addedWallets.isEmpty)
        
        let mnemonic1 = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew())
        try walletsController.addWallet(with: mnemonic1)
        XCTAssertEqual(observer.addedWallets.count, 1)
        
        walletsController.removeObserver(observer)
        let mnemonic2 = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew())
        try walletsController.addWallet(with: mnemonic2)
        XCTAssertEqual(observer.addedWallets.count, 1)
    }
    
    func test_get_active_wallet_if_wallet_is_valid() throws {
        let wallet = Wallet.wallet(with: "1")
        let mockMnemonic = TonSwift.Mnemonic.mnemonicNew()
        let mnemonic = try Mnemonic(mnemonicWords: mockMnemonic)
        try keeperInfoService.updateKeeperInfo(with: wallet)
        try mockWalletMnemonicRepository.saveMnemonic(mnemonic, for: wallet)
        XCTAssertNoThrow(try walletsController.activeWallet)
    }
    
    func test_get_active_wallet_if_wallet_is_not_valid() throws {
        let wallet = Wallet.wallet(with: "1")
        try keeperInfoService.updateKeeperInfo(with: wallet)
        XCTAssertThrowsError(try walletsController.activeWallet)
    }
    
    func test_get_active_wallet_if_no_wallets() throws {
        XCTAssertThrowsError(try walletsController.activeWallet)
    }
    
    func test_get_private_key_for_regular_wallet() throws {
        let mnemonic1 = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew())
        let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic1.mnemonicWords)
        try walletsController.addWallet(with: mnemonic1)
        
        let privateKey = try walletsController.getWalletPrivateKey(try walletsController.activeWallet)
        XCTAssertEqual(privateKey, keyPair.privateKey)
    }
    
    func test_get_private_key_for_external_wallet_throws_error() throws {
        let publicKey = TonSwift.PublicKey(data: String(repeating: "3", count: 32).data(using: .utf8)!)
        try walletsController.addExternalWallet(with: publicKey)
        
        XCTAssertThrowsError(try walletsController.getWalletPrivateKey(try walletsController.activeWallet))
    }
}

private final class Observer: WalletProviderObserver {
    var addedWallets = [Wallet]()
    
    func walletProvider(_ walletProvider: WalletProvider,
                        didAddWallet wallet: Wallet) {
        addedWallets.append(wallet)
    }
    
    func walletProvider(_ walletProvider: WalletProvider, 
                        didChangeActiveWallet wallet: Wallet) {}
    
    func reset() {
        addedWallets = []
    }
}
