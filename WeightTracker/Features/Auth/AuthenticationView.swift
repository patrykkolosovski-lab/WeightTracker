import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var store: AppStore
    let mode: AuthScreenMode

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Image("BeFitLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    Text(mode == .register ? "Create your account" : "Welcome back")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(BeFitTheme.textPrimary)

                    Text(mode == .register ? "Register once, then complete your body metrics to unlock BeFit." : "Sign in to continue tracking your progress.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BeFitTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                BeFitCard {
                    VStack(spacing: 16) {
                        BeFitTextField(title: "Email", placeholder: "you@example.com", text: $email, keyboardType: .emailAddress)
                        BeFitSecureField(title: "Password", placeholder: "Minimum 6 characters", text: $password)

                        if mode == .register {
                            BeFitSecureField(title: "Confirm Password", placeholder: "Repeat your password", text: $confirmPassword)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BeFitTheme.heart)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(title: mode == .register ? "Register" : "Sign In") {
                            submit()
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private func submit() {
        errorMessage = nil

        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        if mode == .register, password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }

        do {
            switch mode {
            case .register:
                try store.register(email: email, password: password)
            case .login:
                try store.login(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
