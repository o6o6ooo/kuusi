import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: SettingsProfileViewModel
    let onEditName: () -> Void
    let onEditIcon: () -> Void
    let onEditBackground: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Menu {
                Button("Edit name", systemImage: "pencil") {
                    onEditName()
                }

                Button("Edit icon", systemImage: "face.smiling") {
                    onEditIcon()
                }

                Button("Edit background", systemImage: "paintpalette") {
                    onEditBackground()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: viewModel.bgColour))
                        .frame(width: 112, height: 112)

                    Text(viewModel.icon.isEmpty ? "🌸" : viewModel.icon)
                        .font(.system(size: 58))
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Text(viewModel.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let inlineMessage = viewModel.inlineMessage {
                InlineMessageView(message: inlineMessage)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
