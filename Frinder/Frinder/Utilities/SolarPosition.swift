import Foundation

/// Solar position calculator using standard astronomical algorithms
enum SolarPosition {
    /// Compute the sun's azimuth and elevation for a given date and location
    /// - Returns: azimuth in degrees (0°=N, 90°=E, clockwise) and elevation in degrees above horizon
    static func sunPosition(date: Date, latitude: Double, longitude: Double) -> (azimuth: Double, elevation: Double) {
        // Julian date
        let jd = julianDate(from: date)
        let n = jd - 2451545.0 // days since J2000.0

        // Solar mean longitude (degrees)
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)

        // Solar mean anomaly (degrees)
        let gDeg = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)
        let g = gDeg * .pi / 180.0

        // Ecliptic longitude (degrees)
        let lambda = L + 1.915 * sin(g) + 0.020 * sin(2 * g)
        let lambdaRad = lambda * .pi / 180.0

        // Obliquity of ecliptic (degrees)
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180.0

        // Right ascension (radians)
        let alpha = atan2(cos(epsilon) * sin(lambdaRad), cos(lambdaRad))

        // Declination (radians)
        let delta = asin(sin(epsilon) * sin(lambdaRad))

        // Greenwich mean sidereal time (hours → degrees)
        let gmst = (6.697375 + 0.0657098242 * n + hourOfDay(date)).truncatingRemainder(dividingBy: 24)
        let lmst = gmst + longitude / 15.0 // local mean sidereal time (hours)

        // Hour angle (radians)
        let ha = (lmst * 15.0) * .pi / 180.0 - alpha

        let latRad = latitude * .pi / 180.0

        // Elevation (altitude)
        let sinElev = sin(latRad) * sin(delta) + cos(latRad) * cos(delta) * cos(ha)
        let elevation = asin(sinElev) * 180.0 / .pi

        // Azimuth
        let cosAz = (sin(delta) - sin(latRad) * sinElev) / (cos(latRad) * cos(asin(sinElev)))
        var azimuth = acos(max(-1, min(1, cosAz))) * 180.0 / .pi
        if sin(ha) > 0 { azimuth = 360.0 - azimuth }

        return (azimuth: azimuth, elevation: elevation)
    }

    /// Whether it's daytime (sun above civil twilight threshold of -6°)
    static func isDaytime(date: Date, latitude: Double, longitude: Double) -> Bool {
        let pos = sunPosition(date: date, latitude: latitude, longitude: longitude)
        return pos.elevation > -6
    }

    // MARK: - Helpers

    private static func julianDate(from date: Date) -> Double {
        // Seconds since Jan 1, 2000 12:00 TT (approximately UTC for our purposes)
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .gmt,
                                   year: 2000, month: 1, day: 1, hour: 12).date!
        let seconds = date.timeIntervalSince(j2000)
        return 2451545.0 + seconds / 86400.0
    }

    private static func hourOfDay(_ date: Date) -> Double {
        let comps = Calendar(identifier: .gregorian).dateComponents(in: TimeZone.gmt, from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0 + Double(comps.second ?? 0) / 3600.0
    }
}
