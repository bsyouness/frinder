import CoreLocation

/// Simplified continent outlines for earth visualization below the horizon.
/// Each continent is represented as a polygon of ~15-25 vertices.
enum ContinentData {
    struct ContinentPolygon {
        let name: String
        let coordinates: [CLLocationCoordinate2D]
    }

    static let continents: [ContinentPolygon] = [
        // North America
        ContinentPolygon(name: "North America", coordinates: [
            CLLocationCoordinate2D(latitude: 49, longitude: -125),
            CLLocationCoordinate2D(latitude: 55, longitude: -130),
            CLLocationCoordinate2D(latitude: 60, longitude: -140),
            CLLocationCoordinate2D(latitude: 64, longitude: -165),
            CLLocationCoordinate2D(latitude: 71, longitude: -157),
            CLLocationCoordinate2D(latitude: 72, longitude: -125),
            CLLocationCoordinate2D(latitude: 62, longitude: -75),
            CLLocationCoordinate2D(latitude: 52, longitude: -56),
            CLLocationCoordinate2D(latitude: 47, longitude: -60),
            CLLocationCoordinate2D(latitude: 44, longitude: -66),
            CLLocationCoordinate2D(latitude: 30, longitude: -82),
            CLLocationCoordinate2D(latitude: 25, longitude: -81),
            CLLocationCoordinate2D(latitude: 25, longitude: -98),
            CLLocationCoordinate2D(latitude: 20, longitude: -105),
            CLLocationCoordinate2D(latitude: 15, longitude: -92),
            CLLocationCoordinate2D(latitude: 15, longitude: -85),
            CLLocationCoordinate2D(latitude: 30, longitude: -115),
            CLLocationCoordinate2D(latitude: 34, longitude: -120),
            CLLocationCoordinate2D(latitude: 40, longitude: -124),
            CLLocationCoordinate2D(latitude: 49, longitude: -125),
        ]),

        // South America
        ContinentPolygon(name: "South America", coordinates: [
            CLLocationCoordinate2D(latitude: 12, longitude: -72),
            CLLocationCoordinate2D(latitude: 7, longitude: -77),
            CLLocationCoordinate2D(latitude: 1, longitude: -80),
            CLLocationCoordinate2D(latitude: -5, longitude: -81),
            CLLocationCoordinate2D(latitude: -15, longitude: -75),
            CLLocationCoordinate2D(latitude: -24, longitude: -70),
            CLLocationCoordinate2D(latitude: -40, longitude: -72),
            CLLocationCoordinate2D(latitude: -46, longitude: -75),
            CLLocationCoordinate2D(latitude: -54, longitude: -70),
            CLLocationCoordinate2D(latitude: -52, longitude: -65),
            CLLocationCoordinate2D(latitude: -40, longitude: -62),
            CLLocationCoordinate2D(latitude: -34, longitude: -55),
            CLLocationCoordinate2D(latitude: -23, longitude: -42),
            CLLocationCoordinate2D(latitude: -13, longitude: -38),
            CLLocationCoordinate2D(latitude: -5, longitude: -35),
            CLLocationCoordinate2D(latitude: 2, longitude: -50),
            CLLocationCoordinate2D(latitude: 7, longitude: -60),
            CLLocationCoordinate2D(latitude: 10, longitude: -62),
            CLLocationCoordinate2D(latitude: 12, longitude: -72),
        ]),

        // Europe
        ContinentPolygon(name: "Europe", coordinates: [
            CLLocationCoordinate2D(latitude: 36, longitude: -9),
            CLLocationCoordinate2D(latitude: 43, longitude: -9),
            CLLocationCoordinate2D(latitude: 48, longitude: -5),
            CLLocationCoordinate2D(latitude: 51, longitude: 2),
            CLLocationCoordinate2D(latitude: 54, longitude: 8),
            CLLocationCoordinate2D(latitude: 58, longitude: 6),
            CLLocationCoordinate2D(latitude: 62, longitude: 5),
            CLLocationCoordinate2D(latitude: 71, longitude: 25),
            CLLocationCoordinate2D(latitude: 70, longitude: 40),
            CLLocationCoordinate2D(latitude: 60, longitude: 30),
            CLLocationCoordinate2D(latitude: 55, longitude: 28),
            CLLocationCoordinate2D(latitude: 50, longitude: 25),
            CLLocationCoordinate2D(latitude: 47, longitude: 30),
            CLLocationCoordinate2D(latitude: 45, longitude: 28),
            CLLocationCoordinate2D(latitude: 41, longitude: 29),
            CLLocationCoordinate2D(latitude: 38, longitude: 24),
            CLLocationCoordinate2D(latitude: 36, longitude: 23),
            CLLocationCoordinate2D(latitude: 38, longitude: 12),
            CLLocationCoordinate2D(latitude: 39, longitude: 3),
            CLLocationCoordinate2D(latitude: 36, longitude: -9),
        ]),

        // Africa
        ContinentPolygon(name: "Africa", coordinates: [
            CLLocationCoordinate2D(latitude: 37, longitude: 10),
            CLLocationCoordinate2D(latitude: 35, longitude: -1),
            CLLocationCoordinate2D(latitude: 32, longitude: -8),
            CLLocationCoordinate2D(latitude: 26, longitude: -15),
            CLLocationCoordinate2D(latitude: 15, longitude: -17),
            CLLocationCoordinate2D(latitude: 5, longitude: -8),
            CLLocationCoordinate2D(latitude: 4, longitude: 7),
            CLLocationCoordinate2D(latitude: -5, longitude: 12),
            CLLocationCoordinate2D(latitude: -15, longitude: 12),
            CLLocationCoordinate2D(latitude: -25, longitude: 15),
            CLLocationCoordinate2D(latitude: -34, longitude: 18),
            CLLocationCoordinate2D(latitude: -34, longitude: 27),
            CLLocationCoordinate2D(latitude: -26, longitude: 33),
            CLLocationCoordinate2D(latitude: -12, longitude: 40),
            CLLocationCoordinate2D(latitude: -1, longitude: 42),
            CLLocationCoordinate2D(latitude: 5, longitude: 46),
            CLLocationCoordinate2D(latitude: 12, longitude: 51),
            CLLocationCoordinate2D(latitude: 15, longitude: 42),
            CLLocationCoordinate2D(latitude: 22, longitude: 36),
            CLLocationCoordinate2D(latitude: 30, longitude: 32),
            CLLocationCoordinate2D(latitude: 32, longitude: 33),
            CLLocationCoordinate2D(latitude: 37, longitude: 10),
        ]),

        // Asia
        ContinentPolygon(name: "Asia", coordinates: [
            CLLocationCoordinate2D(latitude: 42, longitude: 30),
            CLLocationCoordinate2D(latitude: 38, longitude: 44),
            CLLocationCoordinate2D(latitude: 25, longitude: 56),
            CLLocationCoordinate2D(latitude: 22, longitude: 60),
            CLLocationCoordinate2D(latitude: 8, longitude: 77),
            CLLocationCoordinate2D(latitude: 22, longitude: 88),
            CLLocationCoordinate2D(latitude: 22, longitude: 100),
            CLLocationCoordinate2D(latitude: 10, longitude: 105),
            CLLocationCoordinate2D(latitude: 22, longitude: 108),
            CLLocationCoordinate2D(latitude: 30, longitude: 122),
            CLLocationCoordinate2D(latitude: 40, longitude: 122),
            CLLocationCoordinate2D(latitude: 43, longitude: 132),
            CLLocationCoordinate2D(latitude: 53, longitude: 140),
            CLLocationCoordinate2D(latitude: 60, longitude: 145),
            CLLocationCoordinate2D(latitude: 65, longitude: 170),
            CLLocationCoordinate2D(latitude: 70, longitude: 180),
            CLLocationCoordinate2D(latitude: 72, longitude: 140),
            CLLocationCoordinate2D(latitude: 75, longitude: 100),
            CLLocationCoordinate2D(latitude: 72, longitude: 60),
            CLLocationCoordinate2D(latitude: 60, longitude: 55),
            CLLocationCoordinate2D(latitude: 55, longitude: 50),
            CLLocationCoordinate2D(latitude: 50, longitude: 40),
            CLLocationCoordinate2D(latitude: 42, longitude: 30),
        ]),

        // Australia
        ContinentPolygon(name: "Australia", coordinates: [
            CLLocationCoordinate2D(latitude: -12, longitude: 131),
            CLLocationCoordinate2D(latitude: -15, longitude: 124),
            CLLocationCoordinate2D(latitude: -22, longitude: 114),
            CLLocationCoordinate2D(latitude: -32, longitude: 115),
            CLLocationCoordinate2D(latitude: -35, longitude: 117),
            CLLocationCoordinate2D(latitude: -35, longitude: 137),
            CLLocationCoordinate2D(latitude: -38, longitude: 145),
            CLLocationCoordinate2D(latitude: -34, longitude: 151),
            CLLocationCoordinate2D(latitude: -28, longitude: 153),
            CLLocationCoordinate2D(latitude: -19, longitude: 147),
            CLLocationCoordinate2D(latitude: -14, longitude: 144),
            CLLocationCoordinate2D(latitude: -12, longitude: 136),
            CLLocationCoordinate2D(latitude: -12, longitude: 131),
        ]),
    ]
}
