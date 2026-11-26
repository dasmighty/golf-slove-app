import SwiftData
import SwiftUI

@main
struct GolfSloveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Round.self)
    }
}
