import XCTest
import CoreLocation
@testable import Frinder

final class ClusterExpandTests: XCTestCase {

    // MARK: - Helpers

    private func makeFriend(id: String, name: String = "Test") -> Friend {
        Friend(id: id, displayName: name, avatarURL: nil, location: nil)
    }

    private func makeLandmark(id: String) -> Landmark {
        Landmark(
            id: id,
            name: id,
            icon: "📍",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            city: "City",
            country: "Country"
        )
    }

    private func makeCluster(landmarkIds: [String], friendIds: [String] = [], position: CGPoint = .zero) -> LandmarkCluster {
        LandmarkCluster(
            landmarks: landmarkIds.map { makeLandmark(id: $0) },
            position: position,
            friends: friendIds.map { makeFriend(id: $0) }
        )
    }

    // MARK: - Finding the cluster containing a target friend

    func testFindClusterContainingFriend() {
        let clusters = [
            makeCluster(landmarkIds: ["l1", "l2"], friendIds: ["f1"]),
            makeCluster(landmarkIds: ["l3", "l4"], friendIds: ["f2", "f3"]),
            makeCluster(landmarkIds: ["l5"]),
        ]

        let targetId = "f2"
        let found = clusters.first(where: { $0.friends.contains(where: { $0.id == targetId }) })

        XCTAssertNotNil(found, "Should find cluster containing friend f2")
        XCTAssertTrue(found!.friends.contains(where: { $0.id == "f2" }))
        XCTAssertTrue(found!.landmarks.contains(where: { $0.id == "l3" }))
    }

    func testFindClusterReturnsNilForUngroupedFriend() {
        let clusters = [
            makeCluster(landmarkIds: ["l1", "l2"], friendIds: ["f1"]),
            makeCluster(landmarkIds: ["l3"]),
        ]

        let targetId = "f99"
        let found = clusters.first(where: { $0.friends.contains(where: { $0.id == targetId }) })

        XCTAssertNil(found, "Should not find cluster for friend not in any cluster")
    }

    func testSingleClusterShouldNotExpand() {
        // A single-landmark cluster with no friends should not be expanded
        let cluster = makeCluster(landmarkIds: ["l1"])

        XCTAssertTrue(cluster.isSingle, "Single landmark with no friends should be isSingle")
    }

    func testMixedClusterShouldExpand() {
        // A cluster with friends should be expandable (not isSingle)
        let cluster = makeCluster(landmarkIds: ["l1"], friendIds: ["f1"])

        XCTAssertFalse(cluster.isSingle, "Cluster with friends should not be isSingle")
        XCTAssertTrue(cluster.isMixed, "Cluster with friends should be isMixed")
    }

    func testMultiLandmarkClusterShouldExpand() {
        let cluster = makeCluster(landmarkIds: ["l1", "l2"])

        XCTAssertFalse(cluster.isSingle, "Multi-landmark cluster should not be isSingle")
    }

    // MARK: - Cluster ID stability

    func testClusterIdIncludesFriendIds() {
        let cluster = makeCluster(landmarkIds: ["l1"], friendIds: ["f1", "f2"])

        XCTAssertTrue(cluster.id.contains("f1"))
        XCTAssertTrue(cluster.id.contains("f2"))
    }

    func testClusterIdDeterministic() {
        let a = makeCluster(landmarkIds: ["l2", "l1"], friendIds: ["f2", "f1"])
        let b = makeCluster(landmarkIds: ["l1", "l2"], friendIds: ["f1", "f2"])

        // IDs sort internally, so order of input shouldn't matter
        XCTAssertEqual(a.id, b.id, "Cluster ID should be stable regardless of input order")
    }
}
