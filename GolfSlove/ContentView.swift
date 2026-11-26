import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GreenReaderView()
                .tabItem { Label("Baca Green", systemImage: "scope") }

            ComingSoonView(
                title: "Skor & Handicap",
                systemImage: "list.number",
                message: "Kartu skor 18 hole dan perhitungan handicap akan hadir di versi berikutnya."
            )
            .tabItem { Label("Skor", systemImage: "list.number") }

            ComingSoonView(
                title: "Tips & Trik",
                systemImage: "lightbulb",
                message: "Kumpulan tips driving, short game, dan putting akan hadir di versi berikutnya."
            )
            .tabItem { Label("Tips", systemImage: "lightbulb") }
        }
    }
}
