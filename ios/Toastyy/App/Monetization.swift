import Combine
import GoogleMobileAds
import StoreKit
import ToastyyCore
import UIKit
import UserMessagingPlatform

@MainActor
final class Monetization: NSObject, ObservableObject, FullScreenContentDelegate {
    static let productID = "com.toastyy.app.removeads"
    static let privacyURL = URL(string: "https://toasty.app.miomideal.com/privacy.html")!
    static let supportURL = URL(string: "https://toasty.app.miomideal.com/support.html")!
    @Published private(set) var adsRemoved = false
    @Published private(set) var product: Product?
    @Published private(set) var busy = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var isPresenting = false
    @Published var message: String?
    var onPresentationChanged: ((Bool) -> Void)?
    private var interstitial: InterstitialAd?
    private var loadedAt: Double = 0
    private var loading = false
    private var initialized = false
    private var started = false
    private var updates: Task<Void, Never>?
    private var policy = AdBreakPolicy(now: ProcessInfo.processInfo.systemUptime)
    private let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    // Explicit release gate: switch off only after AdMob consent/privacy setup is complete.
    var usesTestAds: Bool { Bundle.main.object(forInfoDictionaryKey: "ToastyyUseTestAds") as? Bool ?? true }

    func start() async {
        guard !started, !uiTesting else { return }
        started = true
        // Apply before consent processing, SDK initialization, or any ad request.
        // These restrictions also apply if the user consents to personalization.
        let adConfiguration = MobileAds.shared.requestConfiguration
        adConfiguration.publisherPrivacyPersonalizationState = .disabled
        adConfiguration.setPublisherFirstPartyIDEnabled(false)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result, transaction.productID == Self.productID {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
        await refreshEntitlements()
        await loadProduct()
        await gatherConsent()
    }

    func loadProduct() async {
        do { product = try await Product.products(for: [Self.productID]).first }
        catch { product = nil }
    }

    private func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        adsRemoved = owned
        if owned { interstitial = nil }
    }

    func purchase() async {
        guard !busy, !adsRemoved else { return }
        busy = true
        defer { busy = false }
        if product == nil { await loadProduct() }
        guard let product else { message = "The purchase is not available yet. Please try again later."; return }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    message = "Apple could not verify this purchase. Please try Restore Purchases."; return
                }
                await refreshEntitlements()
                await transaction.finish()
                message = adsRemoved ? "Ads removed. Thank you for supporting Toastyy!" : "The purchase could not be restored yet. Please try again."
            case .pending: message = "Your purchase is awaiting approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase could not be completed. Please try again." }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = adsRemoved ? "Your ad-free purchase is restored." : "No Remove Ads purchase was found for this Apple Account."
        } catch { message = "Purchases could not be restored. Please try again." }
    }

    private func gatherConsent() async {
        guard !uiTesting, !adsRemoved else { return }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            setPresenting(true)
            defer { setPresenting(false) }
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // A failed consent request never blocks play or enables live ads.
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        await loadAd()
    }

    func privacyOptions() async {
        guard !isPresenting else { return }
        interstitial = nil
        setPresenting(true)
        do { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }
        catch { message = "Privacy choices could not be opened. Please try again." }
        setPresenting(false)
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        await loadAd()
    }

    private func loadAd() async {
        guard !uiTesting, !adsRemoved, !loading, ConsentInformation.shared.canRequestAds else { return }
        loading = true
        defer { loading = false }
        if !initialized {
            initialized = true
            MobileAds.shared.requestConfiguration.maxAdContentRating = .general
            await MobileAds.shared.start()
        }
        let unit = usesTestAds ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-5162263720207671/8412648888"
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        do {
            let ad = try await InterstitialAd.load(with: unit, request: request)
            guard !adsRemoved, ConsentInformation.shared.canRequestAds else { return }
            interstitial = ad
            loadedAt = ProcessInfo.processInfo.systemUptime
            ad.fullScreenContentDelegate = self
        } catch { interstitial = nil }
    }

    func completedRound() { policy.completedRound() }

    func presentAfterRun(afterBurn: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard !uiTesting, !adsRemoved, !isPresenting, ConsentInformation.shared.canRequestAds,
              policy.isEligible(afterBurn: afterBurn, now: now) else { return }
        guard let ad = interstitial, now - loadedAt < 3_500 else {
            interstitial = nil
            Task { await loadAd() }
            return
        }
        do { try ad.canPresent(from: nil) }
        catch { interstitial = nil; Task { await loadAd() }; return }
        interstitial = nil
        setPresenting(true)
        ad.present(from: nil)
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        policy.didPresent(now: ProcessInfo.processInfo.systemUptime)
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        setPresenting(false)
        Task { await loadAd() }
    }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        setPresenting(false)
        Task { await loadAd() }
    }
    private func setPresenting(_ value: Bool) {
        isPresenting = value
        onPresentationChanged?(value)
    }
}
