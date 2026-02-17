import CoreLocation
import CoreMotion
import SwiftUI

struct RadarView: View {
    @EnvironmentObject var radarViewModel: RadarViewModel
    @ObservedObject var settings = AppSettings.shared
    @State private var expandedClusterId: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background: sky color (day) or black (night)
                (radarViewModel.isDaytime ? Color(red: 0.55, green: 0.75, blue: 0.95) : Color.black)
                    .ignoresSafeArea()

                if !radarViewModel.isLocationAuthorized {
                    if radarViewModel.locationAuthorizationStatus == .notDetermined {
                        PrePermissionView(onRequestPermission: {
                            radarViewModel.requestLocationAuthorization()
                        })
                    } else {
                        LocationDeniedView()
                    }
                } else {
                    // Earth visualization with horizon
                    EarthView(
                        horizonPoints: radarViewModel.horizonPoints(in: geometry.size),
                        isDaytime: radarViewModel.isDaytime,
                        screenSize: geometry.size,
                        sunPosition: radarViewModel.sunScreenPosition(in: geometry.size),
                        moonPosition: radarViewModel.moonScreenPosition(in: geometry.size),
                        moonImageName: radarViewModel.moonImageName,
                        rotationMatrix: radarViewModel.rotationMatrix)

                    // Landmark dots (shown behind friends) - clustered when overlapping
                    if radarViewModel.showLandmarks {
                        let clusters = radarViewModel.clusterLandmarks(in: geometry.size)
                        let clusteredFriendIds = clusters.flatMap { $0.friends.map(\.id) }

                        ForEach(clusters) { cluster in
                            if cluster.isSingle, let landmark = cluster.first {
                                LandmarkDotView(
                                    landmark: landmark,
                                    distance: radarViewModel.landmarkDistance(for: landmark),
                                    position: cluster.position)
                            } else {
                                LandmarkClusterView(
                                    cluster: cluster,
                                    getDistance: { radarViewModel.landmarkDistance(for: $0) },
                                    getFriendDistance: { friend in
                                        guard let userLocation = radarViewModel.currentLocation,
                                              let distance = friend.distance(from: userLocation) else { return nil }
                                        return settings.distanceUnit.format(meters: distance)
                                    },
                                    getFriendLocation: { radarViewModel.friendLocationLabel(for: $0.id) },
                                    screenSize: geometry.size,
                                    expandedClusterId: $expandedClusterId)
                                .zIndex(expandedClusterId == cluster.id ? 1 : 0)
                            }
                        }

                        // Friend dots - skip friends that are part of mixed clusters
                        ForEach(radarViewModel.visibleFriends) { friend in
                            if !clusteredFriendIds.contains(friend.id) {
                                FriendDotView(
                                    friend: friend,
                                    userLocation: radarViewModel.currentLocation,
                                    locationLabel: radarViewModel.friendLocationLabel(for: friend.id),
                                    position: radarViewModel.friendPosition(for: friend, in: geometry.size))
                            }
                        }
                    } else {
                        // Friend dots - all visible when landmarks are off
                        ForEach(radarViewModel.visibleFriends) { friend in
                            FriendDotView(
                                friend: friend,
                                userLocation: radarViewModel.currentLocation,
                                locationLabel: radarViewModel.friendLocationLabel(for: friend.id),
                                position: radarViewModel.friendPosition(for: friend, in: geometry.size))
                        }
                    }

                    // Empty state only if no friends AND landmarks are hidden
                    if radarViewModel.friends.isEmpty, !radarViewModel.showLandmarks {
                        EmptyStateView()
                    }

                    // Tap-away overlay to dismiss expanded clusters
                    if expandedClusterId != nil {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedClusterId = nil
                                }
                            }
                    }
                }

                // Navigation arrow overlay
                if let target = radarViewModel.targetFriend {
                    let pos = radarViewModel.friendPosition(for: target, in: geometry.size)
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let dist = hypot(pos.x - center.x, pos.y - center.y)

                    if dist > 150 || pos.x < 0 {
                        NavigationArrowView(
                            friendName: target.displayName,
                            angle: radarViewModel.arrowAngle() ?? 0)
                        {
                            radarViewModel.targetFriend = nil
                        }
                    } else {
                        // Friend is near center — auto-clear
                        Color.clear.onAppear {
                            radarViewModel.targetFriend = nil
                        }
                    }
                }

                // Compass indicator at top
                VStack {
                    CompassIndicator(heading: radarViewModel.deviceHeading)
                        .padding(.top, geometry.safeAreaInsets.top + 12)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct FriendDotView: View {
    let friend: Friend
    let userLocation: CLLocation?
    let locationLabel: String?
    @ObservedObject var settings = AppSettings.shared
    @State private var showLastSeen = false

    let position: CGPoint

    private func lastSeenText() -> String? {
        guard let timestamp = friend.location?.timestamp else { return nil }
        let age = Date().timeIntervalSince(timestamp)
        if age < 60 { return "Updated just now" }
        let minutes = Int(age / 60)
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours)h ago" }
        let days = hours / 24
        return "Updated \(days)d ago"
    }

    var body: some View {
        VStack(spacing: 4) {
            // Avatar or default dot
            if let avatarURL = friend.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    DefaultAvatarView()
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                DefaultAvatarView()
            }

            // Name
            Text(friend.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            if settings.showDistanceAndLocation {
                // Distance
                if let userLocation,
                   let distance = friend.distance(from: userLocation)
                {
                    Text(settings.distanceUnit.format(meters: distance))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Location
                if let locationLabel {
                    Text(locationLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            // Last seen (shown on tap)
            if showLastSeen, let text = lastSeenText() {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation { showLastSeen.toggle() }
        }
        .position(position)
        .animation(.easeOut(duration: 0.5), value: position.x)
        .animation(.easeOut(duration: 0.5), value: position.y)
    }
}

struct DefaultAvatarView: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.blue, .blue.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 22))
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 2))
            .shadow(color: .blue.opacity(0.5), radius: 8)
    }
}

struct LandmarkDotView: View {
    let landmark: Landmark
    let distance: String?
    let position: CGPoint
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 2) {
            // Landmark icon
            Text(landmark.icon)
                .font(.system(size: 28))
                .shadow(color: .black.opacity(0.5), radius: 2)

            // Name
            Text(landmark.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            if settings.showDistanceAndLocation {
                // Distance
                if let distance {
                    Text(distance)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Location
                Text(landmark.locationLabel)
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.4)))
        .position(position)
        .animation(.easeOut(duration: 0.1), value: position.x)
        .animation(.easeOut(duration: 0.1), value: position.y)
    }
}

struct LandmarkClusterView: View {
    let cluster: LandmarkCluster
    let getDistance: (Landmark) -> String?
    let getFriendDistance: (Friend) -> String?
    let getFriendLocation: (Friend) -> String?
    let screenSize: CGSize
    @ObservedObject var settings = AppSettings.shared
    @Binding var expandedClusterId: String?

    private var isExpanded: Bool {
        expandedClusterId == cluster.id
    }

    private var isOffScreen: Bool {
        let margin: CGFloat = 50
        return cluster.position.x < -margin ||
            cluster.position.x > screenSize.width + margin ||
            cluster.position.y < -margin ||
            cluster.position.y > screenSize.height + margin
    }

    private let singleElementHeight: CGFloat = 25
    private let maxElementsForList: CGFloat = 10
    var body: some View {
        VStack(spacing: 2) {
            if isExpanded, !isOffScreen {
                // Expanded list of friends + landmarks
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        // Friends first (blue accent)
                        ForEach(cluster.friends) { friend in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.white))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(friend.displayName)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                    if settings.showDistanceAndLocation {
                                        if let distance = getFriendDistance(friend) {
                                            Text(distance)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        if let location = getFriendLocation(friend) {
                                            Text(location)
                                                .font(.system(size: 7))
                                                .foregroundStyle(.white.opacity(0.5))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }

                        // Landmarks (red accent)
                        ForEach(cluster.landmarks) { landmark in
                            HStack(spacing: 6) {
                                Text(landmark.icon)
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(landmark.name)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(1)
                                    if settings.showDistanceAndLocation {
                                        if let distance = getDistance(landmark) {
                                            Text(distance)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        Text(landmark.locationLabel)
                                            .font(.system(size: 7))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: min(
                    CGFloat(cluster.totalCount) * singleElementHeight,
                    singleElementHeight * maxElementsForList))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.8)))
                .frame(width: 160)
            } else {
                // Collapsed cluster icon with badges
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)

                    // Friend count badge (blue)
                    if !cluster.friends.isEmpty {
                        Text("\(cluster.friends.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.blue))
                            .offset(x: -12, y: -12)
                    }

                    // Landmark count badge (red)
                    Text("\(cluster.landmarks.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(.red))
                        .offset(x: 12, y: -12)
                }
                .padding(8)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.6)))
            }
        }
        .onTapGesture {
            if !isOffScreen {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedClusterId = isExpanded ? nil : cluster.id
                }
            }
        }
        .onChange(of: isOffScreen) { _, offScreen in
            if offScreen, isExpanded {
                expandedClusterId = nil
            }
        }
        .position(cluster.position)
        .animation(.easeOut(duration: 0.1), value: cluster.position.x)
        .animation(.easeOut(duration: 0.1), value: cluster.position.y)
    }
}

struct EarthView: View {
    let horizonPoints: [CGPoint]
    let isDaytime: Bool
    let screenSize: CGSize
    var sunPosition: CGPoint?
    var moonPosition: CGPoint?
    var moonImageName: String?
    var rotationMatrix: CMRotationMatrix?

    private static let horizontalFOV: Double = 60.0
    private static let verticalFOV: Double = 90.0

    private static let starImageNames = ["star1", "star2", "star3", "star4", "star5"]
    private static let cloudImageNames = ["cloud1", "cloud2", "cloud3", "cloud4", "cloud5"]

    /// Fixed star world directions + visual properties
    private static let stars: [(
        dir: (x: Double, y: Double, z: Double),
        imageIndex: Int,
        scale: Double,
        opacity: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 42)
        return (0 ..< 80).map { _ in
            let az = Double.random(in: 0 ... (2 * .pi), using: &rng)
            let el = Double.random(in: 0.1 ... 1.2, using: &rng)
            let cosE = cos(el)
            let dir = (x: cosE * cos(az), y: -cosE * sin(az), z: sin(el))
            return (
                dir: dir,
                imageIndex: Int.random(in: 0 ..< 5, using: &rng),
                scale: Double.random(in: 0.04 ... 0.08, using: &rng),
                opacity: Double.random(in: 0.5 ... 0.9, using: &rng))
        }
    }()

    /// Fixed cloud world directions + visual properties (45 clouds, upper hemisphere)
    private static let clouds: [(
        dir: (x: Double, y: Double, z: Double),
        imageIndex: Int,
        scale: Double,
        opacity: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 99)
        return (0 ..< 20).map { _ in
            let az = Double.random(in: 0 ... (2 * .pi), using: &rng)
            let el = Double.random(in: 0.1 ... 1.3, using: &rng)
            let cosE = cos(el)
            let dir = (x: cosE * cos(az), y: -cosE * sin(az), z: sin(el))
            return (
                dir: dir,
                imageIndex: Int.random(in: 0 ..< 5, using: &rng),
                scale: Double.random(in: 0.08 ... 0.16, using: &rng),
                opacity: 1.0)
        }
    }()

    /// Device roll angle from the rotation matrix (0 when upright)
    private static func deviceRoll(from R: CMRotationMatrix) -> Double {
        // Gravity in world NWU is (0, 0, -1). Transform to device frame:
        let gx = -R.m13
        let gy = -R.m23
        return atan2(gx, -gy)
    }

    var body: some View {
        Canvas { context, size in
            // --- Earth fill (robust): clip screen rect by horizon half-space ---
            let earthColor = Color(red: 50.0 / 255, green: 168.0 / 255, blue: 82.0 / 255).opacity(0.25)

            if let R = rotationMatrix {
                let halfW = size.width / 2
                let halfH = size.height / 2
                let hFOVRad = Self.horizontalFOV.toRadians()
                let vFOVRad = Self.verticalFOV.toRadians()

                func rayWorldZ(at p: CGPoint) -> Double {
                    // Screen -> angular offsets (matches your existing angular projection)
                    let nx = Double((p.x - halfW) / halfW) // -1..1
                    let ny = Double((halfH - p.y) / halfH) // -1..1 (up positive)

                    let ax = nx * (hFOVRad / 2)
                    let ay = ny * (vFOVRad / 2)

                    // Build a camera/device ray: forward is -Z
                    var dx = tan(ax)
                    var dy = tan(ay)
                    var dz = -1.0

                    // Normalize in device space
                    let len = sqrt(dx * dx + dy * dy + dz * dz)
                    dx /= len
                    dy /= len
                    dz /= len

                    // Device -> World using transpose (since R maps world -> device)
                    let wx = R.m11 * dx + R.m21 * dy + R.m31 * dz
                    let wy = R.m12 * dx + R.m22 * dy + R.m32 * dz
                    let wz = R.m13 * dx + R.m23 * dy + R.m33 * dz

                    // In your world model, z>0 is up (stars have positive z), so earth is z<0
                    _ = wx
                    _ = wy
                    return wz
                }

                func isEarth(_ p: CGPoint) -> Bool {
                    rayWorldZ(at: p) < 0
                }

                func edgeCrossing(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
                    // Binary search for wz==0 along the edge
                    var lo = a
                    var hi = b
                    let sLo = rayWorldZ(at: lo)

                    for _ in 0 ..< 22 {
                        let mid = CGPoint(x: (lo.x + hi.x) / 2, y: (lo.y + hi.y) / 2)
                        let sMid = rayWorldZ(at: mid)
                        if (sMid >= 0) == (sLo >= 0) {
                            lo = mid
                        } else {
                            hi = mid
                        }
                    }
                    return CGPoint(x: (lo.x + hi.x) / 2, y: (lo.y + hi.y) / 2)
                }

                // Screen corners in clockwise order
                let corners: [CGPoint] = [
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: size.width, y: 0),
                    CGPoint(x: size.width, y: size.height),
                    CGPoint(x: 0, y: size.height),
                ]

                var poly: [CGPoint] = []
                for i in 0 ..< 4 {
                    let a = corners[i]
                    let b = corners[(i + 1) % 4]
                    let aEarth = isEarth(a)
                    let bEarth = isEarth(b)

                    if aEarth { poly.append(a) }

                    if aEarth != bEarth {
                        poly.append(edgeCrossing(a, b))
                    }
                }

                if poly.count >= 3 {
                    var earthPath = Path()
                    earthPath.move(to: poly[0])
                    for p in poly.dropFirst() {
                        earthPath.addLine(to: p)
                    }
                    earthPath.closeSubpath()
                    context.fill(earthPath, with: .color(earthColor))
                } else {
                    // Either all sky or all earth — fill accordingly
                    if isEarth(CGPoint(x: halfW, y: halfH)) {
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(earthColor))
                    }
                }
            }

            // Stars (night only, world-projected)
            if !isDaytime, let R = rotationMatrix {
                let resolvedStars = Self.starImageNames.map { context.resolve(Image($0)) }
                for star in Self.stars {
                    guard let pt = GeoMath.projectToScreen(
                        worldDirection: star.dir,
                        rotationMatrix: R,
                        horizontalFOV: Self.horizontalFOV,
                        verticalFOV: Self.verticalFOV,
                        screenSize: size) else { continue }
                    let img = resolvedStars[star.imageIndex]
                    let w = img.size.width * star.scale
                    let h = img.size.height * star.scale
                    let rect = CGRect(x: pt.x - w / 2, y: pt.y - h / 2, width: w, height: h)
                    context.opacity = star.opacity
                    context.draw(img, in: rect)
                    context.opacity = 1
                }
            }

            // Moon (world-projected image, ~120pt)
            if let mp = moonPosition, let moonName = moonImageName {
                let resolvedMoon = context.resolve(Image(moonName))
                let moonSize: CGFloat = 120
                let aspect = resolvedMoon.size.width / max(resolvedMoon.size.height, 1)
                let w = moonSize * aspect
                let h = moonSize
                let rect = CGRect(x: mp.x - w / 2, y: mp.y - h / 2, width: w, height: h)
                context.draw(resolvedMoon, in: rect)
            }

            // Sun (world-projected image, 180pt — drawn behind clouds)
            if let sp = sunPosition {
                let resolvedSun = context.resolve(Image("sun"))
                let sunSize: CGFloat = 180
                let aspect = resolvedSun.size.width / max(resolvedSun.size.height, 1)
                let w = sunSize * aspect
                let h = sunSize
                let rect = CGRect(x: sp.x - w / 2, y: sp.y - h / 2, width: w, height: h)
                context.draw(resolvedSun, in: rect)
            }

            // Clouds (day only, world-projected, skip any that overlap the sun)
            if isDaytime, let R = rotationMatrix {
                let roll = Self.deviceRoll(from: R)
                let resolvedClouds = Self.cloudImageNames.map { context.resolve(Image($0)) }
                for cloud in Self.clouds {
                    guard let pt = GeoMath.projectToScreen(
                        worldDirection: cloud.dir,
                        rotationMatrix: R,
                        horizontalFOV: Self.horizontalFOV,
                        verticalFOV: Self.verticalFOV,
                        screenSize: size) else { continue }
                    let img = resolvedClouds[cloud.imageIndex]
                    let w = img.size.width * cloud.scale * 3
                    let h = img.size.height * cloud.scale * 3
                    context.drawLayer { ctx in
                        ctx.translateBy(x: pt.x, y: pt.y)
                        ctx.rotate(by: Angle(radians: -roll))
                        ctx.draw(img, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                    }
                }
            }

        }
    }
}

/// Simple seeded random number generator for deterministic star positions
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

struct CompassIndicator: View {
    let heading: Double

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .rotationEffect(.degrees(-heading))

            Text(cardinalDirection)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var cardinalDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }
}

struct PrePermissionView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Find Your Friends")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                FeatureRow(icon: "dot.radiowaves.left.and.right", text: "See friends' locations on your radar")
                FeatureRow(icon: "location.north.fill", text: "Point your phone to find them")
                FeatureRow(icon: "arrow.triangle.swap", text: "Share your location with friends")
            }
            .padding(.horizontal, 24)

            Text("Frinder needs your location to show where your friends are relative to you.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRequestPermission) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Enable Location")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.gray)

            Text("Location Access Required")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Please enable location access in Settings to see your friends on the radar.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
    }
}

struct NavigationArrowView: View {
    let friendName: String
    let angle: Double
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(angle))

            Text(friendName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Button {
                onDismiss()
            } label: {
                Text("Dismiss")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.6)))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.gray)

            Text("No Friends Yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Add friends in the Friends tab to see them on your radar.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    RadarView()
        .environmentObject(RadarViewModel())
}
