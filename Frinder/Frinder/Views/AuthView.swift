import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showResetAlert = false
    @State private var showResetPrompt = false
    @State private var resetEmail = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()

                        // App logo/title
                        VStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)

                            Text("Frinder")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Find your friends")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Form fields
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    PasswordField(
                        placeholder: "Password",
                        text: $password,
                        contentType: isSignUp ? .newPassword : .password
                    )
                    .frame(height: 36)

                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                resetEmail = email
                                showResetPrompt = true
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)

                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Submit button
                Button {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                displayName: displayName
                            )
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(!isFormValid || authViewModel.isLoading)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal)

                // Google Sign-In button (official branding)
                Button {
                    Task {
                        await authViewModel.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        GoogleLogo()
                            .frame(width: 20, height: 20)
                        Text("Sign in with Google")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .background(Color.white)
                .foregroundStyle(Color(red: 0x1f/255, green: 0x1f/255, blue: 0x1f/255))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0x74/255, green: 0x77/255, blue: 0x75/255), lineWidth: 1)
                )
                .padding(.horizontal)
                .disabled(authViewModel.isLoading)

                // Toggle sign in/up
                Button {
                    withAnimation {
                        isSignUp.toggle()
                        authViewModel.errorMessage = nil
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                }

                        Spacer()
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .alert("Reset Password", isPresented: $showResetPrompt) {
                TextField("Email address", text: $resetEmail)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                Button("Send Reset Link") {
                    Task {
                        let success = await authViewModel.sendPasswordReset(email: resetEmail)
                        if success { showResetAlert = true }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your email address and we'll send you a reset link.")
            }
            .alert("Check Your Email", isPresented: $showResetAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("If an account exists for \(resetEmail), you'll receive a password reset link. Check your spam folder if you don't see it.")
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

/// Official Google "G" logo using the exact SVG paths from Google's branding guidelines
struct GoogleLogo: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 48.0

            Canvas { context, size in
                // Red path - top arc
                let redPath = Path { path in
                    path.move(to: CGPoint(x: 24 * scale, y: 9.5 * scale))
                    path.addCurve(
                        to: CGPoint(x: 33.21 * scale, y: 13.1 * scale),
                        control1: CGPoint(x: 27.54 * scale, y: 9.5 * scale),
                        control2: CGPoint(x: 30.71 * scale, y: 10.72 * scale)
                    )
                    path.addLine(to: CGPoint(x: 40.06 * scale, y: 6.25 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 0 * scale),
                        control1: CGPoint(x: 35.9 * scale, y: 2.38 * scale),
                        control2: CGPoint(x: 30.47 * scale, y: 0 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 2.56 * scale, y: 13.22 * scale),
                        control1: CGPoint(x: 14.62 * scale, y: 0 * scale),
                        control2: CGPoint(x: 6.51 * scale, y: 5.38 * scale)
                    )
                    path.addLine(to: CGPoint(x: 10.54 * scale, y: 19.41 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 9.5 * scale),
                        control1: CGPoint(x: 12.43 * scale, y: 13.72 * scale),
                        control2: CGPoint(x: 17.74 * scale, y: 9.5 * scale)
                    )
                    path.closeSubpath()
                }
                context.fill(redPath, with: .color(Color(red: 0xEA/255, green: 0x43/255, blue: 0x35/255)))

                // Blue path - right side
                let bluePath = Path { path in
                    path.move(to: CGPoint(x: 46.98 * scale, y: 24.55 * scale))
                    path.addCurve(
                        to: CGPoint(x: 46.6 * scale, y: 20 * scale),
                        control1: CGPoint(x: 46.98 * scale, y: 22.98 * scale),
                        control2: CGPoint(x: 46.83 * scale, y: 21.46 * scale)
                    )
                    path.addLine(to: CGPoint(x: 24 * scale, y: 20 * scale))
                    path.addLine(to: CGPoint(x: 24 * scale, y: 29.02 * scale))
                    path.addLine(to: CGPoint(x: 36.94 * scale, y: 29.02 * scale))
                    path.addCurve(
                        to: CGPoint(x: 32.16 * scale, y: 36.2 * scale),
                        control1: CGPoint(x: 36.36 * scale, y: 31.98 * scale),
                        control2: CGPoint(x: 34.68 * scale, y: 34.5 * scale)
                    )
                    path.addLine(to: CGPoint(x: 39.89 * scale, y: 42.2 * scale))
                    path.addCurve(
                        to: CGPoint(x: 46.98 * scale, y: 24.55 * scale),
                        control1: CGPoint(x: 44.4 * scale, y: 38.02 * scale),
                        control2: CGPoint(x: 46.98 * scale, y: 31.91 * scale)
                    )
                    path.closeSubpath()
                }
                context.fill(bluePath, with: .color(Color(red: 0x42/255, green: 0x85/255, blue: 0xF4/255)))

                // Yellow path - left side
                let yellowPath = Path { path in
                    path.move(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
                    path.addCurve(
                        to: CGPoint(x: 9.77 * scale, y: 24 * scale),
                        control1: CGPoint(x: 10.05 * scale, y: 27.14 * scale),
                        control2: CGPoint(x: 9.77 * scale, y: 25.6 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 10.53 * scale, y: 19.41 * scale),
                        control1: CGPoint(x: 9.77 * scale, y: 22.4 * scale),
                        control2: CGPoint(x: 10.04 * scale, y: 20.86 * scale)
                    )
                    path.addLine(to: CGPoint(x: 2.55 * scale, y: 13.22 * scale))
                    path.addCurve(
                        to: CGPoint(x: 0 * scale, y: 24 * scale),
                        control1: CGPoint(x: 0.92 * scale, y: 16.46 * scale),
                        control2: CGPoint(x: 0 * scale, y: 20.12 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 2.56 * scale, y: 34.78 * scale),
                        control1: CGPoint(x: 0 * scale, y: 27.88 * scale),
                        control2: CGPoint(x: 0.92 * scale, y: 31.54 * scale)
                    )
                    path.addLine(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
                    path.closeSubpath()
                }
                context.fill(yellowPath, with: .color(Color(red: 0xFB/255, green: 0xBC/255, blue: 0x05/255)))

                // Green path - bottom arc
                let greenPath = Path { path in
                    path.move(to: CGPoint(x: 24 * scale, y: 48 * scale))
                    path.addCurve(
                        to: CGPoint(x: 39.89 * scale, y: 42.19 * scale),
                        control1: CGPoint(x: 30.48 * scale, y: 48 * scale),
                        control2: CGPoint(x: 35.93 * scale, y: 45.87 * scale)
                    )
                    path.addLine(to: CGPoint(x: 32.16 * scale, y: 36.19 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 38.49 * scale),
                        control1: CGPoint(x: 30.01 * scale, y: 37.64 * scale),
                        control2: CGPoint(x: 27.24 * scale, y: 38.49 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 10.53 * scale, y: 28.58 * scale),
                        control1: CGPoint(x: 17.74 * scale, y: 38.49 * scale),
                        control2: CGPoint(x: 12.43 * scale, y: 34.27 * scale)
                    )
                    path.addLine(to: CGPoint(x: 2.55 * scale, y: 34.77 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 48 * scale),
                        control1: CGPoint(x: 6.51 * scale, y: 42.62 * scale),
                        control2: CGPoint(x: 14.62 * scale, y: 48 * scale)
                    )
                    path.closeSubpath()
                }
                context.fill(greenPath, with: .color(Color(red: 0x34/255, green: 0xA8/255, blue: 0x53/255)))
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
