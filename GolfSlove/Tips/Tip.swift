import Foundation

enum TipCategory: String, CaseIterable, Identifiable, Codable {
    case driving, iron, short, putting, green, mental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: return "Driving"
        case .iron: return "Iron"
        case .short: return "Short Game"
        case .putting: return "Putting"
        case .green: return "Baca Green"
        case .mental: return "Strategi & Mental"
        }
    }

    var systemImage: String {
        switch self {
        case .driving: return "figure.golf"
        case .iron: return "scope"
        case .short: return "arrow.up.forward.circle"
        case .putting: return "circle.circle"
        case .green: return "map"
        case .mental: return "brain.head.profile"
        }
    }
}

struct Tip: Identifiable, Codable, Hashable {
    let id: String
    let category: TipCategory
    let title: String
    let summary: String
    let steps: [String]
    let mistake: String?
    let level: String
}

enum TipLibrary {
    /// Semua tips, dimuat sekali dari Tips.json di dalam aplikasi.
    static let all: [Tip] = {
        guard let url = Bundle.main.url(forResource: "Tips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let tips = try? JSONDecoder().decode([Tip].self, from: data) else {
            assertionFailure("Tips.json tidak ditemukan atau tidak valid")
            return []
        }
        return tips
    }()
}
