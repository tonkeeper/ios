import XCTest
import TonSwift
@testable import SignerCore

final class InputActionCellCodableTests: XCTestCase {
  func test_input_action_link_wallet_store() throws {
    // GIVEN
    let action = InputAction.linkWallet
    let base64String = """
    te6cckEBAQEAAwAAARAlCGVl
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

  func test_input_action_link_wallet_load_from() throws {
    // GIVEN
    let base64String = """
    te6cckEBAQEAAwAAARAlCGVl
    """
    let action = InputAction.linkWallet

    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let loadedAction: InputAction = try slice.loadType()

    // THEN
    XCTAssertEqual(loadedAction, action)
  }
//
  func test_input_action_sign_transfer_store() throws {
    // GIVEN
    let signTransferRequest = SignTransferRequest(
      walletLink: MockEntities.mockWalletLink,
      transfer: try MockEntities.mockTransferCell
    )
    let action = InputAction.signTransfer(signTransferRequest)
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

  func test_input_action_sign_transfer_load_from() throws {
    // GIVEN
    let base64String = """
    te6cckECAwEAALoAAUU//6YGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGEgEBnDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDApqaMXAAAAPAAAIxAAAwIAgmIABsJ6oBmhsHRn4aru3t1Lh8xRmyEkc3chqSIsl+Kkv4SIUAAAAAAAAAAAAAAAAAAAAAAAdGV4dCBwYXlsb2Fk447Qpg==
    """
    let signTransferRequest = SignTransferRequest(
      walletLink: MockEntities.mockWalletLink,
      transfer: try MockEntities.mockTransferCell
    )
    let action = InputAction.signTransfer(signTransferRequest)

    // WHEN
    let cell = try Cell.fromBase64(src: base64String)
    let slice = try cell.toSlice()
    let loadedAction: InputAction = try slice.loadType()

    // THEN
    XCTAssertEqual(loadedAction, action)
  }
}
