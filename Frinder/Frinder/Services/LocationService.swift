import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private var locationSubject = PassthroughSubject<CLLocation, Never>()
    private var headingSubject = PassthroughSubject<CLHeading, Never>()

    @Published var currentLocation: CLLocation?
    @Published var currentHeading: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLHeading, Never> {
        headingSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func startUpdatingHeading() {
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
            startUpdatingHeading()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationSubject.send(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            headingSubject.send(newHeading)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
