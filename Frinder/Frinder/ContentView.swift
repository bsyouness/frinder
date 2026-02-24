import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.needsEmailVerification {
                    VerifyEmailView()
                } else {
                    MainTabView()
                        .sheet(isPresented: $authViewModel.needsRealEmail) {
                            ProvideEmailSheet()
                                .environmentObject(authViewModel)
                        }
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .animation(.easeInOut, value: authViewModel.needsEmailVerification)
    }
}

private struct ProvideEmailSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                Text("Share Your Email")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Apple hid your email. Enter your real email so friends can find you, or skip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 24)

                Button {
                    Task { await authViewModel.provideRealEmail(email) }
                } label: {
                    Text("Save Email")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(isValidEmail ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(10)
                .padding(.horizontal, 24)
                .disabled(!isValidEmail)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { authViewModel.skipRealEmail() }
                }
            }
        }
    }

    private var isValidEmail: Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
