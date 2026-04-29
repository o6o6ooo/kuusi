import Combine
import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
private final class FeedNativeAdViewModel: NSObject, ObservableObject {
    @Published private(set) var nativeAd: NativeAd?

    private var adLoader: AdLoader?
    private var isLoading = false

    func loadIfNeeded(canLoadAds: Bool) {
        guard canLoadAds, nativeAd == nil, !isLoading else { return }
        guard let rootViewController = UIApplication.topViewController() else { return }

        isLoading = true

        let mediaOptions = NativeAdMediaAdLoaderOptions()
        mediaOptions.mediaAspectRatio = .square

        let adLoader = AdLoader(
            adUnitID: AppAdConfiguration.feedNativeAdUnitID,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: [mediaOptions]
        )
        adLoader.delegate = self
        self.adLoader = adLoader
        adLoader.load(Request())
    }
}

extension FeedNativeAdViewModel: AdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        isLoading = false
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        isLoading = false
    }
}

extension FeedNativeAdViewModel: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAd.delegate = self
        self.nativeAd = nativeAd
    }
}

extension FeedNativeAdViewModel: NativeAdDelegate {}

struct FeedNativeAdTileView: View {
    @Environment(\.colorScheme) private var colorScheme

    let width: CGFloat
    let canLoadAds: Bool

    @StateObject private var viewModel = FeedNativeAdViewModel()

    private var tileHeight: CGFloat {
        max(156, width * 0.72)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let nativeAd = viewModel.nativeAd {
                NativeAdRepresentable(nativeAd: nativeAd, colorScheme: colorScheme)
            } else {
                FeedNativeAdPlaceholderView()

                SponsoredBadgeView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .accessibilityIdentifier("feed-inline-ad")
        .task(id: canLoadAds) {
            viewModel.loadIfNeeded(canLoadAds: canLoadAds)
        }
    }
}

private struct FeedNativeAdPlaceholderView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#23384A").opacity(colorScheme == .dark ? 0.82 : 0.18),
                    Color(hex: "#5C9BD1").opacity(colorScheme == .dark ? 0.42 : 0.26),
                    Color(hex: "#F7FAFF").opacity(colorScheme == .dark ? 0.10 : 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ProgressView()
                .tint(AppTheme.accent(for: colorScheme))
        }
    }
}

private struct SponsoredBadgeView: View {
    var body: some View {
        Text("Sponsored")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .appFeedGlassCapsule()
            .padding(8)
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.clipsToBounds = true
        adView.backgroundColor = UIColor(AppTheme.cardBackground(for: colorScheme))

        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        adView.mediaView = mediaView
        adView.addSubview(mediaView)

        let badgeLabel = PaddingLabel(horizontalPadding: 9, verticalPadding: 5)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "Sponsored"
        badgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        badgeLabel.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        badgeLabel.layer.cornerRadius = 14
        badgeLabel.layer.masksToBounds = true
        adView.addSubview(badgeLabel)

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headlineLabel.textColor = UIColor(AppTheme.primaryText(for: colorScheme))
        headlineLabel.numberOfLines = 2
        adView.headlineView = headlineLabel
        adView.addSubview(headlineLabel)

        let advertiserLabel = UILabel()
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel.font = .systemFont(ofSize: 11, weight: .medium)
        advertiserLabel.textColor = UIColor(AppTheme.primaryText(for: colorScheme).opacity(0.68))
        advertiserLabel.numberOfLines = 1
        adView.advertiserView = advertiserLabel
        adView.addSubview(advertiserLabel)

        let callToActionButton = UIButton(type: .system)
        callToActionButton.translatesAutoresizingMaskIntoConstraints = false
        callToActionButton.titleLabel?.font = .preferredFont(forTextStyle: .caption2)
        callToActionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        callToActionButton.tintColor = UIColor(AppTheme.accent(for: colorScheme))
        callToActionButton.backgroundColor = .clear
        var callToActionConfiguration = UIButton.Configuration.plain()
        callToActionConfiguration.baseForegroundColor = UIColor(AppTheme.accent(for: colorScheme))
        callToActionConfiguration.contentInsets = .zero
        callToActionButton.configuration = callToActionConfiguration
        callToActionButton.isUserInteractionEnabled = false
        adView.callToActionView = callToActionButton
        adView.addSubview(callToActionButton)

        NSLayoutConstraint.activate([
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            mediaView.heightAnchor.constraint(equalTo: adView.heightAnchor, multiplier: 0.72),

            badgeLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
            badgeLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),

            advertiserLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            advertiserLabel.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor, constant: -10),
            advertiserLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 8),

            headlineLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
            headlineLabel.topAnchor.constraint(equalTo: advertiserLabel.bottomAnchor, constant: 2),
            headlineLabel.bottomAnchor.constraint(lessThanOrEqualTo: callToActionButton.topAnchor, constant: -6),

            callToActionButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            callToActionButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
            callToActionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        adView.nativeAd = nativeAd
    }
}

private final class PaddingLabel: UILabel {
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat

    init(horizontalPadding: CGFloat, verticalPadding: CGFloat) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: horizontalPadding, dy: verticalPadding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + horizontalPadding * 2,
            height: size.height + verticalPadding * 2
        )
    }
}
