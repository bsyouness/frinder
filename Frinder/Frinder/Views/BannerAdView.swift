import SwiftUI
import GoogleMobileAds

// Replace with your real ad unit ID for production
let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174" // Test banner
let bannerAdHeight: CGFloat = AdSizeBanner.size.height

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = bannerAdUnitID) {
        self.adUnitID = adUnitID
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.adSize = AdSizeBanner
        banner.translatesAutoresizingMaskIntoConstraints = false

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
        }

        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        banner.load(Request())
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
