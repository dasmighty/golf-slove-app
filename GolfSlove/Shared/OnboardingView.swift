import SwiftUI

/// Layar pembuka yang tampil sekali saat aplikasi pertama kali dibuka.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let systemImage: String
        let title: String
        let text: String
    }

    private let pages = [
        Page(systemImage: "scope",
             title: "Baca green dengan LiDAR",
             text: "Pindai green dengan iPhone, lihat kemiringannya dalam warna, lalu dapatkan titik bidik dan kekuatan putt."),
        Page(systemImage: "list.number",
             title: "Catat skor & handicap",
             text: "Isi skor dan putt per hole. Handicap Anda dihitung otomatis dari ronde-ronde terbaik."),
        Page(systemImage: "lightbulb",
             title: "Tips & trik",
             text: "Kumpulan tips driving, iron, short game, putting, dan strategi untuk menurunkan skor."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: pages[i].systemImage)
                            .font(.system(size: 80))
                            .foregroundStyle(.tint)
                        Text(pages[i].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[i].text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Lanjut" : "Mulai")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Text("Alat ukur kemiringan tidak boleh dipakai di kompetisi resmi (Rules of Golf 4.3). Gunakan untuk latihan dan ronde santai.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }
}
