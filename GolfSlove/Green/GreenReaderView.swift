import ARKit
import SwiftUI

/// Membungkus ARSCNView supaya bisa dipakai di SwiftUI.
struct ARGreenView: UIViewRepresentable {
    let model: GreenReaderModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        model.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct GreenReaderView: View {
    @StateObject private var model = GreenReaderModel()

    var body: some View {
        Group {
            if model.mode == .unsupported {
                ContentUnavailableView(
                    "AR tidak tersedia",
                    systemImage: "arkit",
                    description: Text("Fitur baca green perlu iPhone asli dengan kamera. Simulator tidak mendukung AR.")
                )
            } else {
                ZStack {
                    ARGreenView(model: model)
                        .ignoresSafeArea(edges: .top)
                    VStack(spacing: 12) {
                        statusPanel
                        Spacer()
                        if let r = model.result {
                            PuttResultCard(result: r, isSolving: model.isSolving)
                        } else if model.isSolving {
                            ProgressView("Menghitung putt...")
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        controls
                    }
                    .padding()
                }
            }
        }
        .onAppear { model.resume() }
        .onDisappear { model.pause() }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(model.mode == .lidar ? "LiDAR" : "Kamera",
                      systemImage: model.mode == .lidar ? "dot.radiowaves.left.and.right" : "camera")
                Spacer()
                Text("Terpindai \(model.scannedArea, specifier: "%.1f") m²")
            }
            .font(.caption.bold())

            Text(model.instruction)
                .font(.subheadline)

            if let msg = model.trackingMessage {
                Text(msg).font(.caption).foregroundStyle(.yellow)
            }
            if model.mode == .camera {
                Text("Mode kamera: akurasi terbatas. iPhone Pro dengan LiDAR memberi hasil jauh lebih baik.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            SlopeLegend()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Alat", selection: $model.tool) {
                ForEach(GreenTool.allCases) { tool in
                    Text(tool.label).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Stepper(value: $model.stimp, in: 6...14, step: 0.5) {
                    Text("Kecepatan green (Stimp) \(model.stimp, specifier: "%.1f")")
                        .font(.footnote)
                }
                Button(role: .destructive) {
                    model.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Ulangi pemindaian")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SlopeLegend: View {
    private struct Item: Identifiable {
        let label: String
        let percent: Double
        var id: String { label }
    }

    private let items = [
        Item(label: "<1%", percent: 0.5),
        Item(label: "1–2%", percent: 1.5),
        Item(label: "2–3%", percent: 2.5),
        Item(label: ">3%", percent: 3.5),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.color(GreenOverlay.color(percent: item.percent)))
                        .frame(width: 8, height: 8)
                    Text(item.label)
                }
            }
            Spacer()
            Label("arah turun", systemImage: "arrowtriangle.up.fill")
                .labelStyle(.titleAndIcon)
        }
        .font(.caption2)
    }

    static func color(_ c: SIMD4<Float>) -> Color {
        Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z))
    }
}

struct PuttResultCard: View {
    let result: PuttResult
    let isSolving: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saran putt").font(.headline)
                Spacer()
                if isSolving {
                    ProgressView()
                } else if !result.holed {
                    Text("perkiraan").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(aimText)
                .font(.title3.bold())
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Jarak").foregroundStyle(.secondary)
                    Text(String(format: "%.1f m", result.distance))
                }
                GridRow {
                    Text("Elevasi").foregroundStyle(.secondary)
                    Text(heightText)
                }
                GridRow {
                    Text("Kemiringan").foregroundStyle(.secondary)
                    Text(String(format: "rata-rata %.1f%%", result.averageSlopePercent))
                }
                GridRow {
                    Text("Kekuatan").foregroundStyle(.secondary)
                    Text(String(format: "seperti putt datar %.1f m", result.effectiveDistance))
                }
            }
            .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var aimText: String {
        let cm = abs(result.aimOffset) * 100
        if cm < 3 { return "Bidik tepat ke lubang" }
        let side = result.aimOffset > 0 ? "kanan" : "kiri"
        return "Bidik \(Int(cm.rounded())) cm ke \(side) lubang"
    }

    private var heightText: String {
        let cm = result.heightChange * 100
        if abs(cm) < 1 { return "datar" }
        return cm > 0 ? "menanjak \(Int(cm.rounded())) cm" : "menurun \(Int((-cm).rounded())) cm"
    }
}
