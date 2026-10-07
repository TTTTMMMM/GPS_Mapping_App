import SwiftUI

struct LoginView: View {
    let authManager: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            // Black so it's readable on the light panel over the map image
            Text("GPS Tracker")
                .font(.custom("Josefin Sans", size: 40))
                .foregroundStyle(.black)

            Button {
                Task { await authManager.signInWithGoogle() }
            } label: {
                HStack(spacing: 8) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("Sign in with Google")
                        .font(.custom("Josefin Sans", size: 18))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
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
        // A panel in the same soft blue as the signed-in screens, so the text stays
        // readable over the map image
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .background(Color.dashboardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
