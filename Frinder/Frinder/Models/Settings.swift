import Foundation

enum DistanceUnit: String, Codable, CaseIterable {
    case kilometers = "km"
    case miles = "mi"

    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    func format(meters: Double) -> String {
        switch self {
        case .kilometers:
            if meters < 1000 {
                return "\(Self.intFormatter.string(from: NSNumber(value: Int(meters))) ?? "\(Int(meters))") m"
            } else {
                let km = meters / 1000
                return "\(Self.decimalFormatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)) km"
            }
        case .miles:
            let miles = meters / 1609.344
            if miles < 0.1 {
                let feet = meters * 3.28084
                return "\(Self.intFormatter.string(from: NSNumber(value: Int(feet))) ?? "\(Int(feet))") ft"
            } else {
                return "\(Self.decimalFormatter.string(from: NSNumber(value: miles)) ?? String(format: "%.1f", miles)) mi"
            }
        }
    }
}

class AppSettings: ObservableObject {
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }

    @Published var showLandmarks: Bool {
        didSet {
            UserDefaults.standard.set(showLandmarks, forKey: "showLandmarks")
        }
    }

    @Published var disabledLandmarkIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(disabledLandmarkIds), forKey: "disabledLandmarkIds")
        }
    }

    @Published var showDistanceAndLocation: Bool {
        didSet {
            UserDefaults.standard.set(showDistanceAndLocation, forKey: "showDistanceAndLocation")
        }
    }

    func isLandmarkEnabled(_ id: String) -> Bool {
        !disabledLandmarkIds.contains(id)
    }

    func toggleLandmark(_ id: String) {
        if disabledLandmarkIds.contains(id) {
            disabledLandmarkIds.remove(id)
        } else {
            disabledLandmarkIds.insert(id)
        }
    }

    static let shared = AppSettings()

    private init() {
        if let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit"),
           let unit = DistanceUnit(rawValue: savedUnit) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .kilometers
        }

        // Default to showing landmarks
        self.showLandmarks = UserDefaults.standard.object(forKey: "showLandmarks") as? Bool ?? true

        if let savedIds = UserDefaults.standard.stringArray(forKey: "disabledLandmarkIds") {
            self.disabledLandmarkIds = Set(savedIds)
        } else {
            self.disabledLandmarkIds = []
        }

        self.showDistanceAndLocation = UserDefaults.standard.object(forKey: "showDistanceAndLocation") as? Bool ?? true
    }
}
