import SceneKit
import UIKit
import simd

/// Gambar AR di atas green: ubin warna kemiringan, panah arah turun, bola, lubang, dan jalur putt.
final class GreenOverlay {
    let root = SCNNode()
    private let slopeNode = SCNNode()
    private let puttNode = SCNNode()
    private let ballNode: SCNNode
    private let holeNode: SCNNode

    init() {
        let ball = SCNSphere(radius: 0.021)
        ball.firstMaterial = Self.flatMaterial(.white)
        ballNode = SCNNode(geometry: ball)
        ballNode.isHidden = true

        holeNode = SCNNode()
        let cup = SCNCylinder(radius: 0.054, height: 0.004)
        cup.firstMaterial = Self.flatMaterial(.black)
        holeNode.addChildNode(SCNNode(geometry: cup))
        let pole = SCNCylinder(radius: 0.004, height: 0.6)
        pole.firstMaterial = Self.flatMaterial(.systemYellow)
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, 0.3, 0)
        holeNode.addChildNode(poleNode)
        let flag = SCNPlane(width: 0.15, height: 0.1)
        flag.firstMaterial = Self.flatMaterial(.systemRed)
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(0.075, 0.55, 0)
        flagNode.constraints = [SCNBillboardConstraint()]
        holeNode.addChildNode(flagNode)
        holeNode.isHidden = true

        slopeNode.opacity = 0.6
        root.addChildNode(slopeNode)
        root.addChildNode(puttNode)
        root.addChildNode(ballNode)
        root.addChildNode(holeNode)
    }

    func clear() {
        slopeNode.geometry = nil
        puttNode.childNodes.forEach { $0.removeFromParentNode() }
        ballNode.isHidden = true
        holeNode.isHidden = true
    }

    func setBall(_ p: SIMD3<Float>?) {
        guard let p else { ballNode.isHidden = true; return }
        ballNode.simdPosition = p + SIMD3<Float>(0, 0.021, 0)
        ballNode.isHidden = false
    }

    func setHole(_ p: SIMD3<Float>?) {
        guard let p else { holeNode.isHidden = true; return }
        holeNode.simdPosition = p
        holeNode.isHidden = false
    }

    // MARK: - Peta kemiringan

    static func color(percent: Double) -> SIMD4<Float> {
        switch percent {
        case ..<1: return SIMD4(0.20, 0.80, 0.35, 1)  // hijau: hampir datar
        case ..<2: return SIMD4(0.95, 0.85, 0.20, 1)  // kuning
        case ..<3: return SIMD4(1.00, 0.55, 0.10, 1)  // oranye
        default: return SIMD4(0.90, 0.20, 0.20, 1)    // merah: curam
        }
    }

    func showSlopes(_ map: SlopeMap) {
        var verts: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var idx: [UInt32] = []
        let cs = Float(map.cellSize)
        let inset = cs * 0.06
        let white = SIMD4<Float>(1, 1, 1, 1)

        for (k, s) in map.samples {
            let cx = (Float(k.i) + 0.5) * cs
            let cz = (Float(k.j) + 0.5) * cs
            let gx = Float(s.gx), gz = Float(s.gz)
            let h = Float(s.height)
            func y(_ x: Float, _ z: Float, lift: Float) -> Float {
                h + gx * (x - cx) + gz * (z - cz) + lift
            }

            // Ubin mengikuti kemiringan lokal.
            let x0 = Float(k.i) * cs + inset, x1 = Float(k.i + 1) * cs - inset
            let z0 = Float(k.j) * cs + inset, z1 = Float(k.j + 1) * cs - inset
            let base = UInt32(verts.count)
            for (x, z) in [(x0, z0), (x1, z0), (x1, z1), (x0, z1)] {
                verts.append(SCNVector3(x, y(x, z, lift: 0.008), z))
            }
            let col = Self.color(percent: s.percent)
            colors += [col, col, col, col]
            idx += [base, base + 1, base + 2, base, base + 2, base + 3]

            // Panah menunjuk ke arah turun (ke mana bola akan berbelok).
            guard s.percent > 0.3 else { continue }
            let dir = simd_normalize(SIMD2<Float>(-gx, -gz))
            let perp = SIMD2<Float>(-dir.y, dir.x)
            let len = cs * 0.7, halfWidth = cs * 0.18
            let c = SIMD2<Float>(cx, cz)
            let tip = c + dir * (len * 0.5)
            let back = c - dir * (len * 0.5)
            let a = base + 4
            for p in [tip, back + perp * halfWidth, back - perp * halfWidth] {
                verts.append(SCNVector3(p.x, y(p.x, p.y, lift: 0.012), p.y))
                colors.append(white)
            }
            idx += [a, a + 1, a + 2]
        }
        slopeNode.geometry = Self.makeGeometry(vertices: verts, colors: colors, indices: idx)
    }

    // MARK: - Jalur putt

    func showPutt(_ result: PuttResult?, map: SlopeMap) {
        puttNode.childNodes.forEach { $0.removeFromParentNode() }
        guard let r = result else { return }
        let baseHeight = map.sample(x: r.ball.x, z: r.ball.z)?.height ?? 0
        func p3(_ v: Vec2, lift: Float) -> SIMD3<Float> {
            let h = map.sample(x: v.x, z: v.z)?.height ?? baseHeight
            return SIMD3<Float>(Float(v.x), Float(h) + lift, Float(v.z))
        }

        // Garis bidik lurus dari bola ke titik bidik.
        let aimLine = (0...20).map { n -> SIMD3<Float> in
            let t = Double(n) / 20
            return p3(r.ball + (r.aimPoint - r.ball) * t, lift: 0.012)
        }
        if let g = Self.ribbon(aimLine, width: 0.012, color: SIMD4(1, 1, 1, 1)) {
            puttNode.addChildNode(SCNNode(geometry: g))
        }

        // Lintasan bola yang melengkung.
        if let g = Self.ribbon(r.path.map { p3($0, lift: 0.016) }, width: 0.03, color: SIMD4(1, 0.85, 0.1, 1)) {
            puttNode.addChildNode(SCNNode(geometry: g))
        }

        // Penanda titik bidik.
        let marker = SCNCylinder(radius: 0.006, height: 0.25)
        marker.firstMaterial = Self.flatMaterial(.systemRed)
        let markerNode = SCNNode(geometry: marker)
        markerNode.simdPosition = p3(r.aimPoint, lift: 0.125)
        puttNode.addChildNode(markerNode)
    }

    // MARK: - Pembuat geometri

    static func flatMaterial(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.isDoubleSided = true
        return m
    }

    static func makeGeometry(vertices: [SCNVector3], colors: [SIMD4<Float>], indices: [UInt32]) -> SCNGeometry? {
        guard !indices.isEmpty else { return nil }
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        geometry.materials = [flatMaterial(.white)]
        return geometry
    }

    /// Pita tipis yang mengikuti titik-titik, untuk menggambar garis yang terlihat jelas.
    static func ribbon(_ pts: [SIMD3<Float>], width: Float, color: SIMD4<Float>) -> SCNGeometry? {
        guard pts.count >= 2 else { return nil }
        var verts: [SCNVector3] = []
        var idx: [UInt32] = []
        for (n, p) in pts.enumerated() {
            let a = pts[max(n - 1, 0)], b = pts[min(n + 1, pts.count - 1)]
            var d = SIMD2<Float>(b.x - a.x, b.z - a.z)
            let len = simd_length(d)
            d = len > 1e-5 ? d / len : SIMD2<Float>(1, 0)
            let side = SIMD2<Float>(-d.y, d.x) * (width / 2)
            verts.append(SCNVector3(p.x + side.x, p.y, p.z + side.y))
            verts.append(SCNVector3(p.x - side.x, p.y, p.z - side.y))
            if n > 0 {
                let b0 = UInt32((n - 1) * 2)
                idx += [b0, b0 + 1, b0 + 2, b0 + 1, b0 + 3, b0 + 2]
            }
        }
        return makeGeometry(vertices: verts, colors: Array(repeating: color, count: verts.count), indices: idx)
    }
}
