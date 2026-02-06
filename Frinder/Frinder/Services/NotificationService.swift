import Foundation
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    private let db = Firestore.firestore()
    private var currentUserId: String?

    private override init() {
        super.init()
    }

    func configure(userId: String) {
        self.currentUserId = userId
        Messaging.messaging().delegate = self

        // Get current token and save it
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("Error fetching FCM token: \(error)")
                return
            }

            if let token = token {
                Task {
                    await self?.saveToken(token)
                }
            }
        }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    private func saveToken(_ token: String) async {
        guard let userId = currentUserId else {
            print("No user ID set for saving FCM token")
            return
        }

        do {
            try await db.collection("deviceTokens").document(userId).setData([
                "tokens": FieldValue.arrayUnion([token]),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
            print("FCM token saved for user \(userId)")
        } catch {
            print("Error saving FCM token: \(error)")
        }
    }

    func removeToken() async {
        guard let userId = currentUserId else { return }

        // Get current token to remove
        guard let token = try? await Messaging.messaging().token() else { return }

        do {
            try await db.collection("deviceTokens").document(userId).updateData([
                "tokens": FieldValue.arrayRemove([token]),
                "updatedAt": Timestamp(date: Date())
            ])
            print("FCM token removed for user \(userId)")
        } catch {
            print("Error removing FCM token: \(error)")
        }

        currentUserId = nil
    }

    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle notification data
        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request":
                if let senderId = userInfo["senderId"] as? String {
                    print("Received friend request notification from: \(senderId)")
                    // Post notification for UI to handle
                    NotificationCenter.default.post(
                        name: .newFriendRequest,
                        object: nil,
                        userInfo: ["senderId": senderId]
                    )
                }
            default:
                print("Unknown notification type: \(type)")
            }
        }
    }
}

extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM token refreshed")

        Task {
            await saveToken(token)
        }
    }
}

extension Notification.Name {
    static let newFriendRequest = Notification.Name("newFriendRequest")
}
