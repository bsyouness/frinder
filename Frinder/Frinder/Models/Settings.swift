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

    func format(meters: Double) -> String {
        switch self {
        case .kilometers:
            if meters < 1000 {
                return "\(Int(meters)) m"
            } else {
                return String(format: "%.1f km", meters / 1000)
            }
        case .miles:
            let miles = meters / 1609.344
            if miles < 0.1 {
                let feet = meters * 3.28084
                return "\(Int(feet)) ft"
            } else {
                return String(format: "%.1f mi", miles)
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
    }
}
