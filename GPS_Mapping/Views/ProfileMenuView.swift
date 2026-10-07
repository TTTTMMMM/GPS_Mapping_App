import SwiftUI
import FirebaseAuth

extension View {
    /// Puts the signed-in user's profile picture (with its Sign Out dropdown) in the
    /// upper right of this screen's toolbar. Apply to the content of a `NavigationStack`.
    /// A toolbar item is used because views drawn in the macOS title bar strip
    /// don't receive clicks.
    func profileToolbar(authManager: AuthManager) -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                ProfileMenuView(authManager: authManager)
            }
            .sharedBackgroundVisibility(.hidden) // no glass bubble around the picture
        }
    }
}

/// The signed-in user's Google profile picture. Clicking it opens a small
/// dropdown with their name/email and a Sign Out action.
///
/// Note: this uses a Button + popover rather than `Menu`, because on macOS a
/// `Menu` label ignores `.frame` and draws the photo at its natural size.
struct ProfileMenuView: View {
    let authManager: AuthManager

    @State private var isShowingMenu = false
    private let size: CGFloat = 28

    var body: some View {
        Button {
            isShowingMenu.toggle()
        } label: {
            avatar
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile menu")
        .popover(isPresented: $isShowingMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                if let name = authManager.user?.displayName {
                    Text(name)
                        .font(.headline)
                }
                if let email = authManager.user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Divider()
                Button("Sign Out", role: .destructive) {
                    isShowingMenu = false
                    authManager.signOut()
                }
                .buttonStyle(.plain)
            }
            // White text so it's readable on the dark popover background
            .foregroundStyle(.white)
            .padding()
            .frame(minWidth: 180, alignment: .leading)
            // Keep it a dropdown-style popover on iPhone instead of a full sheet
            .presentationCompactAdaptation(.popover)
            // Fixed dark background so the white text is readable whether the
            // device (e.g. an iPad) is in light or dark mode
            .presentationBackground(Color(white: 0.18))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        AsyncImage(url: profileImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                // Shown while loading, or if the account has no photo
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
        .contentShape(Circle())
    }

    /// Google serves a small (96px) photo by default; ask for a sharper one.
    private var profileImageURL: URL? {
        guard let url = authManager.user?.photoURL else { return nil }
        let sharper = url.absoluteString.replacingOccurrences(of: "=s96-c", with: "=s192-c")
        return URL(string: sharper) ?? url
    }
}
