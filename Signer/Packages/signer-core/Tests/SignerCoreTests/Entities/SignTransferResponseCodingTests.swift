import XCTest
import TonSwift
import BigInt
@testable import SignerCore

final class SignTransferResponseCodingTests: XCTestCase {
  func test_sign_transfer_response_store() throws {
    // GIVEN
    let walletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    let signTransferResponse = SignTransferResponse(
      walletLink: walletLink,
      signedTransfer: transferCell
    )
    let base64String = """
    te6cckECAwEAALoAAUX//TAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwkAEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2FkVwYH/Q==
    """
    
    // WHEN
    let storedBase64String = try Builder()
      .store(signTransferResponse)
      .endCell()
      .toBoc()
      .base64EncodedString()
    
    // THEN
    XCTAssertEqual(storedBase64String, base64String)
  }
  
  func test_sign_transfer_response_load_from() throws {
    //GIVEN
    let base64String = """
    te6cckECAwEAALoAAUX//TAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwkAEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2FkVwYH/Q==
    """
    let walletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    
    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let signTransferResponse: SignTransferResponse = try slice.loadType()
    
    // THEN
    XCTAssertEqual(signTransferResponse.walletLink, walletLink)
    XCTAssertEqual(signTransferResponse.signedTransfer, transferCell)
  }
  
  func test_sign_transfer_response_store_and_load() throws {
    // GIVEN
    let mockWalletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    let signTransferResponse = SignTransferResponse(
      walletLink: mockWalletLink,
      signedTransfer: transferCell
    )
    
    // WHEN
    let storedBase64String = try Builder()
      .store(signTransferResponse)
      .endCell()
      .toBoc()
      .base64EncodedString()
    let cell = try Cell.fromBase64(src: storedBase64String)
    let slice = try cell.toSlice()
    let loadedSignTransferResponse: SignTransferResponse = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedSignTransferResponse.walletLink, signTransferResponse.walletLink)
    XCTAssertEqual(loadedSignTransferResponse.signedTransfer, signTransferResponse.signedTransfer)
  }
}
