import SwiftData
import SwiftUI

/// Tab Skor: handicap saat ini dan riwayat ronde.
struct ScoreHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @State private var showingNewRound = false
    @State private var path: [Round] = []

    private var handicap: HandicapCalculator.Result? {
        HandicapCalculator.handicap(rounds.compactMap(\.handicapEntry))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    HandicapCard(result: handicap, completedRounds: rounds.filter(\.isComplete).count)
                } footer: {
                    Text("Handicap sederhana: rata-rata selisih skor terhadap par dari ronde terbaik Anda (8 terbaik dari 20 ronde terakhir). Ini bukan handicap resmi.")
                }

                Section("Riwayat ronde") {
                    if rounds.isEmpty {
                        Text("Belum ada ronde. Ketuk + untuk mulai mencatat skor.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rounds) { round in
                        NavigationLink(value: round) {
                            RoundRow(round: round)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(rounds[index]) }
                    }
                }
            }
            .navigationTitle("Skor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewRound = true
                    } label: {
                        Label("Ronde baru", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Round.self) { round in
                RoundDetailView(round: round)
            }
            .sheet(isPresented: $showingNewRound) {
                NewRoundView(previousRounds: rounds) { round in
                    context.insert(round)
                    path.append(round)
                }
            }
        }
    }
}

struct HandicapCard: View {
    let result: HandicapCalculator.Result?
    let completedRounds: Int

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Handicap").font(.subheadline).foregroundStyle(.secondary)
                if let result {
                    Text(HandicapCalculator.format(result.value))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("Dari \(result.roundsUsed) ronde terbaik di antara \(result.roundsConsidered) ronde terakhir")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("–")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    let needed = max(HandicapCalculator.minimumRounds - completedRounds, 0)
                    Text("Selesaikan \(needed) ronde lagi untuk melihat handicap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "figure.golf")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 6)
    }
}

struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(round.courseName.isEmpty ? "Tanpa nama" : round.courseName)
                    .font(.headline)
                Text(round.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !round.isComplete {
                    Text("\(round.holesPlayed)/\(round.holeCount) hole")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(round.totalStrokes)")
                    .font(.title3.bold())
                Text(ToParText.format(round.toPar))
                    .font(.caption.bold())
                    .foregroundStyle(ToParText.color(round.toPar))
            }
        }
    }
}

enum ToParText {
    static func format(_ diff: Int) -> String {
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    static func color(_ diff: Int) -> Color {
        if diff < 0 { return .red }
        if diff == 0 { return .primary }
        return .blue
    }
}
