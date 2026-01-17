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
                    LocationPermissionView()
                } else if radarViewModel.friends.isEmpty {
                    EmptyStateView()
                } else {
                    // Friend dots
                    ForEach(radarViewModel.friends) { friend in
                        FriendDotView(
                            friend: friend,
                            userLocation: radarViewModel.currentLocation,
                            position: radarViewModel.friendPosition(for: friend, in: geometry.size)
                        )
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

struct LocationPermissionView: View {
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
