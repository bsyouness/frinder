import Foundation
import CoreLocation

struct Landmark: Identifiable {
    let id: String
    let name: String
    let icon: String
    let coordinate: CLLocationCoordinate2D

    /// Calculate distance in meters from a given location
    func distance(from location: CLLocationCoordinate2D) -> Double {
        let landmarkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return landmarkLocation.distance(from: userLocation)
    }

    /// Calculate bearing from user location to this landmark
    func bearing(from location: CLLocationCoordinate2D) -> Double {
        let lat1 = location.latitude.toRadians()
        let lon1 = location.longitude.toRadians()
        let lat2 = coordinate.latitude.toRadians()
        let lon2 = coordinate.longitude.toRadians()

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x).toDegrees()
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}

// MARK: - Famous Landmarks
extension Landmark {
    static let allLandmarks: [Landmark] = [
        // Europe
        Landmark(
            id: "eiffel_tower",
            name: "Eiffel Tower",
            icon: "🗼",
            coordinate: CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)
        ),
        Landmark(
            id: "big_ben",
            name: "Big Ben",
            icon: "🕰️",
            coordinate: CLLocationCoordinate2D(latitude: 51.5007, longitude: -0.1246)
        ),
        Landmark(
            id: "colosseum",
            name: "Colosseum",
            icon: "🏛️",
            coordinate: CLLocationCoordinate2D(latitude: 41.8902, longitude: 12.4922)
        ),
        Landmark(
            id: "sagrada_familia",
            name: "Sagrada Familia",
            icon: "⛪",
            coordinate: CLLocationCoordinate2D(latitude: 41.4036, longitude: 2.1744)
        ),
        Landmark(
            id: "leaning_tower_pisa",
            name: "Leaning Tower of Pisa",
            icon: "🏗️",
            coordinate: CLLocationCoordinate2D(latitude: 43.7230, longitude: 10.3966)
        ),
        Landmark(
            id: "acropolis",
            name: "Acropolis",
            icon: "🏛️",
            coordinate: CLLocationCoordinate2D(latitude: 37.9715, longitude: 23.7257)
        ),

        // North America
        Landmark(
            id: "statue_of_liberty",
            name: "Statue of Liberty",
            icon: "🗽",
            coordinate: CLLocationCoordinate2D(latitude: 40.6892, longitude: -74.0445)
        ),
        Landmark(
            id: "mount_rushmore",
            name: "Mount Rushmore",
            icon: "🏔️",
            coordinate: CLLocationCoordinate2D(latitude: 43.8791, longitude: -103.4591)
        ),
        Landmark(
            id: "golden_gate_bridge",
            name: "Golden Gate Bridge",
            icon: "🌉",
            coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
        ),
        Landmark(
            id: "empire_state_building",
            name: "Empire State Building",
            icon: "🏙️",
            coordinate: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9857)
        ),
        Landmark(
            id: "grand_canyon",
            name: "Grand Canyon",
            icon: "🏜️",
            coordinate: CLLocationCoordinate2D(latitude: 36.0544, longitude: -112.1401)
        ),
        Landmark(
            id: "niagara_falls",
            name: "Niagara Falls",
            icon: "💧",
            coordinate: CLLocationCoordinate2D(latitude: 43.0962, longitude: -79.0377)
        ),

        // Asia
        Landmark(
            id: "shanghai_tower",
            name: "Shanghai Tower",
            icon: "🏢",
            coordinate: CLLocationCoordinate2D(latitude: 31.2335, longitude: 121.5055)
        ),
        Landmark(
            id: "burj_khalifa",
            name: "Burj Khalifa",
            icon: "🗼",
            coordinate: CLLocationCoordinate2D(latitude: 25.1972, longitude: 55.2744)
        ),
        Landmark(
            id: "great_wall_china",
            name: "Great Wall of China",
            icon: "🧱",
            coordinate: CLLocationCoordinate2D(latitude: 40.4319, longitude: 116.5704)
        ),
        Landmark(
            id: "taj_mahal",
            name: "Taj Mahal",
            icon: "🕌",
            coordinate: CLLocationCoordinate2D(latitude: 27.1751, longitude: 78.0421)
        ),
        Landmark(
            id: "mount_fuji",
            name: "Mount Fuji",
            icon: "🗻",
            coordinate: CLLocationCoordinate2D(latitude: 35.3606, longitude: 138.7274)
        ),
        Landmark(
            id: "angkor_wat",
            name: "Angkor Wat",
            icon: "🛕",
            coordinate: CLLocationCoordinate2D(latitude: 13.4125, longitude: 103.8670)
        ),
        Landmark(
            id: "petronas_towers",
            name: "Petronas Towers",
            icon: "🏬",
            coordinate: CLLocationCoordinate2D(latitude: 3.1578, longitude: 101.7117)
        ),

        // Middle East & Africa
        Landmark(
            id: "pyramids_giza",
            name: "Pyramids of Giza",
            icon: "🔺",
            coordinate: CLLocationCoordinate2D(latitude: 29.9792, longitude: 31.1342)
        ),
        Landmark(
            id: "petra",
            name: "Petra",
            icon: "🏜️",
            coordinate: CLLocationCoordinate2D(latitude: 30.3285, longitude: 35.4444)
        ),

        // South America
        Landmark(
            id: "christ_redeemer",
            name: "Christ the Redeemer",
            icon: "✝️",
            coordinate: CLLocationCoordinate2D(latitude: -22.9519, longitude: -43.2105)
        ),
        Landmark(
            id: "machu_picchu",
            name: "Machu Picchu",
            icon: "🏔️",
            coordinate: CLLocationCoordinate2D(latitude: -13.1631, longitude: -72.5450)
        ),

        // Australia & Oceania
        Landmark(
            id: "sydney_opera_house",
            name: "Sydney Opera House",
            icon: "🎭",
            coordinate: CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
        ),
        Landmark(
            id: "uluru",
            name: "Uluru",
            icon: "🪨",
            coordinate: CLLocationCoordinate2D(latitude: -25.3444, longitude: 131.0369)
        )
    ]
}
