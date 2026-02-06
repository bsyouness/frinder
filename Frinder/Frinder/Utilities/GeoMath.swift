import Foundation
import CoreLocation
import CoreMotion

/// Geographic and angular math utilities for radar positioning
enum GeoMath {
    /// Earth's radius in meters
    static let earthRadius: Double = 6_371_000.0

    /// Calculate bearing from one coordinate to another
    /// - Returns: Bearing in degrees (0-360, where 0 = North, 90 = East)
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lon1 = from.longitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let lon2 = to.longitude.toRadians()

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x).toDegrees()
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }

    /// Calculate great-circle distance between two coordinates
    /// - Returns: Distance in meters
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    /// Normalize angle to -180 to 180 range
    /// - Parameter angle: Angle in degrees
    /// - Returns: Normalized angle in degrees
    static func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > 180 { normalized -= 360 }
        while normalized < -180 { normalized += 360 }
        return normalized
    }

    /// Calculate relative bearing (angle from device heading to target)
    /// - Parameters:
    ///   - targetBearing: Absolute bearing to target (0-360 degrees)
    ///   - deviceHeading: Current device heading (0-360 degrees)
    /// - Returns: Relative angle in degrees (-180 to 180, negative = left, positive = right)
    static func relativeBearing(targetBearing: Double, deviceHeading: Double) -> Double {
        return normalizeAngle(targetBearing - deviceHeading)
    }

    /// Check if a bearing is within a horizontal field of view
    /// - Parameters:
    ///   - bearing: Absolute bearing to target (degrees)
    ///   - deviceHeading: Device heading (degrees)
    ///   - fieldOfView: Total horizontal FOV (degrees)
    /// - Returns: True if target is visible
    static func isWithinHorizontalFOV(bearing: Double, deviceHeading: Double, fieldOfView: Double) -> Bool {
        let relativeAngle = relativeBearing(targetBearing: bearing, deviceHeading: deviceHeading)
        return abs(relativeAngle) <= fieldOfView / 2.0
    }

    /// Calculate the true elevation angle for a straight-line path through Earth
    /// - Parameter distance: Great-circle distance in meters
    /// - Returns: Elevation angle in radians (negative = below horizon)
    static func trueElevationAngle(forDistance distance: Double) -> Double {
        // Central angle on Earth's surface
        let centralAngle = distance / earthRadius
        // For a chord through Earth, elevation is half the central angle below horizontal
        return -min(centralAngle / 2.0, .pi / 2.0)
    }

    /// Calculate a scaled elevation angle for display purposes
    /// Maps distance to a manageable angle range for screen display
    /// - Parameters:
    ///   - distance: Distance in meters
    ///   - maxDistance: Maximum distance to map (default 20,000 km)
    ///   - maxAngle: Maximum display angle in degrees (default 20°)
    /// - Returns: Elevation angle in radians (negative = below horizon)
    static func scaledElevationAngle(
        forDistance distance: Double,
        maxDistance: Double = 20_000_000.0,
        maxAngleDegrees: Double = 20.0
    ) -> Double {
        let maxAngleRadians = maxAngleDegrees * .pi / 180.0
        let normalized = min(distance / maxDistance, 1.0)
        return -normalized * maxAngleRadians
    }

    /// Calculate horizontal screen position for a target
    /// - Parameters:
    ///   - bearing: Absolute bearing to target (degrees)
    ///   - deviceHeading: Device heading (degrees)
    ///   - horizontalFOV: Horizontal field of view (degrees)
    ///   - screenWidth: Screen width in points
    /// - Returns: X position on screen (0 = left edge, screenWidth = right edge)
    static func screenX(
        bearing: Double,
        deviceHeading: Double,
        horizontalFOV: Double,
        screenWidth: Double
    ) -> Double {
        let relativeAngle = relativeBearing(targetBearing: bearing, deviceHeading: deviceHeading)
        let halfFOV = horizontalFOV / 2.0
        let normalizedX = (relativeAngle + halfFOV) / horizontalFOV
        return normalizedX * screenWidth
    }

    /// Calculate vertical screen position for a target
    /// - Parameters:
    ///   - elevation: Elevation angle in radians (negative = below horizon)
    ///   - devicePitch: Device pitch in radians (from CoreMotion attitude.pitch, π/2 when upright)
    ///   - verticalFOV: Vertical field of view (degrees)
    ///   - screenHeight: Screen height in points
    /// - Returns: Y position on screen (0 = top, screenHeight = bottom)
    static func screenY(
        elevation: Double,
        devicePitch: Double,
        verticalFOV: Double,
        screenHeight: Double
    ) -> Double {
        // CoreMotion attitude.pitch: 0 = flat on table, π/2 = upright, approaches π when tilted back
        // Adjust so that "upright" (π/2) is our neutral/zero position
        let neutralPitch = Double.pi / 2.0

        // Clamp pitch to avoid the reversal at horizontal (when pitch approaches 0 or π)
        // This limits the effective tilt range to about ±60° from upright
        let clampedPitch = max(Double.pi / 6, min(5 * Double.pi / 6, devicePitch))
        let adjustedPitch = clampedPitch - neutralPitch

        let halfVFOV = verticalFOV / 2.0 * .pi / 180.0
        // How far is the target from where we're looking?
        let relativeElevation = elevation - adjustedPitch
        // Map to screen: negative = below view center = lower on screen (higher Y)
        let normalizedY = 0.5 - (relativeElevation / (2.0 * halfVFOV))
        return normalizedY * screenHeight
    }

    // MARK: - Sphere Projection (Sky Guide-style)

    /// Convert two coordinates into a unit direction vector in NWU reference frame
    /// (North = +x, West = +y, Up = +z) matching Apple's xTrueNorthZVertical frame
    static func directionVector(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> (x: Double, y: Double, z: Double) {
        let azimuth = bearing(from: from, to: to).toRadians()
        let dist = distance(from: from, to: to)
        let elevation = trueElevationAngle(forDistance: dist)

        let cosE = cos(elevation)
        let x = cosE * cos(azimuth)   // North component
        let y = -cosE * sin(azimuth)  // West component (negative sin because West = +y)
        let z = sin(elevation)         // Up component

        return (x, y, z)
    }

    /// Project a world-space direction vector onto the screen using the device rotation matrix
    /// - Returns: Screen point, or nil if the target is behind the device
    static func projectToScreen(
        worldDirection: (x: Double, y: Double, z: Double),
        rotationMatrix: CMRotationMatrix,
        horizontalFOV: Double,
        verticalFOV: Double,
        screenSize: CGSize
    ) -> CGPoint? {
        let R = rotationMatrix

        // Apple's CMRotationMatrix maps world → device: deviceVec = R * worldVec
        let dx = R.m11 * worldDirection.x + R.m12 * worldDirection.y + R.m13 * worldDirection.z
        let dy = R.m21 * worldDirection.x + R.m22 * worldDirection.y + R.m23 * worldDirection.z
        let dz = R.m31 * worldDirection.x + R.m32 * worldDirection.y + R.m33 * worldDirection.z

        // In device frame: x = right, y = up (top of phone), z = out of screen
        // Point is in front of the device if dz < 0
        guard dz < 0 else { return nil }

        // Angular projection
        let angleX = atan2(dx, -dz)
        let angleY = atan2(dy, -dz)

        let hFOVRad = horizontalFOV.toRadians()
        let vFOVRad = verticalFOV.toRadians()
        let halfW = screenSize.width / 2.0
        let halfH = screenSize.height / 2.0

        let px = halfW + CGFloat(angleX / (hFOVRad / 2.0)) * halfW
        let py = halfH - CGFloat(angleY / (vFOVRad / 2.0)) * halfH

        return CGPoint(x: px, y: py)
    }

    /// Compute visible horizon line points by sampling azimuth around the sphere
    static func horizonScreenPoints(
        rotationMatrix: CMRotationMatrix,
        horizontalFOV: Double,
        verticalFOV: Double,
        screenSize: CGSize
    ) -> [CGPoint] {
        var points: [CGPoint] = []
        // Sample azimuth 0°..360° in 2° steps, elevation = 0 (horizon)
        for azDeg in stride(from: 0.0, through: 360.0, by: 2.0) {
            let az = azDeg.toRadians()
            let worldDir = (x: cos(az), y: -sin(az), z: 0.0)
            if let pt = projectToScreen(
                worldDirection: worldDir,
                rotationMatrix: rotationMatrix,
                horizontalFOV: horizontalFOV,
                verticalFOV: verticalFOV,
                screenSize: screenSize
            ) {
                points.append(pt)
            }
        }
        return points
    }

    /// Extract device heading from rotation matrix (for compass display)
    /// - Returns: Heading in degrees (0-360)
    static func headingFromRotationMatrix(_ R: CMRotationMatrix) -> Double {
        // R maps world→device. To get device forward (0,0,-1) in world coords,
        // use R^T (device→world): world = R^T * device
        // world_i = sum_j R[j][i] * d[j]
        // For d = (0,0,-1): world_i = -R[3][i] = -R.m3{i}
        let forwardNorth = -R.m31  // world x (North)
        let forwardWest = -R.m32   // world y (West)
        // Azimuth from North, clockwise: atan2(East, North) = atan2(-West, North)
        var heading = atan2(-forwardWest, forwardNorth).toDegrees()
        if heading < 0 { heading += 360 }
        return heading
    }
}

// MARK: - Degree/Radian Conversion Extensions
extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }

    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}
