import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
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

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                Task {
                                    if await authViewModel.sendPasswordReset(email: email) {
                                        showResetAlert = true
                                    }
                                }
                            }
                            .font(.caption)
                            .disabled(email.isEmpty || authViewModel.isLoading)
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
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
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

                // Google Sign-In button
                Button {
                    Task {
                        await authViewModel.signInWithGoogle()
                    }
                } label: {
                    HStack {
                        GoogleLogo()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .cornerRadius(10)
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
            .alert("Password Reset Email Sent", isPresented: $showResetAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Check your email for instructions to reset your password.")
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
}

struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let center = CGPoint(x: width / 2, y: height / 2)
            let radius = min(width, height) / 2 * 0.9
            let innerRadius = radius * 0.55
            let barWidth = radius * 0.45

            // Blue section (top-right, from ~45° to ~135° visually, but we draw from right)
            var bluePath = Path()
            bluePath.move(to: center)
            bluePath.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))

            // Green section (bottom-right)
            var greenPath = Path()
            greenPath.move(to: center)
            greenPath.addArc(center: center, radius: radius, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))

            // Yellow section (bottom-left)
            var yellowPath = Path()
            yellowPath.move(to: center)
            yellowPath.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 251/255, green: 188/255, blue: 5/255)))

            // Red section (top-left)
            var redPath = Path()
            redPath.move(to: center)
            redPath.addArc(center: center, radius: radius, startAngle: .degrees(225), endAngle: .degrees(315), clockwise: false)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 234/255, green: 67/255, blue: 53/255)))

            // White inner circle to create the "G" shape
            var innerCircle = Path()
            innerCircle.addArc(center: center, radius: innerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.fill(innerCircle, with: .color(.white))

            // Cut out the right side to make the "G" opening
            var cutout = Path()
            cutout.addRect(CGRect(x: center.x, y: center.y - innerRadius, width: radius, height: innerRadius))
            context.fill(cutout, with: .color(.white))

            // Blue horizontal bar for the "G"
            let barRect = CGRect(
                x: center.x - barWidth * 0.1,
                y: center.y - barWidth / 2,
                width: radius * 0.55,
                height: barWidth
            )
            context.fill(Path(barRect), with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
