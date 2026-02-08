import SwiftUI
import CoreLocation

struct RadarView: View {
    @EnvironmentObject var radarViewModel: RadarViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
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
                        earthFillPath: radarViewModel.earthFillPath(in: geometry.size),
                        isDaytime: radarViewModel.isDaytime,
                        screenSize: geometry.size
                    )

                    // Landmark dots (shown behind friends) - clustered when overlapping
                    if radarViewModel.showLandmarks {
                        let clusters = radarViewModel.clusterLandmarks(in: geometry.size)
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
                                    screenSize: geometry.size
                                )
                            }
                        }
                    }

                    // Friend dots - only visible ones
                    ForEach(radarViewModel.visibleFriends) { friend in
                        FriendDotView(
                            friend: friend,
                            userLocation: radarViewModel.currentLocation,
                            position: radarViewModel.friendPosition(for: friend, in: geometry.size)
                        )
                    }

                    // Empty state only if no friends AND landmarks are hidden
                    if radarViewModel.friends.isEmpty && !radarViewModel.showLandmarks {
                        EmptyStateView()
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
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
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
    let screenSize: CGSize
    @State private var isExpanded = false
    @State private var wasOffScreen = false

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
                // Expanded list of landmarks
                VStack(alignment: .leading, spacing: 4) {
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
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.8))
                )
                .frame(width: 140)
            } else {
                // Collapsed cluster icon
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)

                    Text("\(cluster.landmarks.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(.blue))
                        .offset(x: 12, y: -12)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.6))
                )
            }
        }
        .onTapGesture {
            if !isOffScreen {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
        .onChange(of: isOffScreen) { _, offScreen in
            if offScreen {
                // Collapse when going off screen
                isExpanded = false
                wasOffScreen = true
            }
        }
        .position(cluster.position)
        .animation(.easeOut(duration: 0.1), value: cluster.position.x)
        .animation(.easeOut(duration: 0.1), value: cluster.position.y)
    }
}

struct EarthView: View {
    let horizonPoints: [CGPoint]
    let earthFillPath: Path
    let isDaytime: Bool
    let screenSize: CGSize

    /// Fixed star positions generated with a seeded RNG (normalized 0..1 coordinates)
    private static let stars: [(x: Double, y: Double, radius: Double, opacity: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 42)
        return (0..<80).map { _ in
            (
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                radius: Double.random(in: 1...2, using: &rng),
                opacity: Double.random(in: 0.3...0.6, using: &rng)
            )
        }
    }()

    var body: some View {
        Canvas { context, size in
            // Sky fill above horizon (day only)
            if isDaytime && horizonPoints.count >= 2 {
                let sorted = horizonPoints.sorted { $0.x < $1.x }
                var skyPath = Path()
                skyPath.move(to: CGPoint(x: 0, y: 0))
                skyPath.addLine(to: CGPoint(x: size.width, y: 0))
                skyPath.addLine(to: CGPoint(x: sorted.last!.x, y: sorted.last!.y))
                for pt in sorted.reversed().dropFirst() {
                    skyPath.addLine(to: pt)
                }
                skyPath.addLine(to: CGPoint(x: 0, y: 0))
                skyPath.closeSubpath()
                context.fill(skyPath, with: .color(.blue.opacity(0.15)))
            }

            // Stars (night only)
            if !isDaytime && horizonPoints.count >= 2 {
                let sorted = horizonPoints.sorted { $0.x < $1.x }
                let avgHorizonY = sorted.map(\.y).reduce(0, +) / Double(sorted.count)

                for star in Self.stars {
                    let sx = star.x * size.width
                    let sy = star.y * size.height
                    // Only draw stars above horizon (approximate)
                    guard sy < avgHorizonY else { continue }
                    let rect = CGRect(
                        x: sx - star.radius,
                        y: sy - star.radius,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(star.opacity))
                    )
                }
            }

            // Green ground fill below horizon
            context.fill(earthFillPath, with: .color(.green.opacity(0.08)))

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
