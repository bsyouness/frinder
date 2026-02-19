import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var isChecking = false
    @State private var isResending = false
    @State private var resendCooldown = 0
    @State private var notVerifiedYet = false
    @State private var resendTimer: Timer?

    private var email: String {
        authViewModel.currentUser?.email ?? "your email"
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            // Heading
            VStack(spacing: 8) {
                Text("Verify Your Email")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("We sent a verification link to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            // Instructions
            Text("Open the link in the email, then come back and tap the button below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // "I've verified" feedback
            if notVerifiedYet {
                Text("Your email hasn't been verified yet. Please check your inbox and try again.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                // Check verification button
                Button {
                    Task { await checkVerification() }
                } label: {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("I've Verified My Email")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
                .disabled(isChecking)

                // Resend button
                Button {
                    Task { await resend() }
                } label: {
                    if isResending {
                        ProgressView()
                    } else if resendCooldown > 0 {
                        Text("Resend Email (\(resendCooldown)s)")
                    } else {
                        Text("Resend Email")
                    }
                }
                .font(.subheadline)
                .disabled(isResending || resendCooldown > 0)

                // Back to sign in
                Button("Back to Sign In") {
                    authViewModel.signOut()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
    }

    private func checkVerification() async {
        isChecking = true
        notVerifiedYet = false
        let verified = await authViewModel.checkEmailVerification()
        if !verified {
            notVerifiedYet = true
        }
        isChecking = false
    }

    private func resend() async {
        isResending = true
        await authViewModel.resendVerificationEmail()
        isResending = false
        startCooldown()
    }

    private func startCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            resendCooldown -= 1
            if resendCooldown <= 0 {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    VerifyEmailView()
        .environmentObject(AuthViewModel())
}
