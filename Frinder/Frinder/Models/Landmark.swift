import Foundation
import CoreLocation

struct Landmark: Identifiable {
    let id: String
    let name: String
    let icon: String
    let coordinate: CLLocationCoordinate2D
    let city: String
    let country: String

    var locationLabel: String {
        "\(city), \(country)"
    }

    /// Calculate distance in meters from a given location
    func distance(from location: CLLocationCoordinate2D) -> Double {
        let landmarkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return landmarkLocation.distance(from: userLocation)
    }

    /// Calculate bearing from user location to this landmark
    /// - Returns: Bearing in degrees (0-360)
    func bearing(from location: CLLocationCoordinate2D) -> Double {
        return GeoMath.bearing(from: location, to: coordinate)
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
            coordinate: CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945),
            city: "Paris",
            country: "France"
        ),
        Landmark(
            id: "big_ben",
            name: "Big Ben",
            icon: "🕰️",
            coordinate: CLLocationCoordinate2D(latitude: 51.5007, longitude: -0.1246),
            city: "London",
            country: "United Kingdom"
        ),
        Landmark(
            id: "colosseum",
            name: "Colosseum",
            icon: "🏛️",
            coordinate: CLLocationCoordinate2D(latitude: 41.8902, longitude: 12.4922),
            city: "Rome",
            country: "Italy"
        ),
        Landmark(
            id: "sagrada_familia",
            name: "Sagrada Familia",
            icon: "⛪",
            coordinate: CLLocationCoordinate2D(latitude: 41.4036, longitude: 2.1744),
            city: "Barcelona",
            country: "Spain"
        ),
        Landmark(
            id: "leaning_tower_pisa",
            name: "Leaning Tower of Pisa",
            icon: "🏗️",
            coordinate: CLLocationCoordinate2D(latitude: 43.7230, longitude: 10.3966),
            city: "Pisa",
            country: "Italy"
        ),
        Landmark(
            id: "acropolis",
            name: "Acropolis",
            icon: "🏛️",
            coordinate: CLLocationCoordinate2D(latitude: 37.9715, longitude: 23.7257),
            city: "Athens",
            country: "Greece"
        ),

        // North America
        Landmark(
            id: "mount_rushmore",
            name: "Mount Rushmore",
            icon: "🏔️",
            coordinate: CLLocationCoordinate2D(latitude: 43.8791, longitude: -103.4591),
            city: "Keystone",
            country: "United States"
        ),
        Landmark(
            id: "golden_gate_bridge",
            name: "Golden Gate Bridge",
            icon: "🌉",
            coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
            city: "San Francisco",
            country: "United States"
        ),
        Landmark(
            id: "empire_state_building",
            name: "Empire State Building",
            icon: "🏙️",
            coordinate: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9857),
            city: "New York",
            country: "United States"
        ),
        Landmark(
            id: "grand_canyon",
            name: "Grand Canyon",
            icon: "🏜️",
            coordinate: CLLocationCoordinate2D(latitude: 36.0544, longitude: -112.1401),
            city: "Grand Canyon Village",
            country: "United States"
        ),
        Landmark(
            id: "niagara_falls",
            name: "Niagara Falls",
            icon: "💧",
            coordinate: CLLocationCoordinate2D(latitude: 43.0962, longitude: -79.0377),
            city: "Niagara Falls",
            country: "Canada"
        ),

        // Asia
        Landmark(
            id: "shanghai_tower",
            name: "Shanghai Tower",
            icon: "🏢",
            coordinate: CLLocationCoordinate2D(latitude: 31.2335, longitude: 121.5055),
            city: "Shanghai",
            country: "China"
        ),
        Landmark(
            id: "burj_khalifa",
            name: "Burj Khalifa",
            icon: "🗼",
            coordinate: CLLocationCoordinate2D(latitude: 25.1972, longitude: 55.2744),
            city: "Dubai",
            country: "United Arab Emirates"
        ),
        Landmark(
            id: "great_wall_china",
            name: "Great Wall of China",
            icon: "🧱",
            coordinate: CLLocationCoordinate2D(latitude: 40.4319, longitude: 116.5704),
            city: "Beijing",
            country: "China"
        ),
        Landmark(
            id: "taj_mahal",
            name: "Taj Mahal",
            icon: "🕌",
            coordinate: CLLocationCoordinate2D(latitude: 27.1751, longitude: 78.0421),
            city: "Agra",
            country: "India"
        ),
        Landmark(
            id: "mount_fuji",
            name: "Mount Fuji",
            icon: "🗻",
            coordinate: CLLocationCoordinate2D(latitude: 35.3606, longitude: 138.7274),
            city: "Fujinomiya",
            country: "Japan"
        ),
        Landmark(
            id: "angkor_wat",
            name: "Angkor Wat",
            icon: "🛕",
            coordinate: CLLocationCoordinate2D(latitude: 13.4125, longitude: 103.8670),
            city: "Siem Reap",
            country: "Cambodia"
        ),
        // Middle East & Africa
        Landmark(
            id: "pyramids_giza",
            name: "Pyramids of Giza",
            icon: "🔺",
            coordinate: CLLocationCoordinate2D(latitude: 29.9792, longitude: 31.1342),
            city: "Giza",
            country: "Egypt"
        ),
        // South America
        Landmark(
            id: "christ_redeemer",
            name: "Christ the Redeemer",
            icon: "✝️",
            coordinate: CLLocationCoordinate2D(latitude: -22.9519, longitude: -43.2105),
            city: "Rio de Janeiro",
            country: "Brazil"
        ),
        Landmark(
            id: "machu_picchu",
            name: "Machu Picchu",
            icon: "🏔️",
            coordinate: CLLocationCoordinate2D(latitude: -13.1631, longitude: -72.5450),
            city: "Cusco",
            country: "Peru"
        ),

        // Australia & Oceania
        Landmark(
            id: "sydney_opera_house",
            name: "Sydney Opera House",
            icon: "🎭",
            coordinate: CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153),
            city: "Sydney",
            country: "Australia"
        )
    ]
}
