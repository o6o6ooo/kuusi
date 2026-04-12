import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct GroupQRCodeOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var toastMessage: AppMessage?
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }

    var body: some View {
        let qrImage = makeQRCodeImage(from: payload)

        NavigationStack {
            VStack(spacing: 18) {
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(18)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                ShareLink(item: payload) {
                    Text("Share QR code")
                        .appTextLinkStyle()
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .appOverlayTheme()
            .task {
                if qrImage == nil {
                    toastMessage = AppMessage(.failedToGenerateQRCode, .error)
                }
            }
            .appToastMessage(toastMessage) {
                toastMessage = nil
            }
            .appToastHost()
        }
    }

    private func makeQRCodeImage(from string: String) -> UIImage? {
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
