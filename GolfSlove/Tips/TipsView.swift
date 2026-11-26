import SwiftUI

/// Tab Tips: daftar tips per kategori, dengan pencarian dan favorit.
struct TipsView: View {
    @State private var category: TipCategory?
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @AppStorage("favoriteTips") private var favoritesRaw = ""

    private var favorites: Set<String> {
        Set(favoritesRaw.split(separator: ",").map(String.init))
    }

    private var filtered: [Tip] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return TipLibrary.all.filter { tip in
            (category == nil || tip.category == category)
                && (!showFavoritesOnly || favorites.contains(tip.id))
                && (query.isEmpty
                    || tip.title.lowercased().contains(query)
                    || tip.summary.lowercased().contains(query)
                    || tip.steps.contains { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryBar
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if filtered.isEmpty {
                    ContentUnavailableView(
                        showFavoritesOnly ? "Belum ada favorit" : "Tidak ditemukan",
                        systemImage: showFavoritesOnly ? "star" : "magnifyingglass",
                        description: Text(showFavoritesOnly
                            ? "Ketuk bintang di halaman tips untuk menyimpannya di sini."
                            : "Coba kata kunci lain.")
                    )
                }
                ForEach(TipCategory.allCases) { cat in
                    let tips = filtered.filter { $0.category == cat }
                    if !tips.isEmpty {
                        Section(cat.title) {
                            ForEach(tips) { tip in
                                NavigationLink(value: tip) {
                                    TipRow(tip: tip, isFavorite: favorites.contains(tip.id))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tips & Trik")
            .searchable(text: $searchText, prompt: "Cari tips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                    }
                    .accessibilityLabel("Tampilkan favorit saja")
                }
            }
            .navigationDestination(for: Tip.self) { tip in
                TipDetailView(tip: tip, isFavorite: favoriteBinding(for: tip))
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "Semua", systemImage: "square.grid.2x2", selected: category == nil) {
                    category = nil
                }
                ForEach(TipCategory.allCases) { cat in
                    CategoryChip(title: cat.title, systemImage: cat.systemImage, selected: category == cat) {
                        category = (category == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func favoriteBinding(for tip: Tip) -> Binding<Bool> {
        Binding(
            get: { favorites.contains(tip.id) },
            set: { isOn in
                var set = favorites
                if isOn { set.insert(tip.id) } else { set.remove(tip.id) }
                favoritesRaw = set.sorted().joined(separator: ",")
            }
        )
    }
}

private struct CategoryChip: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct TipRow: View {
    let tip: Tip
    let isFavorite: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.category.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tip.title).font(.headline)
                    if isFavorite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                    }
                }
                Text(tip.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct TipDetailView: View {
    let tip: Tip
    @Binding var isFavorite: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Label(tip.category.title, systemImage: tip.category.systemImage)
                    Text("·")
                    Text(tip.level)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(tip.summary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Langkah").font(.headline)
                    ForEach(Array(tip.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor, in: Circle())
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let mistake = tip.mistake {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Kesalahan umum", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(mistake)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(tip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(isFavorite ? "Hapus dari favorit" : "Simpan ke favorit")
            }
        }
    }
}
