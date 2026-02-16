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
    var showLandmarks: Bool { AppSettings.shared.disabledLandmarkIds.count < Landmark.allLandmarks.count }

    /// Horizontal field of view in degrees (total angle visible on screen width)
    private let horizontalFOV: Double = 60.0
    /// Vertical field of view in degrees (total angle visible on screen height)
    private let verticalFOV: Double = 90.0

    /// Get landmarks that are within the current field of view
    var visibleLandmarks: [Landmark] {
        guard let userLocation = currentLocation, let R = rotationMatrix else { return [] }
        let screenSize = CGSize(width: 400, height: 800) // reference size for visibility check
        let settings = AppSettings.shared
        return landmarks.filter { landmark in
            guard settings.isLandmarkEnabled(landmark.id) else { return false }
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

    /// Get friends that are within the current field of view
    var visibleFriends: [Friend] {
        guard let userLocation = currentLocation, let R = rotationMatrix else { return [] }
        let screenSize = CGSize(width: 400, height: 800)
        return friends.filter { friend in
            guard let location = friend.location else { return false }
            let dir = GeoMath.directionVector(from: userLocation.coordinate, to: location.coordinate)
            return GeoMath.projectToScreen(
                worldDirection: dir,
                rotationMatrix: R,
                horizontalFOV: horizontalFOV,
                verticalFOV: verticalFOV,
                screenSize: screenSize
            ) != nil
        }
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

    /// Whether it's currently daytime based on real solar position
    var isDaytime: Bool {
        if let loc = currentLocation {
            return SolarPosition.isDaytime(date: Date(), latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }

    /// Current sun elevation in degrees above horizon
    var sunElevation: Double {
        guard let loc = currentLocation else { return 0 }
        return SolarPosition.sunPosition(date: Date(), latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude).elevation
    }

    /// Calculate the sun's screen position
    func sunScreenPosition(in size: CGSize) -> CGPoint? {
        guard let loc = currentLocation, let R = rotationMatrix else { return nil }
        let pos = SolarPosition.sunPosition(date: Date(), latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        let azRad = pos.azimuth.toRadians()
        let elRad = pos.elevation.toRadians()
        let cosE = cos(elRad)
        let worldDir = (x: cosE * cos(azRad), y: -cosE * sin(azRad), z: sin(elRad))
        return GeoMath.projectToScreen(
            worldDirection: worldDir,
            rotationMatrix: R,
            horizontalFOV: horizontalFOV,
            verticalFOV: verticalFOV,
            screenSize: size
        )
    }

    /// Current moon phase image name (nil during new moon)
    var moonImageName: String? {
        LunarPosition.moonPhaseImageName(date: Date())
    }

    /// Calculate the moon's screen position
    func moonScreenPosition(in size: CGSize) -> CGPoint? {
        guard let loc = currentLocation, let R = rotationMatrix else { return nil }
        let pos = LunarPosition.moonPosition(date: Date(), latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        let azRad = pos.azimuth.toRadians()
        let elRad = pos.elevation.toRadians()
        let cosE = cos(elRad)
        let worldDir = (x: cosE * cos(azRad), y: -cosE * sin(azRad), z: sin(elRad))
        return GeoMath.projectToScreen(
            worldDirection: worldDir,
            rotationMatrix: R,
            horizontalFOV: horizontalFOV,
            verticalFOV: verticalFOV,
            screenSize: size
        )
    }

    /// Whether the zenith (straight up) is visible on screen — used to determine sky/earth orientation
    /// Build a path for the earth fill below the horizon line on screen
    func earthFillPath(in size: CGSize) -> Path {
        let horizon = horizonPoints(in: size)
        guard horizon.count >= 2 else { return Path() }
        let sorted = horizon.sorted { $0.x < $1.x }

        return Path { path in
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: sorted.first!.x, y: sorted.first!.y))
            for pt in sorted.dropFirst() { path.addLine(to: pt) }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }

    /// Cluster overlapping landmarks based on screen positions, merging nearby friends into mixed clusters
    func clusterLandmarks(in size: CGSize, threshold: CGFloat = 60) -> [LandmarkCluster] {
        let visible = visibleLandmarks
        guard !visible.isEmpty else { return [] }

        let friendsWithPositions = visibleFriends.map { ($0, friendPosition(for: $0, in: size)) }

        var clusters: [LandmarkCluster] = []
        var assignedLandmarks = Set<String>()
        var assignedFriends = Set<String>()

        for landmark in visible {
            if assignedLandmarks.contains(landmark.id) { continue }

            let position = landmarkPosition(for: landmark, in: size)
            var clusterLandmarkList = [landmark]
            assignedLandmarks.insert(landmark.id)

            // Find other landmarks that overlap with this one
            for other in visible {
                if assignedLandmarks.contains(other.id) { continue }
                let otherPosition = landmarkPosition(for: other, in: size)
                let distance = hypot(position.x - otherPosition.x, position.y - otherPosition.y)
                if distance < threshold {
                    clusterLandmarkList.append(other)
                    assignedLandmarks.insert(other.id)
                }
            }

            // Find friends that overlap with this cluster
            var clusterFriends: [Friend] = []
            for (friend, friendPos) in friendsWithPositions {
                if assignedFriends.contains(friend.id) { continue }
                let distance = hypot(position.x - friendPos.x, position.y - friendPos.y)
                if distance < threshold {
                    clusterFriends.append(friend)
                    assignedFriends.insert(friend.id)
                }
            }

            // Sort landmarks in cluster by distance
            if let userLocation = currentLocation {
                clusterLandmarkList.sort { l1, l2 in
                    l1.distance(from: userLocation.coordinate) < l2.distance(from: userLocation.coordinate)
                }
            }

            clusters.append(LandmarkCluster(landmarks: clusterLandmarkList, position: position, friends: clusterFriends))
        }

        return clusters
    }

    /// Set of friend IDs that are part of mixed clusters (used to skip individual rendering)
    func friendsInClusters(in size: CGSize) -> Set<String> {
        let clusters = clusterLandmarks(in: size)
        var ids = Set<String>()
        for cluster in clusters {
            for friend in cluster.friends {
                ids.insert(friend.id)
            }
        }
        return ids
    }
}

/// Represents a cluster of landmarks (and optionally friends) at a position
struct LandmarkCluster: Identifiable {
    let landmarks: [Landmark]
    var friends: [Friend]
    let position: CGPoint

    init(landmarks: [Landmark], position: CGPoint, friends: [Friend] = []) {
        self.landmarks = landmarks
        self.friends = friends
        self.position = position
    }

    /// Stable ID based on landmark IDs so SwiftUI preserves state across updates
    var id: String {
        let landmarkIds = landmarks.map { $0.id }.sorted().joined(separator: "-")
        let friendIds = friends.map { $0.id }.sorted().joined(separator: "-")
        return landmarkIds + (friendIds.isEmpty ? "" : "+" + friendIds)
    }

    var isSingle: Bool { landmarks.count == 1 && friends.isEmpty }
    var first: Landmark? { landmarks.first }
    var isMixed: Bool { !friends.isEmpty }
    var totalCount: Int { landmarks.count + friends.count }
}

