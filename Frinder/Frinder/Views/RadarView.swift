import SwiftUI
import CoreLocation
import CoreMotion

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
                        rotationMatrix: radarViewModel.rotationMatrix
                    )

                    // Landmark dots (shown behind friends) - clustered when overlapping
                    if radarViewModel.showLandmarks {
                        let clusters = radarViewModel.clusterLandmarks(in: geometry.size)
                        let clusteredFriendIds = clusters.flatMap { $0.friends.map(\.id) }

                        ForEach(clusters) { cluster in
                            if cluster.isSingle, let landmark = cluster.first {
                                LandmarkDotView(
                                    landmark: landmark,
                                    distance: radarViewModel.landmarkDistance(for: landmark),
                                    position: cluster.position
                                )
                            } else {
                                LandmarkClusterView(
                                    cluster: cluster,
                                    getDistance: { radarViewModel.landmarkDistance(for: $0) },
                                    getFriendDistance: { friend in
                                        guard let userLocation = radarViewModel.currentLocation,
                                              let distance = friend.distance(from: userLocation) else { return nil }
                                        return settings.distanceUnit.format(meters: distance)
                                    },
                                    screenSize: geometry.size,
                                    expandedClusterId: $expandedClusterId
                                )
                            }
                        }

                        // Friend dots - skip friends that are part of mixed clusters
                        ForEach(radarViewModel.visibleFriends) { friend in
                            if !clusteredFriendIds.contains(friend.id) {
                                FriendDotView(
                                    friend: friend,
                                    userLocation: radarViewModel.currentLocation,
                                    position: radarViewModel.friendPosition(for: friend, in: geometry.size)
                                )
                            }
                        }
                    } else {
                        // Friend dots - all visible when landmarks are off
                        ForEach(radarViewModel.visibleFriends) { friend in
                            FriendDotView(
                                friend: friend,
                                userLocation: radarViewModel.currentLocation,
                                position: radarViewModel.friendPosition(for: friend, in: geometry.size)
                            )
                        }
                    }

                    // Empty state only if no friends AND landmarks are hidden
                    if radarViewModel.friends.isEmpty && !radarViewModel.showLandmarks {
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
                            angle: radarViewModel.arrowAngle() ?? 0
                        ) {
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
                        .padding(.top, 60)
                    Spacer()
                }
            }
        }
    }
}

struct FriendDotView: View {
    let friend: Friend
    let userLocation: CLLocation?
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

            // Distance
            if let userLocation = userLocation,
               let distance = friend.distance(from: userLocation) {
                Text(settings.distanceUnit.format(meters: distance))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
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
                    endRadius: 22
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .blue.opacity(0.5), radius: 8)
    }
}

struct LandmarkDotView: View {
    let landmark: Landmark
    let distance: String?
    let position: CGPoint

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

            // Distance
            if let distance = distance {
                Text(distance)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.4))
        )
        .position(position)
        .animation(.easeOut(duration: 0.1), value: position.x)
        .animation(.easeOut(duration: 0.1), value: position.y)
    }
}

struct LandmarkClusterView: View {
    let cluster: LandmarkCluster
    let getDistance: (Landmark) -> String?
    let getFriendDistance: (Friend) -> String?
    let screenSize: CGSize
    @Binding var expandedClusterId: String?

    private var isExpanded: Bool { expandedClusterId == cluster.id }

    private var isOffScreen: Bool {
        let margin: CGFloat = 50
        return cluster.position.x < -margin ||
               cluster.position.x > screenSize.width + margin ||
               cluster.position.y < -margin ||
               cluster.position.y > screenSize.height + margin
    }

    var body: some View {
        VStack(spacing: 2) {
            if isExpanded && !isOffScreen {
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
                                            .foregroundStyle(.white)
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(friend.displayName)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                    if let distance = getFriendDistance(friend) {
                                        Text(distance)
                                            .font(.system(size: 8))
                                            .foregroundStyle(.white.opacity(0.6))
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
                                    if let distance = getDistance(landmark) {
                                        Text(distance)
                                            .font(.system(size: 8))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: 400)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.8))
                )
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
                        .fill(.black.opacity(0.6))
                )
            }
        }
        .onTapGesture {
            if !isOffScreen {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedClusterId = cluster.id
                }
            }
        }
        .onChange(of: isOffScreen) { _, offScreen in
            if offScreen && isExpanded {
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
    var sunPosition: CGPoint? = nil
    var moonPosition: CGPoint? = nil
    var moonImageName: String? = nil
    var rotationMatrix: CMRotationMatrix? = nil

    private static let horizontalFOV: Double = 60.0
    private static let verticalFOV: Double = 90.0

    private static let starImageNames = ["star1", "star2", "star3", "star4", "star5"]
    private static let cloudImageNames = ["cloud1", "cloud2", "cloud3", "cloud4", "cloud5"]

    /// Fixed star world directions + visual properties
    private static let stars: [(dir: (x: Double, y: Double, z: Double), imageIndex: Int, scale: Double, opacity: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 42)
        return (0..<80).map { _ in
            let az = Double.random(in: 0...(2 * .pi), using: &rng)
            let el = Double.random(in: 0.1...1.2, using: &rng)
            let cosE = cos(el)
            let dir = (x: cosE * cos(az), y: -cosE * sin(az), z: sin(el))
            return (
                dir: dir,
                imageIndex: Int.random(in: 0..<5, using: &rng),
                scale: Double.random(in: 0.04...0.08, using: &rng),
                opacity: Double.random(in: 0.5...0.9, using: &rng)
            )
        }
    }()

    /// Fixed cloud world directions + visual properties (45 clouds, upper hemisphere)
    private static let clouds: [(dir: (x: Double, y: Double, z: Double), imageIndex: Int, scale: Double, opacity: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 99)
        return (0..<20).map { _ in
            let az = Double.random(in: 0...(2 * .pi), using: &rng)
            let el = Double.random(in: 0.1...1.3, using: &rng)
            let cosE = cos(el)
            let dir = (x: cosE * cos(az), y: -cosE * sin(az), z: sin(el))
            return (
                dir: dir,
                imageIndex: Int.random(in: 0..<5, using: &rng),
                scale: Double.random(in: 0.08...0.16, using: &rng),
                opacity: 1.0
            )
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
            // Earth fill (#32a852) — determine earth region by projecting
            // a point just below the horizon and checking which screen half it lands in
            let earthColor = Color(red: 50.0/255, green: 168.0/255, blue: 82.0/255).opacity(0.25)

            if let R = rotationMatrix {
                // Skip earth fill when looking steeply up — horizon forms a ring and the
                // left-to-right path logic incorrectly fills the sky region with earth color
                let lookUp = -R.m33

                // Project nadir (straight down, 0,0,-1) to find which screen region is earth
                let nadirDz = R.m31 * 0 + R.m32 * 0 + R.m33 * (-1)
                let nadirVisible = nadirDz < 0

                if lookUp < 0.5, horizonPoints.count >= 10 {
                    // Enough horizon points for a reliable path
                    let sorted = horizonPoints.sorted { $0.x < $1.x }
                    let avgHorizonY = sorted.map(\.y).reduce(0, +) / CGFloat(sorted.count)

                    // Determine if earth is below or above the horizon on screen
                    // by checking where the nadir projects relative to the horizon
                    let earthBelow: Bool
                    if nadirVisible {
                        let nadirDx = R.m11 * 0 + R.m12 * 0 + R.m13 * (-1)
                        let nadirDy = R.m21 * 0 + R.m22 * 0 + R.m23 * (-1)
                        let nadirAngleY = atan2(nadirDy, -nadirDz)
                        let vFOVRad = Self.verticalFOV.toRadians()
                        let nadirPy = size.height / 2 - CGFloat(nadirAngleY / (vFOVRad / 2)) * size.height / 2
                        earthBelow = nadirPy > avgHorizonY
                    } else {
                        // Nadir not visible — earth is on the far side (behind device)
                        // Check: if looking up, earth is below horizon on screen
                        earthBelow = R.m33 < 0  // device z-axis z-component < 0 means looking up
                    }

                    var earthPath = Path()
                    if earthBelow {
                        earthPath.move(to: CGPoint(x: 0, y: size.height))
                        earthPath.addLine(to: CGPoint(x: sorted.first!.x, y: sorted.first!.y))
                        for pt in sorted.dropFirst() { earthPath.addLine(to: pt) }
                        earthPath.addLine(to: CGPoint(x: size.width, y: size.height))
                    } else {
                        earthPath.move(to: CGPoint(x: 0, y: 0))
                        earthPath.addLine(to: CGPoint(x: sorted.first!.x, y: sorted.first!.y))
                        for pt in sorted.dropFirst() { earthPath.addLine(to: pt) }
                        earthPath.addLine(to: CGPoint(x: size.width, y: 0))
                    }
                    earthPath.closeSubpath()
                    context.fill(earthPath, with: .color(earthColor))
                } else {
                    // No reliable horizon — fill entire screen if looking at ground
                    // Nadir visible means we can see the ground
                    if nadirVisible {
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
                        screenSize: size
                    ) else { continue }
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
                        screenSize: size
                    ) else { continue }
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

            // Horizon stroke line
            if horizonPoints.count >= 2 {
                let sorted = horizonPoints.sorted { $0.x < $1.x }
                var line = Path()
                line.move(to: sorted[0])
                for pt in sorted.dropFirst() {
                    line.addLine(to: pt)
                }
                context.stroke(line, with: .color(.white.opacity(0.3)), lineWidth: 1)
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
                .fill(.black.opacity(0.6))
        )
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
