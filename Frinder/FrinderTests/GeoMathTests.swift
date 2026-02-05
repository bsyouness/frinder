import XCTest
import CoreLocation
@testable import Frinder

final class GeoMathTests: XCTestCase {

    // MARK: - Test Coordinates
    // Well-known locations for testing

    let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    let tokyo = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
    let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
    let paris = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    let losAngeles = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

    // MARK: - Distance Tests

    func testDistanceNewYorkToLondon() {
        // Known distance: approximately 5,570 km
        let distance = GeoMath.distance(from: newYork, to: london)
        let distanceKm = distance / 1000.0

        XCTAssertEqual(distanceKm, 5570, accuracy: 50, "NY to London should be ~5,570 km")
    }

    func testDistanceNewYorkToLosAngeles() {
        // Known distance: approximately 3,940 km
        let distance = GeoMath.distance(from: newYork, to: losAngeles)
        let distanceKm = distance / 1000.0

        XCTAssertEqual(distanceKm, 3940, accuracy: 50, "NY to LA should be ~3,940 km")
    }

    func testDistanceToSamePoint() {
        let distance = GeoMath.distance(from: newYork, to: newYork)
        XCTAssertEqual(distance, 0, accuracy: 0.1, "Distance to same point should be 0")
    }

    func testDistanceSydneyToLondon() {
        // Known distance: approximately 16,990 km (nearly opposite sides of Earth)
        let distance = GeoMath.distance(from: sydney, to: london)
        let distanceKm = distance / 1000.0

        XCTAssertEqual(distanceKm, 16990, accuracy: 100, "Sydney to London should be ~16,990 km")
    }

    // MARK: - Bearing Tests

    func testBearingNewYorkToLondon() {
        // NY to London: roughly Northeast (~51°)
        let bearing = GeoMath.bearing(from: newYork, to: london)

        XCTAssertEqual(bearing, 51, accuracy: 5, "NY to London bearing should be ~51° (NE)")
    }

    func testBearingLondonToNewYork() {
        // London to NY: roughly West-Southwest (~288°)
        let bearing = GeoMath.bearing(from: london, to: newYork)

        XCTAssertEqual(bearing, 288, accuracy: 5, "London to NY bearing should be ~288° (WSW)")
    }

    func testBearingDueNorth() {
        let southPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let northPoint = CLLocationCoordinate2D(latitude: 41.0, longitude: -74.0)

        let bearing = GeoMath.bearing(from: southPoint, to: northPoint)

        XCTAssertEqual(bearing, 0, accuracy: 1, "Due north should be 0°")
    }

    func testBearingDueEast() {
        let westPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -75.0)
        let eastPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)

        let bearing = GeoMath.bearing(from: westPoint, to: eastPoint)

        XCTAssertEqual(bearing, 90, accuracy: 1, "Due east should be 90°")
    }

    func testBearingDueSouth() {
        let northPoint = CLLocationCoordinate2D(latitude: 41.0, longitude: -74.0)
        let southPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)

        let bearing = GeoMath.bearing(from: northPoint, to: southPoint)

        XCTAssertEqual(bearing, 180, accuracy: 1, "Due south should be 180°")
    }

    func testBearingDueWest() {
        let eastPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let westPoint = CLLocationCoordinate2D(latitude: 40.0, longitude: -75.0)

        let bearing = GeoMath.bearing(from: eastPoint, to: westPoint)

        XCTAssertEqual(bearing, 270, accuracy: 1, "Due west should be 270°")
    }

    // MARK: - Normalize Angle Tests

    func testNormalizeAngleInRange() {
        XCTAssertEqual(GeoMath.normalizeAngle(45), 45, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(-45), -45, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(180), 180, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(-180), -180, accuracy: 0.001)
    }

    func testNormalizeAngleOver180() {
        XCTAssertEqual(GeoMath.normalizeAngle(270), -90, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(360), 0, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(450), 90, accuracy: 0.001)
    }

    func testNormalizeAngleUnderMinus180() {
        XCTAssertEqual(GeoMath.normalizeAngle(-270), 90, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(-360), 0, accuracy: 0.001)
        XCTAssertEqual(GeoMath.normalizeAngle(-450), -90, accuracy: 0.001)
    }

    // MARK: - Relative Bearing Tests

    func testRelativeBearingDirectlyAhead() {
        // Target at 90°, device pointing 90° -> directly ahead (0°)
        let relative = GeoMath.relativeBearing(targetBearing: 90, deviceHeading: 90)
        XCTAssertEqual(relative, 0, accuracy: 0.001)
    }

    func testRelativeBearingToTheRight() {
        // Target at 120°, device pointing 90° -> 30° to the right
        let relative = GeoMath.relativeBearing(targetBearing: 120, deviceHeading: 90)
        XCTAssertEqual(relative, 30, accuracy: 0.001)
    }

    func testRelativeBearingToTheLeft() {
        // Target at 60°, device pointing 90° -> 30° to the left
        let relative = GeoMath.relativeBearing(targetBearing: 60, deviceHeading: 90)
        XCTAssertEqual(relative, -30, accuracy: 0.001)
    }

    func testRelativeBearingBehind() {
        // Target at 270°, device pointing 90° -> 180° behind
        let relative = GeoMath.relativeBearing(targetBearing: 270, deviceHeading: 90)
        XCTAssertEqual(relative, 180, accuracy: 0.001)
    }

    func testRelativeBearingWrapAround() {
        // Target at 10°, device pointing 350° -> 20° to the right (wraps around north)
        let relative = GeoMath.relativeBearing(targetBearing: 10, deviceHeading: 350)
        XCTAssertEqual(relative, 20, accuracy: 0.001)
    }

    // MARK: - Field of View Tests

    func testIsWithinFOVCenter() {
        // Target directly ahead
        let inFOV = GeoMath.isWithinHorizontalFOV(bearing: 90, deviceHeading: 90, fieldOfView: 60)
        XCTAssertTrue(inFOV)
    }

    func testIsWithinFOVEdge() {
        // Target at edge of 60° FOV (30° from center)
        let inFOV = GeoMath.isWithinHorizontalFOV(bearing: 120, deviceHeading: 90, fieldOfView: 60)
        XCTAssertTrue(inFOV)
    }

    func testIsOutsideFOV() {
        // Target 45° from center, FOV is 60° (so max is 30°)
        let inFOV = GeoMath.isWithinHorizontalFOV(bearing: 135, deviceHeading: 90, fieldOfView: 60)
        XCTAssertFalse(inFOV)
    }

    func testIsWithinFOVWrapAround() {
        // Device pointing north (0°), target at 350° (10° to the left)
        let inFOV = GeoMath.isWithinHorizontalFOV(bearing: 350, deviceHeading: 0, fieldOfView: 60)
        XCTAssertTrue(inFOV)
    }

    // MARK: - True Elevation Angle Tests

    func testTrueElevationAngleNearby() {
        // 100 km away - should be very close to horizon
        let elevation = GeoMath.trueElevationAngle(forDistance: 100_000)
        let elevationDegrees = elevation.toDegrees()

        // Central angle = 100km / 6371km ≈ 0.0157 rad ≈ 0.9°
        // Elevation = -0.45°
        XCTAssertEqual(elevationDegrees, -0.45, accuracy: 0.1, "100km should be ~0.45° below horizon")
    }

    func testTrueElevationAngle1000km() {
        // 1000 km away
        let elevation = GeoMath.trueElevationAngle(forDistance: 1_000_000)
        let elevationDegrees = elevation.toDegrees()

        // Central angle = 1000km / 6371km ≈ 0.157 rad ≈ 9°
        // Elevation = -4.5°
        XCTAssertEqual(elevationDegrees, -4.5, accuracy: 0.5, "1000km should be ~4.5° below horizon")
    }

    func testTrueElevationAngle10000km() {
        // 10,000 km away (quarter of Earth's circumference)
        let elevation = GeoMath.trueElevationAngle(forDistance: 10_000_000)
        let elevationDegrees = elevation.toDegrees()

        // Central angle = 10000km / 6371km ≈ 1.57 rad ≈ 90°
        // Elevation = -45°
        XCTAssertEqual(elevationDegrees, -45, accuracy: 2, "10,000km should be ~45° below horizon")
    }

    func testTrueElevationAngleAntipodal() {
        // 20,000 km away (opposite side of Earth)
        let elevation = GeoMath.trueElevationAngle(forDistance: 20_000_000)
        let elevationDegrees = elevation.toDegrees()

        // Should cap at -90° (straight down)
        XCTAssertEqual(elevationDegrees, -90, accuracy: 1, "Antipodal point should be 90° below horizon")
    }

    // MARK: - Scaled Elevation Angle Tests

    func testScaledElevationAngleZeroDistance() {
        let elevation = GeoMath.scaledElevationAngle(forDistance: 0)
        XCTAssertEqual(elevation, 0, accuracy: 0.001, "Zero distance should be at horizon")
    }

    func testScaledElevationAngleMaxDistance() {
        let elevation = GeoMath.scaledElevationAngle(forDistance: 20_000_000)
        let elevationDegrees = elevation.toDegrees()

        XCTAssertEqual(elevationDegrees, -20, accuracy: 0.1, "Max distance should be -20° (default)")
    }

    func testScaledElevationAngleHalfDistance() {
        let elevation = GeoMath.scaledElevationAngle(forDistance: 10_000_000)
        let elevationDegrees = elevation.toDegrees()

        XCTAssertEqual(elevationDegrees, -10, accuracy: 0.1, "Half max distance should be -10°")
    }

    func testScaledElevationAngleBeyondMax() {
        // Beyond max distance should cap at max angle
        let elevation = GeoMath.scaledElevationAngle(forDistance: 30_000_000)
        let elevationDegrees = elevation.toDegrees()

        XCTAssertEqual(elevationDegrees, -20, accuracy: 0.1, "Beyond max should cap at -20°")
    }

    // MARK: - Screen Position Tests

    func testScreenXCenter() {
        // Target directly ahead -> center of screen
        let x = GeoMath.screenX(bearing: 90, deviceHeading: 90, horizontalFOV: 60, screenWidth: 400)
        XCTAssertEqual(x, 200, accuracy: 1, "Center target should be at screen center")
    }

    func testScreenXLeftEdge() {
        // Target at left edge of FOV (30° left of center)
        let x = GeoMath.screenX(bearing: 60, deviceHeading: 90, horizontalFOV: 60, screenWidth: 400)
        XCTAssertEqual(x, 0, accuracy: 1, "Left edge target should be at x=0")
    }

    func testScreenXRightEdge() {
        // Target at right edge of FOV (30° right of center)
        let x = GeoMath.screenX(bearing: 120, deviceHeading: 90, horizontalFOV: 60, screenWidth: 400)
        XCTAssertEqual(x, 400, accuracy: 1, "Right edge target should be at x=screenWidth")
    }

    func testScreenYHorizon() {
        // Target at horizon (0° elevation), device level (0° pitch)
        let y = GeoMath.screenY(elevation: 0, devicePitch: 0, verticalFOV: 90, screenHeight: 800)
        XCTAssertEqual(y, 400, accuracy: 1, "Horizon should be at screen center")
    }

    func testScreenYBelowHorizon() {
        // Target 20° below horizon, device level
        let elevation = -20.0.toRadians()
        let y = GeoMath.screenY(elevation: elevation, devicePitch: 0, verticalFOV: 90, screenHeight: 800)

        // -20° / 90° FOV = -0.22 from center, so Y should be > 400
        XCTAssertGreaterThan(y, 400, "Below horizon should be below screen center")
    }

    func testScreenYDeviceTiltedDown() {
        // Target at horizon, device tilted down 20° -> target appears above center
        let devicePitch = -20.0.toRadians()
        let y = GeoMath.screenY(elevation: 0, devicePitch: devicePitch, verticalFOV: 90, screenHeight: 800)

        XCTAssertLessThan(y, 400, "Tilting down should move horizon up on screen")
    }

    func testScreenYDeviceTiltedUp() {
        // Target at horizon, device tilted up 20° -> target appears below center
        let devicePitch = 20.0.toRadians()
        let y = GeoMath.screenY(elevation: 0, devicePitch: devicePitch, verticalFOV: 90, screenHeight: 800)

        XCTAssertGreaterThan(y, 400, "Tilting up should move horizon down on screen")
    }

    // MARK: - Integration Tests

    func testLandmarkPositionNewYorkToEiffelTower() {
        // From New York, looking towards Eiffel Tower
        let eiffelTower = CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)

        let bearing = GeoMath.bearing(from: newYork, to: eiffelTower)
        let distance = GeoMath.distance(from: newYork, to: eiffelTower)

        // Bearing should be roughly NE (~54°)
        XCTAssertEqual(bearing, 54, accuracy: 5)

        // Distance should be ~5,837 km
        XCTAssertEqual(distance / 1000, 5837, accuracy: 50)

        // If device is pointing at the Eiffel Tower (heading = bearing)
        let screenX = GeoMath.screenX(
            bearing: bearing,
            deviceHeading: bearing,
            horizontalFOV: 60,
            screenWidth: 400
        )
        XCTAssertEqual(screenX, 200, accuracy: 1, "Should be centered when pointing directly at target")
    }

    func testRelativePositionsOfMultipleLandmarks() {
        // From a point, two landmarks at different distances should have different elevations
        let observer = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let near = CLLocationCoordinate2D(latitude: 40.1, longitude: -74.0)  // ~11 km north
        let far = CLLocationCoordinate2D(latitude: 45.0, longitude: -74.0)   // ~555 km north

        let distanceNear = GeoMath.distance(from: observer, to: near)
        let distanceFar = GeoMath.distance(from: observer, to: far)

        let elevationNear = GeoMath.scaledElevationAngle(forDistance: distanceNear)
        let elevationFar = GeoMath.scaledElevationAngle(forDistance: distanceFar)

        // Far landmark should have more negative elevation (lower on screen)
        XCTAssertLessThan(elevationFar, elevationNear, "Farther landmark should be lower")

        // Both should be negative (below horizon)
        XCTAssertLessThan(elevationNear, 0)
        XCTAssertLessThan(elevationFar, 0)
    }
}
