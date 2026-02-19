import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section("Profile") {
                    if authViewModel.isOffline {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.orange.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "wifi.slash")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Working Offline")
                                    .font(.headline)
                                Text("Profile unavailable")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if let user = authViewModel.currentUser {
                        NavigationLink {
                            EditProfileView()
                        } label: {
                            HStack(spacing: 12) {
                                if let urlStr = user.avatarURL, let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                        default:
                                            initialsCircle(user.displayName)
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    initialsCircle(user.displayName)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Preferences section
                Section("Preferences") {
                    Picker("Distance Unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Toggle("Show Distance & Location", isOn: $settings.showDistanceAndLocation)
                }

                // Landmarks section
                Section {
                    NavigationLink {
                        LandmarkListView()
                    } label: {
                        HStack {
                            Text("Landmarks")
                            Spacer()
                            let enabled = Landmark.allLandmarks.count - settings.disabledLandmarkIds.count
                            Text("\(enabled)/\(Landmark.allLandmarks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Choose which landmarks appear on your radar.")
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://frinder.me/privacy.html")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Link(destination: URL(string: "https://frinder.me/terms.html")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Sign out section
                Section {
                    Button(role: .destructive) {
                        authViewModel.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private func initialsCircle(_ name: String) -> some View {
        Circle()
            .fill(.blue.opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            )
    }
}

struct LandmarkListView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        List {
            Section {
                Toggle("Show Landmarks", isOn: Binding(
                    get: { settings.disabledLandmarkIds.isEmpty },
                    set: { newValue in
                        if newValue {
                            settings.disabledLandmarkIds.removeAll()
                        } else {
                            settings.disabledLandmarkIds = Set(Landmark.allLandmarks.map(\.id))
                        }
                    }
                ))
            }

            Section {
                ForEach(Landmark.allLandmarks.sorted { $0.name < $1.name }) { landmark in
                    HStack(spacing: 12) {
                        Text(landmark.icon)
                            .font(.title2)
                        Text(landmark.name)
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.isLandmarkEnabled(landmark.id) },
                            set: { _ in settings.toggleLandmark(landmark.id) }
                        ))
                        .labelsHidden()
                    }
                }
            }
        }
        .navigationTitle("Landmarks")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
