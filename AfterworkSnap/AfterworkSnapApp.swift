import SwiftUI

@main
struct AfterworkSnapApp: App {
    var body: some Scene {
        // Light mode commented out: the scene is pinned dark at the root;
        // the light-mode branches below it stay in the code, unreachable.
        WindowGroup { ContentView().preferredColorScheme(.dark) }
    }
}
