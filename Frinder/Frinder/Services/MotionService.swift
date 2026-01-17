import Foundation
import CoreMotion
import Combine

class MotionService: ObservableObject {
    static let shared = MotionService()

    private let motionManager = CMMotionManager()
    private var timer: Timer?

    @Published var pitch: Double = 0 // Tilt forward/backward
    @Published var roll: Double = 0  // Tilt left/right
    @Published var yaw: Double = 0   // Rotation around vertical axis

    private init() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
    }

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Calculates the angle of the device's heading relative to north
    /// Combined with compass heading for accurate direction
    var deviceHeadingOffset: Double {
        return yaw.toDegrees()
    }
}
