import SwiftUI

struct LoginView: View {
    let authManager: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            // Black so it's readable on the yellow background
            Text("GPS Mapping")
                .font(.custom("Josefin Sans", size: 40))
                .foregroundStyle(.black)

            Button {
                Task { await authManager.signInWithGoogle() }
            } label: {
                HStack(spacing: 6) {
                    Text("G")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("Sign in with Google")
                        .font(.custom("Josefin Sans", size: 14))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(authManager.isSigningIn)

            if authManager.isSigningIn {
                ProgressView()
            }

            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.custom("Josefin Sans", size: 14))
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }
}
