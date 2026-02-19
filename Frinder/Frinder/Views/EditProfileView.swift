import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Avatar
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var isUploadingAvatar = false

    // Display name
    @State private var displayName = ""
    @State private var isSavingName = false

    // Password
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false

    // Feedback
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var avatarURL: URL? {
        guard let str = authViewModel.currentUser?.avatarURL else { return nil }
        return URL(string: str)
    }

    var body: some View {
        Form {
            // MARK: Avatar
            Section("Avatar") {
                HStack {
                    Spacer()
                    Button {
                        showImagePicker = true
                    } label: {
                        avatarView
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // MARK: Display Name
            Section("Display Name") {
                TextField("Display name", text: $displayName)
                    .autocorrectionDisabled()
                Button {
                    Task { await saveName() }
                } label: {
                    if isSavingName {
                        ProgressView()
                    } else {
                        Text("Save Name")
                    }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSavingName)
            }

            // MARK: Password (email/password users only)
            if authViewModel.isEmailPasswordUser {
                Section("Change Password") {
                    PasswordField(placeholder: "New password", text: $newPassword, contentType: .newPassword)
                        .frame(height: 36)
                    PasswordField(placeholder: "Confirm password", text: $confirmPassword, contentType: .newPassword)
                        .frame(height: 36)
                    Button {
                        Task { await changePassword() }
                    } label: {
                        if isChangingPassword {
                            ProgressView()
                        } else {
                            Text("Change Password")
                        }
                    }
                    .disabled(newPassword.isEmpty || isChangingPassword)
                }
            }

            // MARK: Feedback
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $pickedImage)
        }
        .onChange(of: pickedImage) { _, image in
            guard let image else { return }
            Task { await uploadAvatar(image) }
        }
        .onAppear {
            displayName = authViewModel.currentUser?.displayName ?? ""
        }
    }

    // MARK: - Avatar view

    @ViewBuilder
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            if isUploadingAvatar {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .overlay(ProgressView())
            } else if let pickedImage {
                Image(uiImage: pickedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
            } else if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholderCircle
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
            } else {
                placeholderCircle
            }

            Image(systemName: "camera.fill")
                .font(.caption)
                .padding(6)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .offset(x: 4, y: 4)
        }
        .padding(.vertical, 8)
    }

    private var placeholderCircle: some View {
        Circle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 90, height: 90)
            .overlay(
                Text((authViewModel.currentUser?.displayName.prefix(1).uppercased()) ?? "?")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            )
    }

    // MARK: - Actions

    private func uploadAvatar(_ image: UIImage) async {
        isUploadingAvatar = true
        errorMessage = nil
        successMessage = nil

        let maxSide: CGFloat = 512
        let resized = image.resized(toMaxSide: maxSide)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to encode image."
            isUploadingAvatar = false
            return
        }

        await authViewModel.updateAvatar(jpeg)
        isUploadingAvatar = false

        if authViewModel.errorMessage == nil {
            successMessage = "Avatar updated."
        } else {
            errorMessage = authViewModel.errorMessage
        }
    }

    private func saveName() async {
        isSavingName = true
        errorMessage = nil
        successMessage = nil
        await authViewModel.updateDisplayName(displayName.trimmingCharacters(in: .whitespaces))
        isSavingName = false
        if authViewModel.errorMessage == nil {
            successMessage = "Display name updated."
        } else {
            errorMessage = authViewModel.errorMessage
        }
    }

    private func changePassword() async {
        errorMessage = nil
        successMessage = nil
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        isChangingPassword = true
        do {
            try await authViewModel.updatePassword(newPassword)
            newPassword = ""
            confirmPassword = ""
            successMessage = "Password changed successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
        isChangingPassword = false
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resized(toMaxSide maxSide: CGFloat) -> UIImage {
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthViewModel())
    }
}
