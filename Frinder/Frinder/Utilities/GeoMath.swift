import Foundation
import CoreLocation

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
