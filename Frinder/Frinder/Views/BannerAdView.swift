import SwiftUI
import GoogleMobileAds

// Replace with your real ad unit ID for production
let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174" // Test banner

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = bannerAdUnitID) {
        self.adUnitID = adUnitID
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.translatesAutoresizingMaskIntoConstraints = false

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
            let adSize = largeAnchoredAdaptiveBanner(width: windowScene.screen.bounds.width)
            banner.adSize = adSize
        }

        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
