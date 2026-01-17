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
        let lat1 = from.latitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let deltaLon = (to.longitude - from.longitude).toRadians()

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        var bearing = atan2(y, x).toDegrees()
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}

extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }

    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}
