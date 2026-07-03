import SwiftUI

struct OnboardingView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var selectedSlideID = OnboardingSlide.slides[0].id

	let onFinish: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			TabView(selection: $selectedSlideID) {
				ForEach(OnboardingSlide.slides) { slide in
					OnboardingSlideView(slide: slide, reduceMotion: reduceMotion)
						.tag(slide.id)
				}
			}
			.tabViewStyle(.page(indexDisplayMode: .always))
			.indexViewStyle(.page(backgroundDisplayMode: .never))

			Button(action: handlePrimaryButton) {
				Text(
					LocalizedStringKey(
						isFinalSlide ? "onboarding.finish" : "onboarding.next"
					)
				)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 6)
			}
			.buttonStyle(.appPrimaryCapsule(font: .body.weight(.semibold)))
			.padding(.horizontal, 72)
			.padding(.top, 18)
			.padding(.bottom, 24)
			.accessibilityIdentifier("onboarding-primary-button")
		}
		.appOverlayTheme()
		.interactiveDismissDisabled()
		.accessibilityIdentifier("onboarding-screen")
	}

	private var currentSlideIndex: Int {
		OnboardingSlide.slides.firstIndex { $0.id == selectedSlideID } ?? 0
	}

	private var isFinalSlide: Bool {
		currentSlideIndex == OnboardingSlide.slides.count - 1
	}

	private func handlePrimaryButton() {
		guard !isFinalSlide else {
			onFinish()
			return
		}

		let nextIndex = min(currentSlideIndex + 1, OnboardingSlide.slides.count - 1)
		withAnimation(.easeInOut(duration: 0.28)) {
			selectedSlideID = OnboardingSlide.slides[nextIndex].id
		}
	}
}

private struct OnboardingSlideView: View {
	let slide: OnboardingSlide
	let reduceMotion: Bool

	var body: some View {
		VStack(spacing: 22) {
			Spacer(minLength: 18)

			OnboardingMediaView(media: slide.media, reduceMotion: reduceMotion)
				.frame(maxWidth: 340)
				.frame(maxHeight: 520)
				.padding(.horizontal, 24)

			VStack(spacing: 10) {
				Text(slide.titleKey)
					.font(.title2.weight(.bold))
					.multilineTextAlignment(.center)

				Text(slide.descriptionKey)
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.lineSpacing(2)
			}
			.padding(.horizontal, 28)
			.padding(.bottom, 36)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

private struct OnboardingMediaView: View {
	let media: OnboardingMedia
	let reduceMotion: Bool

	@State private var currentImageIndex = 0

	var body: some View {
		Group {
			switch media {
			case let .image(name):
				screenshotImage(name)
			case let .loopingImages(names):
				screenshotImage(names[safe: currentImageIndex] ?? names[0])
					.task(id: reduceMotion) {
						currentImageIndex = 0
						guard !reduceMotion else { return }
						guard names.count > 1 else { return }
						while !Task.isCancelled {
							try? await Task.sleep(nanoseconds: 1_050_000_000)
							currentImageIndex = (currentImageIndex + 1) % names.count
						}
					}
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
		.accessibilityHidden(true)
	}

	private func screenshotImage(_ name: String) -> some View {
		Image(name)
			.resizable()
			.scaledToFit()
	}
}

private struct OnboardingSlide: Identifiable {
	let id: String
	let titleKey: LocalizedStringKey
	let descriptionKey: LocalizedStringKey
	let media: OnboardingMedia

	static let slides: [OnboardingSlide] = [
		OnboardingSlide(
			id: "feed",
			titleKey: "onboarding.feed.title",
			descriptionKey: "onboarding.feed.description",
			media: .loopingImages([
				"OnboardingFeedEmpty",
				"OnboardingFeedEmptyPoint"
			])
		),
		OnboardingSlide(
			id: "profile",
			titleKey: "onboarding.profile.title",
			descriptionKey: "onboarding.profile.description",
			media: .loopingImages([
				"OnboardingProfileClosed",
				"OnboardingProfilePoint",
				"OnboardingProfileMenuOpen"
			])
		),
		OnboardingSlide(
			id: "groups",
			titleKey: "onboarding.groups.title",
			descriptionKey: "onboarding.groups.description",
			media: .loopingImages([
				"OnboardingGroupsClosed",
				"OnboardingGroupsPoint",
				"OnboardingGroupsMenuOpen"
			])
		),
		OnboardingSlide(
			id: "upload",
			titleKey: "onboarding.upload.title",
			descriptionKey: "onboarding.upload.description",
			media: .loopingImages([
				"OnboardingUploadClosed",
				"OnboardingUploadPoint",
				"OnboardingUploadMenuOpen"
			])
		)
	]
}

private enum OnboardingMedia {
	case image(String)
	case loopingImages([String])
}

private extension Array {
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
