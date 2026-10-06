import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        ZStack {
            // Fill the entire screen with yellow, including the safe areas
            Color.yellow
                .ignoresSafeArea()

            Text("Hello, world!")
                .font(.custom("Josefin Sans", size: 34))
                .foregroundStyle(.black)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
