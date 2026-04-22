import SwiftUI

struct FeedBottomChromeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var hashtagSelectionNamespace

    let groups: [GroupSummary]
    let availableHashtags: [String]
    @Binding var selectedHashtag: String?
    @Binding var isHashtagBarExpanded: Bool
    let onSelectGroup: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !groups.isEmpty {
                Menu {
                    ForEach(groups) { group in
                        Button(group.name) {
                            onSelectGroup(group.id)
                        }
                    }
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(chromePrimaryColor)
                        .shadow(color: chromeShadowColor.opacity(0.9), radius: 8, x: 0, y: 3)
                        .frame(width: 48, height: 48)
                        .appFeedGlassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed-group-button")
            }

            Spacer(minLength: 0)

            if !availableHashtags.isEmpty {
                hashtagBar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 0)
        .background(.clear)
    }

    private var hashtagBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isHashtagBarExpanded.toggle()
                }
            } label: {
                Image(systemName: "number")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(chromePrimaryColor)
                    .shadow(color: chromeShadowColor.opacity(0.9), radius: 8, x: 0, y: 3)
                    .frame(width: 48, height: 48)
                    .appFeedGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed-hashtag-toggle-button")

            if isHashtagBarExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        hashtagChip(
                            title: "All",
                            isSelected: selectedHashtag == nil,
                            action: { selectedHashtag = nil }
                        )

                        ForEach(availableHashtags, id: \.self) { hashtag in
                            hashtagChip(
                                title: "#\(hashtag)",
                                isSelected: selectedHashtag == hashtag,
                                action: { selectedHashtag = hashtag }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 48)
                .frame(maxWidth: 280)
                .padding(.horizontal, 6)
                .appFeedGlassPill()
            }
        }
    }

    private func hashtagChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(chromePrimaryColor)
                .shadow(color: chromeShadowColor.opacity(0.9), radius: 8, x: 0, y: 3)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(selectionFill(isSelected: isSelected))
                .overlay {
                    selectionStroke(isSelected: isSelected)
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.12, dampingFraction: 0.86), value: selectedHashtag)
    }

    @ViewBuilder
    private func selectionFill(isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .matchedGeometryEffect(id: "selectedHashtagChip", in: hashtagSelectionNamespace)
        }
    }

    @ViewBuilder
    private func selectionStroke(isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
                    lineWidth: 0.8
                )
                .matchedGeometryEffect(id: "selectedHashtagChipStroke", in: hashtagSelectionNamespace)
        }
    }

    private var chromePrimaryColor: Color {
        Color.white.opacity(0.94)
    }

    private var chromeShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22)
    }
}
