import Foundation

/// Lunar position and phase calculator using simplified astronomical algorithms
enum LunarPosition {
    /// Returns the asset name for the current moon phase, or nil during new moon
    static func moonPhaseImageName(date: Date) -> String? {
        // Known new moon: Jan 6, 2000 18:14 UTC
        let refComponents = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .gmt,
                                           year: 2000, month: 1, day: 6, hour: 18, minute: 14)
        let refDate = refComponents.date!
        let daysSinceRef = date.timeIntervalSince(refDate) / 86400.0
        let synodicPeriod = 29.53
        let phase = daysSinceRef.truncatingRemainder(dividingBy: synodicPeriod)
        let age = phase < 0 ? phase + synodicPeriod : phase

        switch age {
        case 0..<1.85, 27.7..<29.53:
            return nil // new moon — don't draw
        case 1.85..<5.5:
            return "moon-crescent-waxing"
        case 5.5..<9.2:
            return "moon-half-waxing"
        case 9.2..<20.3:
            return "moon-full"
        case 20.3..<24.0:
            return "moon-half-waning"
        case 24.0..<27.7:
            return "moon-crescent-waning"
        default:
            return nil
        }
    }

    /// Compute the moon's azimuth and elevation for a given date and location
    /// - Returns: azimuth in degrees (0°=N, 90°=E, clockwise) and elevation in degrees above horizon
    static func moonPosition(date: Date, latitude: Double, longitude: Double) -> (azimuth: Double, elevation: Double) {
        let jd = SolarPosition.julianDate(from: date)
        let n = jd - 2451545.0

        // Mean lunar elements (degrees)
        let L0 = (218.316 + 13.176396 * n).truncatingRemainder(dividingBy: 360) // mean longitude
        let M  = (134.963 + 13.064993 * n).truncatingRemainder(dividingBy: 360) // mean anomaly
        let F  = (93.272 + 13.229350 * n).truncatingRemainder(dividingBy: 360)  // mean distance

        let Mrad = M * .pi / 180.0
        let Frad = F * .pi / 180.0

        // Ecliptic longitude and latitude (degrees)
        let eclLon = L0 + 6.289 * sin(Mrad)
        let eclLat = 5.128 * sin(Frad)

        let eclLonRad = eclLon * .pi / 180.0
        let eclLatRad = eclLat * .pi / 180.0

        // Obliquity of ecliptic
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180.0

        // Ecliptic to equatorial
        let sinDec = sin(eclLatRad) * cos(epsilon) + cos(eclLatRad) * sin(epsilon) * sin(eclLonRad)
        let delta = asin(sinDec)

        let alpha = atan2(
            sin(eclLonRad) * cos(epsilon) - tan(eclLatRad) * sin(epsilon),
            cos(eclLonRad)
        )

        // Hour angle
        let gmst = (6.697375 + 0.0657098242 * n + SolarPosition.hourOfDay(date)).truncatingRemainder(dividingBy: 24)
        let lmst = gmst + longitude / 15.0
        let ha = (lmst * 15.0) * .pi / 180.0 - alpha

        let latRad = latitude * .pi / 180.0

        // Altitude / azimuth
        let sinElev = sin(latRad) * sin(delta) + cos(latRad) * cos(delta) * cos(ha)
        let elevation = asin(sinElev) * 180.0 / .pi

        let cosAz = (sin(delta) - sin(latRad) * sinElev) / (cos(latRad) * cos(asin(sinElev)))
        var azimuth = acos(max(-1, min(1, cosAz))) * 180.0 / .pi
        if sin(ha) > 0 { azimuth = 360.0 - azimuth }

        return (azimuth: azimuth, elevation: elevation)
    }
}
