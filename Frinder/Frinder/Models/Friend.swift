import Foundation
import CoreLocation

struct Friend: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String?
    var location: UserLocation?

    var distance: CLLocationDistance? {
        nil // Calculated dynamically based on user's current location
    }

    func distance(from userLocation: CLLocation) -> CLLocationDistance? {
        guard let friendLocation = location else { return nil }
        let friendCLLocation = CLLocation(latitude: friendLocation.latitude, longitude: friendLocation.longitude)
        return userLocation.distance(from: friendCLLocation)
    }

    func bearing(from userLocation: CLLocation) -> Double? {
        guard let friendLocation = location else { return nil }
        return calculateBearing(
            from: userLocation.coordinate,
            to: friendLocation.coordinate
        )
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        return GeoMath.bearing(from: from, to: to)
    }
}
