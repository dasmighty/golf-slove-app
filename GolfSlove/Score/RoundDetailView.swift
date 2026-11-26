import SwiftUI

/// Mengisi skor per hole.
struct RoundDetailView: View {
    @Bindable var round: Round

    var body: some View {
        List {
            Section {
                summary
            }
            Section("Hole") {
                ForEach(0..<round.holeCount, id: \.self) { i in
                    HoleRow(
                        number: i + 1,
                        par: $round.pars[i],
                        strokes: $round.strokes[i],
                        putts: $round.putts[i]
                    )
                }
            }
            Section {
                DatePicker("Tanggal", selection: $round.date, displayedComponents: .date)
                TextField("Nama lapangan", text: $round.courseName)
            }
        }
        .navigationTitle(round.courseName.isEmpty ? "Ronde" : round.courseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        HStack {
            SummaryItem(title: "Skor", value: "\(round.totalStrokes)")
            Divider()
            SummaryItem(title: "Par", value: ToParText.format(round.toPar), color: ToParText.color(round.toPar))
            Divider()
            SummaryItem(title: "Putt", value: "\(round.totalPutts)")
            Divider()
            SummaryItem(title: "Hole", value: "\(round.holesPlayed)/\(round.holeCount)")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HoleRow: View {
    let number: Int
    @Binding var par: Int
    @Binding var strokes: Int
    @Binding var putts: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hole \(number)")
                    .font(.headline)
                Menu {
                    ForEach(3...6, id: \.self) { p in
                        Button("Par \(p)") { par = p }
                    }
                } label: {
                    Text("Par \(par)")
                        .font(.subheadline)
                }
                Spacer()
                if strokes > 0 {
                    ScoreBadge(diff: strokes - par)
                }
            }
            HStack {
                CountControl(title: "Pukulan", value: strokes) { delta in
                    // Ketukan + pertama langsung mengisi skor par, agar cepat.
                    if strokes == 0 && delta > 0 {
                        strokes = par
                    } else {
                        strokes = min(max(strokes + delta, 0), 20)
                    }
                    if putts > strokes { putts = strokes }
                }
                Spacer()
                CountControl(title: "Putt", value: putts) { delta in
                    putts = min(max(putts + delta, 0), max(strokes, 10))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CountControl: View {
    let title: String
    let value: Int
    let change: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    change(-1)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .disabled(value == 0)
                Text(value == 0 ? "–" : "\(value)")
                    .font(.title2.monospacedDigit().bold())
                    .frame(minWidth: 30)
                Button {
                    change(1)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
            // Gaya borderless supaya tombol di dalam List bisa ditekan terpisah.
            .buttonStyle(.borderless)
        }
    }
}

struct ScoreBadge: View {
    let diff: Int

    private var label: String {
        switch diff {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        default: return "+\(diff)"
        }
    }

    private var color: Color {
        switch diff {
        case ...(-1): return .red
        case 0: return .green
        case 1: return .blue
        default: return .purple
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
