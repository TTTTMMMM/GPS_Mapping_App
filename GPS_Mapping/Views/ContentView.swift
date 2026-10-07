import SwiftUI
import Playgrounds

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            // Fill the entire screen, including the safe areas: yellow on the login
            // screen, light blue once signed in
            (authManager.isSignedIn ? Color.dashboardBackground : Color.yellow)
                .ignoresSafeArea()

            if authManager.isSignedIn {
                DashboardView(authManager: authManager)
            } else {
                LoginView(authManager: authManager)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
