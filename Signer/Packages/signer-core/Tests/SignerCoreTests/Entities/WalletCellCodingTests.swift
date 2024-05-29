import XCTest
import TonSwift
@testable import SignerCore

final class WalletCellCodingTests: XCTestCase {
  func test_wallet_store_to() throws {
    // GIVEN
    let base64BocString = "te6cckEBAQEAJQAARf/9MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDCQ3cSmOQ=="
    let publicKey = TonSwift.PublicKey(data: String(repeating: "0", count: 32).data(using: .utf8)!)
    let builder = Builder()
    let wallet = WalletLink(
      network: .testnet,
      publicKey: publicKey,
      contractVersion: .v4R2)

    // WHEN
    let storedBase64BocString = try builder.store(wallet)
      .endCell()
      .toBoc()
      .base64EncodedString()
    
    // THEN
    XCTAssertEqual(storedBase64BocString, base64BocString)
  }
  
  func test_wallet_load_from() throws {
    // GIVEN
    let base64BocString = "te6cckEBAQEAJQAARf/9MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDCQ3cSmOQ=="
    let publicKey = TonSwift.PublicKey(data: String(repeating: "0", count: 32).data(using: .utf8)!)
    let wallet = WalletLink(
      network: .testnet,
      publicKey: publicKey,
      contractVersion: .v4R2)
    
    // WHEN
    let cell = try Cell.fromBase64(src: base64BocString)
    let slice = try cell.toSlice()
    let loadedWallet: WalletLink = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedWallet, wallet)
  }
  
  func test_wallet_store_and_load() throws {
    // GIVEN
    let publicKey = TonSwift.PublicKey(data: String(repeating: "0", count: 32).data(using: .utf8)!)
    let builder = Builder()
    let wallet = WalletLink(
      network: .testnet,
      publicKey: publicKey,
      contractVersion: .v4R2)
    
    // WHEN
    let storedBase64BocString = try builder.store(wallet)
      .endCell()
      .toBoc()
      .base64EncodedString()
    let cell = try Cell.fromBase64(src: storedBase64BocString)
    let slice = try cell.toSlice()
    let loadedWallet: WalletLink = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedWallet, wallet)
  }
}
