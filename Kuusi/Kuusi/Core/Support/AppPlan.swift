import Foundation

enum AppPlan: String {
	case free
	case premium

	var quotaMB: Double {
		switch self {
		case .free:
			return 1024.0
		case .premium:
			return 30720.0
		}
	}

	var maxGroups: Int {
		switch self {
		case .free:
			return 3
		case .premium:
			return 10
		}
	}

	var title: String {
		switch self {
		case .free:
			return "Free"
		case .premium:
			return "Premium"
		}
	}

	var priceLabel: String? {
		switch self {
		case .free:
			return nil
		case .premium:
			return "£24.99 / year"
		}
	}

	var productID: String? {
		switch self {
		case .free:
			return nil
		case .premium:
			return "com.swallace.kuusi.premium.annual"
		}
	}

	var featureLines: [String] {
		switch self {
		case .free:
			return [
				String(localized: "plan.free.feature.storage"),
				String(localized: "plan.free.feature.previews"),
				String(localized: "plan.free.feature.groups"),
				String(localized: "plan.free.feature.ads"),
			]
		case .premium:
			return [
				String(localized: "plan.premium.feature.storage"),
				String(localized: "plan.premium.feature.previews"),
				String(localized: "plan.premium.feature.groups"),
				String(localized: "plan.premium.feature.ads"),
			]
		}
	}
}

enum PlanAccessPolicy {
	static func currentPlan(isPremiumActive: Bool) -> AppPlan {
		isPremiumActive ? .premium : .free
	}

	static func previewAccess(
		for createdAt: Date?,
		isPremiumActive: Bool,
		now: Date = Date(),
		calendar: Calendar = .current
	) -> PreviewAccess {
		guard !isPremiumActive else { return .full }
		guard let createdAt else { return .full }
		guard
			let expiryDate = calendar.date(byAdding: .year, value: 2, to: createdAt)
		else {
			return .full
		}

		return now < expiryDate ? .full : .thumbnailOnly
	}

	static func previewAccess(
		for photo: FeedPhoto,
		isPremiumActive: Bool,
		now: Date = Date()
	) -> PreviewAccess {
		previewAccess(
			for: photo.createdAt,
			isPremiumActive: isPremiumActive,
			now: now
		)
	}

	static func isStorageLimitReached(usageMB: Double, isPremiumActive: Bool)
		-> Bool
	{
		let quotaMB = currentPlan(isPremiumActive: isPremiumActive).quotaMB
		return usageMB >= quotaMB
	}

	static func canUpload(
		currentUsageMB: Double,
		additionalUsageMB: Double,
		isPremiumActive: Bool
	) -> Bool {
		let quotaMB = currentPlan(isPremiumActive: isPremiumActive).quotaMB
		return currentUsageMB + additionalUsageMB <= quotaMB
	}

	static func overflowMB(usageMB: Double, isPremiumActive: Bool) -> Double {
		let quotaMB = currentPlan(isPremiumActive: isPremiumActive).quotaMB
		return max(usageMB - quotaMB, 0)
	}
}

enum PreviewAccess {
	case full
	case thumbnailOnly
}
