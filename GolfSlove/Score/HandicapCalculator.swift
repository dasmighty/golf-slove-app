import Foundation

/// Handicap sederhana (bukan handicap resmi World Handicap System).
///
/// Rumus: selisih skor terhadap par tiap ronde (ronde 9 hole dikali 2),
/// lalu dirata-rata dari ronde-ronde terbaik di antara 20 ronde terakhir:
/// 8 terbaik jika sudah ada 20 ronde, atau 40% terbaik jika kurang.
/// Minimal 3 ronde selesai.
enum HandicapCalculator {
    struct Entry {
        let date: Date
        let strokes: Int
        let par: Int
        let holes: Int
    }

    struct Result {
        let value: Double
        let roundsConsidered: Int
        let roundsUsed: Int
    }

    static let minimumRounds = 3
    static let window = 20

    /// Selisih terhadap par, disetarakan ke 18 hole.
    static func differential(_ e: Entry) -> Double {
        Double(e.strokes - e.par) * 18.0 / Double(max(e.holes, 1))
    }

    static func handicap(_ entries: [Entry]) -> Result? {
        let recent = entries.sorted { $0.date > $1.date }.prefix(window)
        guard recent.count >= minimumRounds else { return nil }
        let diffs = recent.map(differential).sorted()
        let take = recent.count >= window ? 8 : max(1, Int((Double(recent.count) * 0.4).rounded()))
        let best = diffs.prefix(take)
        let value = best.reduce(0, +) / Double(best.count)
        return Result(value: (value * 10).rounded() / 10, roundsConsidered: recent.count, roundsUsed: best.count)
    }

    /// Format tampilan: handicap di bawah 0 ditulis dengan tanda plus, seperti kebiasaan golf.
    static func format(_ value: Double) -> String {
        value < 0 ? String(format: "+%.1f", -value) : String(format: "%.1f", value)
    }
}
