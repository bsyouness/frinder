import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @State private var showAddFriend = false
    @State private var friendEmail = ""

    var body: some View {
        NavigationStack {
            List {
                // Pending requests section
                if !friendsViewModel.pendingRequests.isEmpty {
                    Section("Friend Requests") {
                        ForEach(friendsViewModel.pendingRequests) { user in
                            FriendRequestRow(user: user) {
                                Task { await friendsViewModel.acceptRequest(from: user) }
                            } onDecline: {
                                Task { await friendsViewModel.declineRequest(from: user) }
                            }
                        }
                    }
                }

                // Friends section
                Section("Friends (\(friendsViewModel.friends.count))") {
                    if friendsViewModel.friends.isEmpty {
                        Text("No friends yet. Add some friends to get started!")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(friendsViewModel.friends) { friend in
                            FriendRow(friend: friend)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await friendsViewModel.removeFriend(friend) }
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(
                    email: $friendEmail,
                    isLoading: friendsViewModel.isLoading,
                    errorMessage: friendsViewModel.errorMessage,
                    successMessage: friendsViewModel.successMessage
                ) {
                    Task {
                        await friendsViewModel.sendFriendRequest(email: friendEmail)
                        if friendsViewModel.errorMessage == nil {
                            friendEmail = ""
                        }
                    }
                } onDismiss: {
                    showAddFriend = false
                    friendEmail = ""
                    friendsViewModel.errorMessage = nil
                    friendsViewModel.successMessage = nil
                }
            }
            .refreshable {
                await friendsViewModel.loadPendingRequests()
            }
            .task {
                await friendsViewModel.loadPendingRequests()
            }
        }
    }
}

struct FriendRow: View {
    let friend: Friend

    private func relativeTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = friend.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(.blue.opacity(0.3))
                        .overlay(
                            Text(friend.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(.blue)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(friend.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body)

                if let location = friend.location {
                    let age = Date().timeIntervalSince(location.timestamp)
                    if age < 300 {
                        Text("Online")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Last seen \(relativeTime(age))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct FriendRequestRow: View {
    let user: User
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.orange.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddFriendSheet: View {
    @Binding var email: String
    let isLoading: Bool
    let errorMessage: String?
    let successMessage: String?
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Add a friend by entering their email address.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("friend@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if let success = successMessage {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                Button {
                    onAdd()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Friend Request")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(email.isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(email.isEmpty || isLoading)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    FriendsView()
        .environmentObject(FriendsViewModel())
}
