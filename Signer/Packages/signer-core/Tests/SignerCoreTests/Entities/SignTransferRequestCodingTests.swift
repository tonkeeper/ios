import XCTest
import TonSwift
import BigInt
@testable import SignerCore

final class SignTransferRequestCodingTests: XCTestCase {
  func test_sign_transfer_request_store() throws {
    // GIVEN
    let walletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    let signTransferRequest = SignTransferRequest(
      walletLink: walletLink,
      transfer: transferCell
    )
    let base64String = """
    te6cckECAwEAALoAAUX//TAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwkAEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2FkVwYH/Q==
    """
    
    // WHEN
    let storedBase64String = try Builder()
      .store(signTransferRequest)
      .endCell()
      .toBoc()
      .base64EncodedString()
    
    // THEN
    XCTAssertEqual(storedBase64String, base64String)
  }
  
  func test_sign_transfer_request_load_from() throws {
    //GIVEN
    let base64String = """
    te6cckECAwEAALoAAUX//TAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwkAEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2FkVwYH/Q==
    """
    let walletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    
    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let signTransferRequest: SignTransferRequest = try slice.loadType()
    
    // THEN
    XCTAssertEqual(signTransferRequest.walletLink, walletLink)
    XCTAssertEqual(signTransferRequest.transfer, transferCell)
  }
  
  func test_sign_transfer_request_store_and_load() throws {
    // GIVEN
    let walletLink = MockEntities.mockWalletLink
    let transferCell = try MockEntities.mockTransferCell
    let signTransferRequest = SignTransferRequest(
      walletLink: walletLink,
      transfer: transferCell
    )
    
    // WHEN
    let storedBase64String = try Builder()
      .store(signTransferRequest)
      .endCell()
      .toBoc()
      .base64EncodedString()
    let cell = try Cell.fromBase64(src: storedBase64String)
    let slice = try cell.toSlice()
    let loadedSignTransferRequest: SignTransferRequest = try slice.loadType()
    
    // THEN
    XCTAssertEqual(loadedSignTransferRequest.walletLink, signTransferRequest.walletLink)
    XCTAssertEqual(loadedSignTransferRequest.transfer, signTransferRequest.transfer)
  }
}
