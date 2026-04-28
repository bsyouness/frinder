import CoreLocation
import MapKit
import SwiftUI

struct FriendsMapView: View {
    @EnvironmentObject var radarViewModel: RadarViewModel
    @Binding var focusedFriendID: String?
    let focusRequestID: UUID
    var onShowInRadar: ((Friend) -> Void)? = nil

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasInitializedCamera = false
    @State private var visibleRegion: MKCoordinateRegion?
    private let clusterScreenDistance: CGFloat = 44

    private var friendsWithLocation: [Friend] {
        radarViewModel.friends.filter { $0.location != nil }
    }

    private var selectedFriend: Friend? {
        guard let focusedFriendID else { return nil }
        return friendsWithLocation.first { $0.id == focusedFriendID }
    }

    private var hasMapContent: Bool {
        radarViewModel.currentLocation != nil || !friendsWithLocation.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if radarViewModel.currentLocation == nil && friendsWithLocation.isEmpty {
                    ContentUnavailableView(
                        "Map Unavailable",
                        systemImage: "map",
                        description: Text("Location data will appear here once you or your friends have active positions.")
                    )
                } else {
                    ZStack(alignment: .bottom) {
                        GeometryReader { geometry in
                            let friendClusters = clusters(for: geometry.size)

                            Map(position: $cameraPosition, selection: $focusedFriendID) {
                                if let currentLocation = radarViewModel.currentLocation {
                                    Annotation("You", coordinate: currentLocation.coordinate) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 18, height: 18)
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                }

                                ForEach(friendClusters) { cluster in
                                    if cluster.friends.count == 1, let friend = cluster.friends.first {
                                        Marker(friend.displayName, coordinate: cluster.coordinate)
                                            .tint(focusedFriendID == friend.id ? .blue : .red)
                                            .tag(friend.id)
                                    } else {
                                        Annotation("", coordinate: cluster.coordinate) {
                                            Button {
                                                focusedFriendID = nil
                                                cameraPosition = .region(region(for: cluster.friends.compactMap { $0.location?.coordinate }))
                                            } label: {
                                                FriendClusterBubble(count: cluster.friends.count)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .mapStyle(.standard(elevation: .realistic))
                            .mapControls {
                                MapCompass()
                                MapScaleView()
                                MapUserLocationButton()
                            }
                            .onMapCameraChange(frequency: .continuous) { context in
                                visibleRegion = context.region
                            }
                        }

                        if let selectedFriend {
                            FriendMapDetailCard(
                                friend: selectedFriend,
                                locationLabel: radarViewModel.friendLocationLabel(for: selectedFriend.id),
                                userLocation: radarViewModel.currentLocation,
                                onShowInRadar: {
                                    onShowInRadar?(selectedFriend)
                                },
                                onClearSelection: {
                                    focusedFriendID = nil
                                }
                            )
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Map")
        }
        .onAppear {
            if hasMapContent, !hasInitializedCamera {
                updateCamera()
                hasInitializedCamera = true
            }
        }
        .onChange(of: focusedFriendID) { _, _ in
            updateCamera()
        }
        .onChange(of: focusRequestID) { _, _ in
            updateCamera()
        }
        .onChange(of: hasMapContent) { _, hasContent in
            if hasContent, !hasInitializedCamera {
                updateCamera()
                hasInitializedCamera = true
            }
        }
    }

    private func clusters(for size: CGSize) -> [FriendMapCluster] {
        guard let region = visibleRegion else {
            return friendsWithLocation.compactMap { friend in
                guard let coordinate = friend.location?.coordinate else { return nil }
                return FriendMapCluster(coordinate: coordinate, friends: [friend])
            }
        }

        var clusters: [FriendScreenCluster] = []

        for friend in friendsWithLocation {
            guard let coordinate = friend.location?.coordinate,
                  let point = projectedPoint(for: coordinate, in: region, size: size) else { continue }

            if let index = clusters.firstIndex(where: { cluster in
                hypot(cluster.screenPoint.x - point.x, cluster.screenPoint.y - point.y) <= clusterScreenDistance
            }) {
                clusters[index].friends.append(friend)
                clusters[index].screenPoint.x = (clusters[index].screenPoint.x + point.x) / 2
                clusters[index].screenPoint.y = (clusters[index].screenPoint.y + point.y) / 2
            } else {
                clusters.append(FriendScreenCluster(screenPoint: point, friends: [friend]))
            }
        }

        return clusters.compactMap { cluster in
            let coordinates = cluster.friends.compactMap { $0.location?.coordinate }
            guard !coordinates.isEmpty else { return nil }
            return FriendMapCluster(
                coordinate: averageCoordinate(for: coordinates),
                friends: cluster.friends
            )
        }
    }

    private func updateCamera() {
        if let selectedFriend,
           let friendLocation = selectedFriend.location?.coordinate {
            let region = MKCoordinateRegion(
                center: friendLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            visibleRegion = region
            cameraPosition = .region(region)
            return
        }

        var coordinates = friendsWithLocation.compactMap { $0.location?.coordinate }
        if let currentLocation = radarViewModel.currentLocation?.coordinate {
            coordinates.append(currentLocation)
        }
        guard !coordinates.isEmpty else { return }
        let region = region(for: coordinates)
        visibleRegion = region
        cameraPosition = .region(region)
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latitudeDelta = max((maxLat - minLat) * 1.6, 0.03)
        let longitudeDelta = max((maxLon - minLon) * 1.6, 0.03)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func projectedPoint(
        for coordinate: CLLocationCoordinate2D,
        in region: MKCoordinateRegion,
        size: CGSize
    ) -> CGPoint? {
        let latitudeDelta = max(region.span.latitudeDelta, 0.000001)
        let longitudeDelta = max(region.span.longitudeDelta, 0.000001)

        let minLat = region.center.latitude - latitudeDelta / 2
        let maxLat = region.center.latitude + latitudeDelta / 2
        let minLon = region.center.longitude - longitudeDelta / 2
        let maxLon = region.center.longitude + longitudeDelta / 2

        guard coordinate.latitude >= minLat, coordinate.latitude <= maxLat,
              coordinate.longitude >= minLon, coordinate.longitude <= maxLon else { return nil }

        let x = ((coordinate.longitude - minLon) / longitudeDelta) * size.width
        let y = (1 - ((coordinate.latitude - minLat) / latitudeDelta)) * size.height
        return CGPoint(x: x, y: y)
    }

    private func averageCoordinate(for coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct FriendMapCluster: Identifiable {
    let coordinate: CLLocationCoordinate2D
    var friends: [Friend]

    var id: String {
        let ids = friends.map(\.id).sorted().joined(separator: ",")
        return "\(coordinate.latitude),\(coordinate.longitude)#\(ids)"
    }
}

private struct FriendScreenCluster {
    var screenPoint: CGPoint
    var friends: [Friend]
}

private struct FriendClusterBubble: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 34, height: 34)
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 34, height: 34)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

private struct FriendMapDetailCard: View {
    let friend: Friend
    let locationLabel: String?
    let userLocation: CLLocation?
    let onShowInRadar: () -> Void
    let onClearSelection: () -> Void

    @ObservedObject private var settings = AppSettings.shared

    private var distanceText: String? {
        guard let userLocation,
              let distance = friend.distance(from: userLocation) else { return nil }
        return settings.distanceUnit.format(meters: distance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.blue.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(friend.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.headline)

                    if let distanceText {
                        Text(distanceText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let locationLabel {
                        Text(locationLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onClearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Button {
                onShowInRadar()
            } label: {
                Label("See In Radar", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    FriendsMapView(focusedFriendID: .constant(nil), focusRequestID: UUID())
        .environmentObject(RadarViewModel())
}
