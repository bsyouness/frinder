import Foundation
import CoreMotion
import Combine

class MotionService: ObservableObject {
    static let shared = MotionService()

    private let motionManager = CMMotionManager()
    private var isUpdating = false

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    @Published var rotationMatrix: CMRotationMatrix?

    private init() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    func startUpdates() {
        guard !isUpdating else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        isUpdating = true
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw
            self.rotationMatrix = motion.attitude.rotationMatrix
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        isUpdating = false
        motionManager.stopDeviceMotionUpdates()
        pitch = 0
        roll = 0
        yaw = 0
        rotationMatrix = nil
    }
}
