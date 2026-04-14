import SwiftUI

struct FeedBottomChromeView: View {
    @Environment(\.colorScheme) private var colorScheme

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
                        .frame(width: 54, height: 54)
                        .background(glassCircleBackground)
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
                    .frame(width: 54, height: 54)
                    .background(glassCircleBackground)
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
                .frame(height: 54)
                .frame(maxWidth: 280)
                .padding(.horizontal, 6)
                .background(glassPillBackground)
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
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
                                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(Color.clear)
                        )
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22)
                                : Color.clear,
                            lineWidth: isSelected ? 0.8 : 0
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var glassCircleBackground: some View {
        let shape = Circle()

        return ZStack {
            Color.clear
                .background(.ultraThinMaterial, in: shape)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.05),
                            Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.26),
                            Color.white.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )

            shape
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.1),
                    lineWidth: 0.6
                )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var glassPillBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)

        return ZStack {
            Color.clear
                .background(.ultraThinMaterial, in: shape)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.05),
                            Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
                            Color.white.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )

            shape
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.1),
                    lineWidth: 0.6
                )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var chromePrimaryColor: Color {
        Color.white.opacity(0.94)
    }

    private var chromeShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22)
    }
}
