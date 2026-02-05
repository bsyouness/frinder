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
                    // Landmark dots (shown behind friends)
                    if radarViewModel.showLandmarks {
                        ForEach(radarViewModel.landmarks) { landmark in
                            LandmarkDotView(
                                landmark: landmark,
                                distance: radarViewModel.landmarkDistance(for: landmark),
                                position: radarViewModel.landmarkPosition(for: landmark, in: geometry.size)
                            )
                        }
                    }

                    // Friend dots
                    ForEach(radarViewModel.friends) { friend in
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

    let position: CGPoint

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
        }
        .position(position)
        .animation(.easeOut(duration: 0.1), value: position.x)
        .animation(.easeOut(duration: 0.1), value: position.y)
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
