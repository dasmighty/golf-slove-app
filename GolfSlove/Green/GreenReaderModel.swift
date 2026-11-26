import ARKit
import SceneKit
import SwiftUI

enum GreenTool: String, CaseIterable, Identifiable {
    case scan, ball, hole

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scan: return "Pindai"
        case .ball: return "Bola"
        case .hole: return "Lubang"
        }
    }
}

enum ScanMode {
    /// iPhone Pro dengan sensor LiDAR: data kedalaman padat dan akurat.
    case lidar
    /// iPhone tanpa LiDAR: memakai titik fitur dari kamera, akurasi terbatas.
    case camera
    /// Perangkat tidak mendukung ARKit (misalnya Simulator).
    case unsupported
}

/// Mengatur sesi AR: mengumpulkan titik permukaan green, menganalisis kemiringan,
/// menerima ketukan untuk bola dan lubang, lalu menghitung saran putt.
final class GreenReaderModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var tool: GreenTool = .scan {
        didSet { hint = nil }
    }
    @Published var stimp: Double = 9 {
        didSet { solveIfReady() }
    }
    @Published private(set) var mode: ScanMode = GreenReaderModel.detectMode()
    @Published private(set) var scannedArea: Double = 0
    @Published private(set) var trackingMessage: String?
    @Published private(set) var hint: String?
    @Published private(set) var result: PuttResult?
    @Published private(set) var isSolving = false
    @Published private(set) var hasBall = false
    @Published private(set) var hasHole = false

    private weak var sceneView: ARSCNView?
    private let overlay = GreenOverlay()
    private let queue = DispatchQueue(label: "golfslove.green", qos: .userInitiated)
    private static let cellSize = 0.2

    // Hanya diakses dari `queue`.
    private var field = HeightField(cellSize: GreenReaderModel.cellSize)

    // Hanya diakses dari main thread.
    private var map = SlopeMap.empty
    private var frameCounter = 0
    private var lastAnalysis = Date.distantPast
    private var analysisPending = false
    private var isRunning = false
    private var ballPos: SIMD3<Float>?
    private var holePos: SIMD3<Float>?
    private var solveGeneration = 0
    private var resetGeneration = 0

    private static func detectMode() -> ScanMode {
        if !ARWorldTrackingConfiguration.isSupported { return .unsupported }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { return .lidar }
        return .camera
    }

    var instruction: String {
        if let hint { return hint }
        switch tool {
        case .scan:
            if scannedArea < 1 {
                return "Pegang iPhone ±1 m di atas rumput, arahkan ke green, lalu berjalan pelan di antara bola dan lubang."
            }
            return "Bagus! Pindai sampai area bola dan lubang berwarna, lalu pilih Bola."
        case .ball:
            return "Ketuk layar tepat di posisi bola."
        case .hole:
            return "Ketuk layar tepat di posisi lubang."
        }
    }

    // MARK: - Sesi

    func attach(_ view: ARSCNView) {
        sceneView = view
        view.session.delegate = self
        view.scene.rootNode.addChildNode(overlay.root)
        view.automaticallyUpdatesLighting = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        start(reset: false)
    }

    func resume() {
        if !isRunning { start(reset: false) }
    }

    func pause() {
        sceneView?.session.pause()
        isRunning = false
    }

    private func start(reset: Bool) {
        guard let view = sceneView, mode != .unsupported else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravity
        if mode == .lidar {
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                config.frameSemantics.insert(.smoothedSceneDepth)
            } else {
                config.frameSemantics.insert(.sceneDepth)
            }
        }
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        view.session.run(config, options: options)
        isRunning = true
    }

    func reset() {
        queue.async { [weak self] in
            self?.field = HeightField(cellSize: GreenReaderModel.cellSize)
        }
        solveGeneration += 1
        resetGeneration += 1
        map = .empty
        scannedArea = 0
        ballPos = nil
        holePos = nil
        hasBall = false
        hasHole = false
        result = nil
        isSolving = false
        tool = .scan
        overlay.clear()
        start(reset: true)
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        frameCounter += 1
        guard tool == .scan, frameCounter % 2 == 0 else { return }
        if case .normal = frame.camera.trackingState {} else { return }

        let points = mode == .lidar ? Self.depthPoints(frame) : Self.featurePoints(frame)
        if !points.isEmpty {
            queue.async { [weak self] in
                guard let self else { return }
                for p in points {
                    self.field.add(x: Double(p.x), y: Double(p.y), z: Double(p.z))
                }
            }
        }
        if !analysisPending && Date().timeIntervalSince(lastAnalysis) > 1.0 {
            runAnalysis()
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            trackingMessage = nil
        case .notAvailable:
            trackingMessage = "Pelacakan kamera belum tersedia."
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                trackingMessage = "Gerakkan iPhone lebih pelan."
            case .insufficientFeatures:
                trackingMessage = "Permukaan kurang terlihat. Coba sudut lain atau cahaya lebih terang."
            case .initializing, .relocalizing:
                trackingMessage = "Menyiapkan kamera..."
            @unknown default:
                trackingMessage = "Pelacakan terbatas."
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        trackingMessage = "Sesi AR gagal: \(error.localizedDescription)"
        isRunning = false
    }

    // MARK: - Analisis

    private func runAnalysis() {
        analysisPending = true
        lastAnalysis = Date()
        let minCount = mode == .lidar ? 20 : 3
        let generation = resetGeneration
        queue.async { [weak self] in
            guard let self else { return }
            let m = self.field.analyze(minCount: minCount)
            DispatchQueue.main.async {
                self.analysisPending = false
                guard generation == self.resetGeneration else { return }
                self.map = m
                self.scannedArea = Double(m.samples.count) * m.cellSize * m.cellSize
                self.overlay.showSlopes(m)
                if self.hasBall && self.hasHole { self.solveIfReady() }
            }
        }
    }

    // MARK: - Ketukan

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = sceneView, tool != .scan else { return }
        guard let pos = worldPosition(at: gesture.location(in: view), in: view) else {
            hint = "Permukaan tidak ditemukan di titik itu. Pindai area tersebut lalu ketuk lagi."
            return
        }
        hint = nil
        switch tool {
        case .ball:
            ballPos = pos
            hasBall = true
            overlay.setBall(pos)
            if !hasHole { tool = .hole }
        case .hole:
            holePos = pos
            hasHole = true
            overlay.setHole(pos)
        case .scan:
            break
        }
        solveIfReady()
    }

    private func worldPosition(at point: CGPoint, in view: ARSCNView) -> SIMD3<Float>? {
        guard let query = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
              let hit = view.session.raycast(query).first else { return nil }
        let t = hit.worldTransform.columns.3
        var p = SIMD3<Float>(t.x, t.y, t.z)
        // Gunakan ketinggian dari hasil pemindaian bila ada, karena lebih akurat.
        if let s = map.sample(x: Double(p.x), z: Double(p.z)) {
            p.y = Float(s.height)
        }
        return p
    }

    // MARK: - Putt

    private func solveIfReady() {
        guard let b = ballPos, let h = holePos else { return }
        guard !map.isEmpty else {
            hint = "Pindai green dulu supaya kemiringannya bisa dihitung."
            return
        }
        solveGeneration += 1
        let generation = solveGeneration
        isSolving = true
        let simulator = PuttSimulator(map: map, stimp: stimp)
        let currentMap = map
        let ball = Vec2(x: Double(b.x), z: Double(b.z))
        let hole = Vec2(x: Double(h.x), z: Double(h.z))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = simulator.solve(ball: ball, hole: hole)
            DispatchQueue.main.async {
                guard let self, generation == self.solveGeneration else { return }
                self.isSolving = false
                self.result = r
                if r == nil {
                    self.hint = "Bola terlalu dekat dengan lubang, atau putt tidak bisa dihitung."
                }
                self.overlay.showPutt(r, map: currentMap)
            }
        }
    }

    // MARK: - Titik permukaan

    /// Mengubah peta kedalaman LiDAR menjadi titik 3D di koordinat dunia.
    private static func depthPoints(_ frame: ARFrame) -> [SIMD3<Float>] {
        guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return [] }
        let depthMap = depth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let w = CVPixelBufferGetWidth(depthMap)
        let h = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        var confBase: UnsafeMutableRawPointer?
        var confRowBytes = 0
        if let conf = depth.confidenceMap {
            CVPixelBufferLockBaseAddress(conf, .readOnly)
            confBase = CVPixelBufferGetBaseAddress(conf)
            confRowBytes = CVPixelBufferGetBytesPerRow(conf)
        }
        defer {
            if let conf = depth.confidenceMap { CVPixelBufferUnlockBaseAddress(conf, .readOnly) }
        }

        // Intrinsik kamera berlaku untuk gambar penuh; skalakan ke resolusi peta kedalaman.
        let res = frame.camera.imageResolution
        let sx = Float(w) / Float(res.width)
        let sy = Float(h) / Float(res.height)
        let k = frame.camera.intrinsics
        let fx = k[0][0] * sx, fy = k[1][1] * sy
        let cx = k[2][0] * sx, cy = k[2][1] * sy
        let transform = frame.camera.transform
        let cameraHeight = transform.columns.3.y
        let highConfidence = UInt8(ARConfidenceLevel.high.rawValue)

        var out: [SIMD3<Float>] = []
        out.reserveCapacity(w * h / 16)
        for v in stride(from: 0, to: h, by: 4) {
            let row = base.advanced(by: v * rowBytes).assumingMemoryBound(to: Float32.self)
            let confRow = confBase?.advanced(by: v * confRowBytes).assumingMemoryBound(to: UInt8.self)
            for u in stride(from: 0, to: w, by: 4) {
                if let confRow, confRow[u] < highConfidence { continue }
                let d = row[u]
                guard d > 0.25, d < 5 else { continue }
                // Koordinat kamera ARKit: x kanan, y atas, -z ke depan.
                let pc = SIMD4<Float>((Float(u) - cx) * d / fx, -(Float(v) - cy) * d / fy, -d, 1)
                let pw = transform * pc
                // Hanya titik di bawah iPhone (permukaan tanah).
                guard pw.y < cameraHeight - 0.3 else { continue }
                out.append(SIMD3<Float>(pw.x, pw.y, pw.z))
            }
        }
        return out
    }

    /// Titik fitur kamera untuk iPhone tanpa LiDAR.
    private static func featurePoints(_ frame: ARFrame) -> [SIMD3<Float>] {
        guard let pts = frame.rawFeaturePoints?.points else { return [] }
        let cameraHeight = frame.camera.transform.columns.3.y
        return pts.filter { $0.y < cameraHeight - 0.3 }
    }
}
