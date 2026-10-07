import SwiftUI
import Playgrounds

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            if authManager.isSignedIn {
                DashboardView(authManager: authManager)
            } else {
                LoginView(authManager: authManager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fills the entire screen, including the safe areas: the topographic map image on
        // the login screen, light blue once signed in. It's a background, so the image's
        // own size can't affect the layout of the screen on top of it.
        .background {
            Group {
                if authManager.isSignedIn {
                    Color.dashboardBackground
                } else {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                }
            }
            .ignoresSafeArea()
            .clipped()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
