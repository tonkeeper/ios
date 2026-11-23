import AppUI
import Foundation
import SwiftUI

/// Details for a sheet that keeps the view it opened with: they rebuild whenever the wallet decrypts a comment.
struct MultichainLiveTransactionDetailsView: View {
    @ObservedObject var encryptedComments: MultichainEncryptedComments
    let model: () -> MultichainTransactionDetailsModel
    let onOpenTransaction: (URL, String?) -> Void

    var body: some View {
        MultichainTransactionDetailsView(
            model: model(),
            onOpenTransaction: onOpenTransaction,
            onCopy: { Pasteboard.copy(value: $0) }
        )
    }
}
