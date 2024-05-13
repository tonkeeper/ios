import XCTest
import TonSwift
@testable import SignerCore

final class OutputActionCellCodableTests: XCTestCase {
  func test_output_action_link_wallet_store() throws {
    // GIVEN
    let walletLinkResponse = WalletLinkResponse(walletLink: MockEntities.mockWalletLink)
    let action = OutputAction.linkWallet(walletLinkResponse)
    let base64String = """
    te6cckEBAQEAJQAARR//pgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYSEoDq3A==
    """
    
    // WHEN
    let storedBase64String = try Builder()
      .store(action)
      .endCell()
      .toBoc()
      .base64EncodedString()
    
    // THEN
    XCTAssertEqual(storedBase64String, base64String)
  }
  
  func test_output_action_link_wallet_load_from() throws {
    // GIVEN
    let base64String = """
    te6cckEBAQEAJQAARR//pgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYSEoDq3A==
    """
    let walletLinkResponse = WalletLinkResponse(walletLink: MockEntities.mockWalletLink)
    let action = OutputAction.linkWallet(walletLinkResponse)
    
    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let loadedAction: OutputAction = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedAction, action)
  }
  
  func test_output_action_sign_transfer_store() throws {
    // GIVEN
    let signTransferResponse = SignTransferResponse(
      walletLink: MockEntities.mockWalletLink,
      signedTransfer: try MockEntities.mockTransferCell
    )
    let action = OutputAction.signTransfer(signTransferResponse)
    let base64String = """
    te6cckECAwEAALoAAUU//6YGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGEgEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2Fk447Qpg==
    """
    
    // WHEN
    let storedBase64String = try Builder()
      .store(action)
      .endCell()
      .toBoc()
      .base64EncodedString()
    
    // THEN
    XCTAssertEqual(storedBase64String, base64String)
  }
  
  func test_output_action_sign_transfer_load_from() throws {
    // GIVEN
    let base64String = """
    te6cckECAwEAALoAAUU//6YGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGEgEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2Fk447Qpg==
    """
    let signTransferResponse = SignTransferResponse(
      walletLink: MockEntities.mockWalletLink,
      signedTransfer: try MockEntities.mockTransferCell
    )
    let action = OutputAction.signTransfer(signTransferResponse)
    
    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let loadedAction: OutputAction = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedAction, action)
  }
}
