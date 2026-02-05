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
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.blue.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                )

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

                // Preferences section
                Section("Preferences") {
                    Picker("Distance Unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Toggle("Show Landmarks", isOn: $settings.showLandmarks)
                }

                // Landmarks info section
                Section {
                    HStack {
                        Text("Landmarks")
                        Spacer()
                        Text("\(Landmark.allLandmarks.count) worldwide")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("See famous landmarks like the Eiffel Tower, Statue of Liberty, and more on your radar.")
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Link(destination: URL(string: "https://example.com/terms")!) {
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
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
