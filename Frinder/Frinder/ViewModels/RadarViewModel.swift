import Foundation
import SwiftUI
import CoreLocation
import CoreMotion
import Combine

@MainActor
class RadarViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var deviceHeading: Double = 0
    @Published var rotationMatrix: CMRotationMatrix?
    @Published var currentLocation: CLLocation?
    @Published var isLocationAuthorized = false
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var targetFriend: Friend?

    let landmarks = Landmark.allLandmarks
    var showLandmarks: Bool { AppSettings.shared.showLandmarks }

    /// Horizontal field of view in degrees (total angle visible on screen width)
    private let horizontalFOV: Double = 60.0
    /// Vertical field of view in degrees (total angle visible on screen height)
    private let verticalFOV: Double = 90.0

    /// Get landmarks that are within the current field of view
    var visibleLandmarks: [Landmark] {
        guard let userLocation = currentLocation, let R = rotationMatrix else { return [] }
        let screenSize = CGSize(width: 400, height: 800) // reference size for visibility check
        return landmarks.filter { landmark in
            let dir = GeoMath.directionVector(from: userLocation.coordinate, to: landmark.coordinate)
            return GeoMath.projectToScreen(
                worldDirection: dir,
                rotationMatrix: R,
                horizontalFOV: horizontalFOV,
                verticalFOV: verticalFOV,
                screenSize: screenSize
            ) != nil
        }
    }

    /// Get friends that are within the current field of view (excludes stale >5min)
    var visibleFriends: [Friend] {
        guard let userLocation = currentLocation, let R = rotationMatrix else { return [] }
        let screenSize = CGSize(width: 400, height: 800)
        let now = Date()
        let result = friends.filter { friend in
            guard let location = friend.location,
                  now.timeIntervalSince(location.timestamp) < 300 else { return false }
            let dir = GeoMath.directionVector(from: userLocation.coordinate, to: location.coordinate)
            return GeoMath.projectToScreen(
                worldDirection: dir,
                rotationMatrix: R,
                horizontalFOV: horizontalFOV,
                verticalFOV: verticalFOV,
                screenSize: screenSize
            ) != nil
        }
        // Auto-clear target if they become visible on screen
        if let target = targetFriend, result.contains(where: { $0.id == target.id }) {
            Task { @MainActor in self.targetFriend = nil }
        }
        return result
    }

    /// Compute the angle (in degrees) from screen center toward the target friend
    func arrowAngle() -> Double? {
        guard let target = targetFriend,
              let location = target.location,
              let userLocation = currentLocation else { return nil }
        let targetBearing = GeoMath.bearing(from: userLocation.coordinate, to: location.coordinate)
        return GeoMath.relativeBearing(targetBearing: targetBearing, deviceHeading: deviceHeading)
    }

    private let locationService = LocationService.shared
    private let motionService = MotionService.shared
    private let friendService = FriendService.shared
    private var cancellables = Set<AnyCancellable>()
    private var userId: String?

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind location updates
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location
                if let location = location, let userId = self?.userId {
                    Task {
                        try? await self?.updateUserLocation(location, userId: userId)
                    }
                }
            }
            .store(in: &cancellables)

        // Bind rotation matrix from MotionService
        motionService.$rotationMatrix
            .receive(on: DispatchQueue.main)
            .sink { [weak self] matrix in
                self?.rotationMatrix = matrix
                if let R = matrix {
                    self?.deviceHeading = GeoMath.headingFromRotationMatrix(R)
                }
            }
            .store(in: &cancellables)

        // Bind authorization status
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthorizationStatus = status
                self?.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            }
            .store(in: &cancellables)

        // Bind friends from service
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .assign(to: &$friends)
    }

    func requestLocationAuthorization() {
        locationService.requestAuthorization()
    }

    func startTracking(userId: String) {
        self.userId = userId
        locationService.requestAuthorization()
        locationService.startUpdatingLocation()
        locationService.startUpdatingHeading()
        motionService.startUpdates()
        friendService.startListeningToFriends(userId: userId)
    }

    func stopTracking() {
        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        motionService.stopUpdates()
        friendService.stopListening()
    }

    private func updateUserLocation(_ location: CLLocation, userId: String) async throws {
        let userLocation = UserLocation(coordinate: location.coordinate)
        try await friendService.updateLocation(userLocation, for: userId)
    }

    /// Calculate the position of a friend on the radar view
    func friendPosition(for friend: Friend, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation,
              let coord = friend.location?.coordinate,
              let R = rotationMatrix else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let dir = GeoMath.directionVector(from: userLocation.coordinate, to: coord)
        if let pt = GeoMath.projectToScreen(
            worldDirection: dir,
            rotationMatrix: R,
            horizontalFOV: horizontalFOV,
            verticalFOV: verticalFOV,
            screenSize: size
        ) {
            return pt
        }
        // Off-screen sentinel
        return CGPoint(x: -1000, y: -1000)
    }

    /// Calculate the position of a landmark on the radar view
    func landmarkPosition(for landmark: Landmark, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation,
              let R = rotationMatrix else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let dir = GeoMath.directionVector(from: userLocation.coordinate, to: landmark.coordinate)
        if let pt = GeoMath.projectToScreen(
            worldDirection: dir,
            rotationMatrix: R,
            horizontalFOV: horizontalFOV,
            verticalFOV: verticalFOV,
            screenSize: size
        ) {
            return pt
        }
        return CGPoint(x: -1000, y: -1000)
    }

    /// Get distance to landmark formatted as string
    func landmarkDistance(for landmark: Landmark) -> String? {
        guard let userLocation = currentLocation else { return nil }
        let distance = landmark.distance(from: userLocation.coordinate)
        return AppSettings.shared.distanceUnit.format(meters: distance)
    }

    /// Compute horizon line points for the current view
    func horizonPoints(in size: CGSize) -> [CGPoint] {
        guard let R = rotationMatrix else { return [] }
        return GeoMath.horizonScreenPoints(
            rotationMatrix: R,
            horizontalFOV: horizontalFOV,
            verticalFOV: verticalFOV,
            screenSize: size
        )
    }

    /// Whether it's currently daytime (civil twilight approximation: 6 AM – 8 PM)
    var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }

    /// Build a path for the earth fill below the horizon
    func earthFillPath(in size: CGSize) -> Path {
        let horizon = horizonPoints(in: size)
        guard horizon.count >= 2 else { return Path() }
        let sorted = horizon.sorted { $0.x < $1.x }

        return Path { path in
            // Start from bottom-left, trace up to first horizon point
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: sorted.first!.x, y: sorted.first!.y))
            for pt in sorted.dropFirst() {
                path.addLine(to: pt)
            }
            // Close along bottom-right
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }

    /// Cluster overlapping landmarks based on screen positions, hiding any that overlap with friends
    func clusterLandmarks(in size: CGSize, threshold: CGFloat = 60) -> [LandmarkCluster] {
        let friendPositions = visibleFriends.map { friendPosition(for: $0, in: size) }

        // Filter out landmarks that overlap with any friend
        let visible = visibleLandmarks.filter { landmark in
            let pos = landmarkPosition(for: landmark, in: size)
            return !friendPositions.contains { friendPos in
                hypot(pos.x - friendPos.x, pos.y - friendPos.y) < threshold
            }
        }
        guard !visible.isEmpty else { return [] }

        var clusters: [LandmarkCluster] = []
        var assigned = Set<String>()

        for landmark in visible {
            if assigned.contains(landmark.id) { continue }

            let position = landmarkPosition(for: landmark, in: size)
            var clusterLandmarks = [landmark]
            assigned.insert(landmark.id)

            // Find other landmarks that overlap with this one
            for other in visible {
                if assigned.contains(other.id) { continue }
                let otherPosition = landmarkPosition(for: other, in: size)
                let distance = hypot(position.x - otherPosition.x, position.y - otherPosition.y)
                if distance < threshold {
                    clusterLandmarks.append(other)
                    assigned.insert(other.id)
                }
            }

            // Sort landmarks in cluster by distance
            if let userLocation = currentLocation {
                clusterLandmarks.sort { l1, l2 in
                    l1.distance(from: userLocation.coordinate) < l2.distance(from: userLocation.coordinate)
                }
            }

            clusters.append(LandmarkCluster(landmarks: clusterLandmarks, position: position))
        }

        return clusters
    }
}

/// Represents a cluster of landmarks at a position
struct LandmarkCluster: Identifiable {
    let landmarks: [Landmark]
    let position: CGPoint

    /// Stable ID based on landmark IDs so SwiftUI preserves state across updates
    var id: String {
        landmarks.map { $0.id }.sorted().joined(separator: "-")
    }

    var isSingle: Bool { landmarks.count == 1 }
    var first: Landmark? { landmarks.first }
}

