import SwiftUI

struct EmailVerificationView: View {
    private static let minimumOTPDigits = 6
    private static let maximumOTPDigits = 10

    @ObservedObject var store: AppStore
    let email: String
    @State private var verificationCode = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var resendCooldown = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 28)

                Image(systemName: "envelope.badge")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(BeFitTheme.warning)

                VStack(spacing: 10) {
                    Text("Verify your email")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(BeFitTheme.textPrimary)

                    Text("Enter the verification code Supabase sent to \(email) to finish setting up your BeFit account.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BeFitTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                BeFitCard {
                    VStack(spacing: 16) {
                        BeFitTextField(
                            title: "Verification Code",
                            placeholder: "Enter the code from your email",
                            text: $verificationCode,
                            keyboardType: .numberPad
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BeFitTheme.heart)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BeFitTheme.warning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(title: "Verify Email Code") {
                            Task {
                                await submitCode()
                            }
                        }

                        Button(resendButtonTitle) {
                            Task {
                                await resendCode()
                            }
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(canResendCode ? BeFitTheme.warning : BeFitTheme.textSecondary)
                        .disabled(!canResendCode || store.isAuthActionInFlight)

                        Button("Back to Sign In") {
                            errorMessage = nil
                            statusMessage = nil
                            verificationCode = ""
                            store.returnToLoginFromVerification()
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .onChange(of: verificationCode) { _, newValue in
            verificationCode = sanitizedCode(from: newValue)
        }
        .task(id: resendCooldown) {
            guard resendCooldown > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            guard resendCooldown > 0 else { return }
            resendCooldown -= 1
        }
    }

    private var canResendCode: Bool {
        resendCooldown == 0
    }

    private var resendButtonTitle: String {
        canResendCode ? "Resend Code" : "Resend Code in \(resendCooldown)s"
    }

    private func sanitizedCode(from value: String) -> String {
        String(value.filter(\.isNumber).prefix(Self.maximumOTPDigits))
    }

    private func submitCode() async {
        errorMessage = nil
        statusMessage = nil

        guard (Self.minimumOTPDigits...Self.maximumOTPDigits).contains(verificationCode.count) else {
            errorMessage = "Enter the full verification code from your email."
            return
        }

        do {
            try await store.submitSignupOTP(email: email, code: verificationCode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resendCode() async {
        errorMessage = nil
        statusMessage = nil

        guard canResendCode else { return }

        do {
            try await store.resendSignupOTP(email: email)
            resendCooldown = 60
            statusMessage = "A new verification code was sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
