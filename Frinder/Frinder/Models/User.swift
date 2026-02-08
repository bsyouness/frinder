import Foundation
import CoreLocation

struct User: Identifiable, Codable, Equatable {
    let id: String
    var email: String
    var displayName: String
    var avatarURL: String?
    var location: UserLocation?
    var friendIds: [String]
    var friendRequestsSent: [String]
    var friendRequestsReceived: [String]
    var lastUpdated: Date

    init(id: String, email: String, displayName: String, avatarURL: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.location = nil
        self.friendIds = []
        self.friendRequestsSent = []
        self.friendRequestsReceived = []
        self.lastUpdated = Date()
    }
}

struct UserLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = Date()
    }

    init(latitude: Double, longitude: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}
