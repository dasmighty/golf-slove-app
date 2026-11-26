import Foundation

/// Indeks sel pada grid horizontal (sumbu x dan z dunia ARKit; y = ke atas).
struct GridKey: Hashable {
    let i: Int
    let j: Int
}

/// Bidang miring y = a·x + b·z + c. (a, b) adalah gradien: arah naik tercuram.
struct SlopePlane {
    let a: Double
    let b: Double
    let c: Double

    func height(x: Double, z: Double) -> Double { a * x + b * z + c }

    /// Kuadrat terkecil berbobot untuk titik (x, z, y, bobot).
    static func fit(_ pts: [(x: Double, z: Double, y: Double, w: Double)]) -> SlopePlane? {
        guard pts.count >= 3 else { return nil }
        var sw = 0.0, mx = 0.0, mz = 0.0, my = 0.0
        for p in pts {
            sw += p.w; mx += p.w * p.x; mz += p.w * p.z; my += p.w * p.y
        }
        guard sw > 0 else { return nil }
        mx /= sw; mz /= sw; my /= sw
        var sxx = 0.0, szz = 0.0, sxz = 0.0, sxy = 0.0, szy = 0.0
        for p in pts {
            let dx = p.x - mx, dz = p.z - mz, dy = p.y - my
            sxx += p.w * dx * dx
            szz += p.w * dz * dz
            sxz += p.w * dx * dz
            sxy += p.w * dx * dy
            szy += p.w * dz * dy
        }
        let det = sxx * szz - sxz * sxz
        // Titik yang segaris tidak cukup untuk menentukan bidang.
        guard det > 1e-12, det > 1e-6 * sxx * szz else { return nil }
        let a = (sxy * szz - sxz * szy) / det
        let b = (sxx * szy - sxz * sxy) / det
        return SlopePlane(a: a, b: b, c: my - a * mx - b * mz)
    }
}

/// Kemiringan halus di pusat satu sel.
struct SlopeSample {
    let height: Double
    let gx: Double
    let gz: Double

    /// Kemiringan dalam persen (1% = naik 1 cm tiap 1 m).
    var percent: Double { (gx * gx + gz * gz).squareRoot() * 100 }
}

/// Hasil analisis: kemiringan per sel yang bisa ditanyakan di titik mana pun.
struct SlopeMap {
    let cellSize: Double
    let samples: [GridKey: SlopeSample]
    let globalPlane: SlopePlane?

    static let empty = SlopeMap(cellSize: 0.2, samples: [:], globalPlane: nil)

    var isEmpty: Bool { samples.isEmpty }

    /// Ketinggian dan gradien di (x, z), diinterpolasi dari sel terdekat.
    /// Di luar area yang dipindai, dipakai bidang rata-rata seluruh green.
    func sample(x: Double, z: Double) -> (height: Double, gx: Double, gz: Double)? {
        let u = x / cellSize - 0.5
        let v = z / cellSize - 0.5
        let i0 = Int(floor(u)), j0 = Int(floor(v))
        let fu = u - Double(i0), fv = v - Double(j0)
        let corners: [(Int, Int, Double)] = [
            (0, 0, (1 - fu) * (1 - fv)),
            (1, 0, fu * (1 - fv)),
            (0, 1, (1 - fu) * fv),
            (1, 1, fu * fv),
        ]
        var h = 0.0, gx = 0.0, gz = 0.0, wsum = 0.0
        for (di, dj, w) in corners {
            if let s = samples[GridKey(i: i0 + di, j: j0 + dj)] {
                h += w * s.height; gx += w * s.gx; gz += w * s.gz; wsum += w
            }
        }
        if wsum > 0.05 {
            return (h / wsum, gx / wsum, gz / wsum)
        }
        if let g = globalPlane {
            return (g.height(x: x, z: z), g.a, g.b)
        }
        return nil
    }
}

/// Mengumpulkan titik 3D permukaan green ke dalam grid dan menghitung kemiringannya.
struct HeightField {
    struct Cell {
        var mean: Double = 0
        var count: Int = 0
    }

    let cellSize: Double
    private(set) var cells: [GridKey: Cell] = [:]
    private(set) var totalPoints = 0
    /// Setelah batas ini, sel memakai rata-rata bergerak supaya tetap mengikuti data baru.
    let maxPerCell = 400

    init(cellSize: Double = 0.2) {
        self.cellSize = cellSize
    }

    func key(x: Double, z: Double) -> GridKey {
        GridKey(i: Int(floor(x / cellSize)), j: Int(floor(z / cellSize)))
    }

    func center(_ k: GridKey) -> (x: Double, z: Double) {
        ((Double(k.i) + 0.5) * cellSize, (Double(k.j) + 0.5) * cellSize)
    }

    mutating func add(x: Double, y: Double, z: Double) {
        let k = key(x: x, z: z)
        var cell = cells[k] ?? Cell()
        // Buang titik yang jauh dari rata-rata sel: kaki, tongkat, bendera, bola.
        if cell.count >= 8 && abs(y - cell.mean) > 0.08 { return }
        if cell.count >= maxPerCell {
            cell.mean += (y - cell.mean) / Double(maxPerCell)
        } else {
            cell.count += 1
            cell.mean += (y - cell.mean) / Double(cell.count)
        }
        cells[k] = cell
        totalPoints += 1
    }

    /// Menghitung kemiringan halus untuk tiap sel yang cukup datanya.
    /// - Parameters:
    ///   - minCount: jumlah titik minimal agar sel dipercaya.
    ///   - radiusCells: radius tetangga (dalam sel) untuk penghalusan.
    func analyze(minCount: Int, radiusCells r: Int = 2) -> SlopeMap {
        let good = cells.filter { $0.value.count >= minCount }
        let global = SlopePlane.fit(good.map { entry in
            let p = center(entry.key)
            return (x: p.x, z: p.z, y: entry.value.mean, w: 1.0)
        })

        var samples: [GridKey: SlopeSample] = [:]
        for (k, c) in good {
            var pts: [(x: Double, z: Double, y: Double, w: Double)] = []
            for di in -r...r {
                for dj in -r...r {
                    let nk = GridKey(i: k.i + di, j: k.j + dj)
                    guard let nc = good[nk] else { continue }
                    let p = center(nk)
                    let dist2 = Double(di * di + dj * dj)
                    let w = exp(-dist2 / Double(max(r * r, 1))) * min(Double(nc.count), 50)
                    pts.append((x: p.x, z: p.z, y: nc.mean, w: w))
                }
            }
            let cp = center(k)
            if pts.count >= 5, let plane = SlopePlane.fit(pts) {
                samples[k] = SlopeSample(height: plane.height(x: cp.x, z: cp.z), gx: plane.a, gz: plane.b)
            } else if let g = global {
                samples[k] = SlopeSample(height: c.mean, gx: g.a, gz: g.b)
            }
        }
        return SlopeMap(cellSize: cellSize, samples: samples, globalPlane: global)
    }
}
