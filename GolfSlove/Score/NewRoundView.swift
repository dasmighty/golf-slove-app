import SwiftUI

/// Form untuk memulai ronde baru.
struct NewRoundView: View {
    /// Susunan par umum untuk lapangan par 72.
    static let standardPars = [4, 4, 3, 4, 5, 4, 3, 4, 5, 4, 4, 3, 4, 5, 4, 3, 4, 5]

    let previousRounds: [Round]
    let onCreate: (Round) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var courseName = ""
    @State private var holes = 18
    @State private var date = Date.now

    /// Lapangan yang pernah dimainkan, terbaru lebih dulu.
    private var knownCourses: [String] {
        var seen = Set<String>()
        return previousRounds.compactMap { r in
            let name = r.courseName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            return name
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lapangan") {
                    TextField("Nama lapangan", text: $courseName)
                    if !knownCourses.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(knownCourses, id: \.self) { name in
                                    Button(name) { courseName = name }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                Section("Ronde") {
                    Picker("Jumlah hole", selection: $holes) {
                        Text("9 hole").tag(9)
                        Text("18 hole").tag(18)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Tanggal", selection: $date, displayedComponents: .date)
                }
                Section {
                    Text(parInfo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ronde baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mulai") {
                        let name = courseName.trimmingCharacters(in: .whitespaces)
                        onCreate(Round(date: date, courseName: name, pars: pars(for: name)))
                        dismiss()
                    }
                }
            }
        }
    }

    private var previousSameCourse: Round? {
        let name = courseName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return nil }
        return previousRounds.first {
            $0.courseName.trimmingCharacters(in: .whitespaces).lowercased() == name && $0.holeCount == holes
        }
    }

    private var parInfo: String {
        if previousSameCourse != nil {
            return "Par tiap hole disalin dari ronde terakhir Anda di lapangan ini."
        }
        return "Par awal memakai susunan umum (par \(holes == 18 ? 72 : 36)). Anda bisa mengubah par tiap hole saat mengisi skor."
    }

    private func pars(for name: String) -> [Int] {
        if let previous = previousSameCourse { return previous.pars }
        return Array(Self.standardPars.prefix(holes))
    }
}
