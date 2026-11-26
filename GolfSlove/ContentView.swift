import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        TabView {
            GreenReaderView()
                .tabItem { Label("Baca Green", systemImage: "scope") }

            ScoreHomeView()
                .tabItem { Label("Skor", systemImage: "list.number") }

            TipsView()
                .tabItem { Label("Tips", systemImage: "lightbulb") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView { hasSeenOnboarding = true }
        }
    }
}
