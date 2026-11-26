import Foundation

/// Vektor 2D di bidang horizontal (x, z).
struct Vec2: Equatable {
    var x: Double
    var z: Double

    static let zero = Vec2(x: 0, z: 0)

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x + b.x, z: a.z + b.z) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x - b.x, z: a.z - b.z) }
    static func * (a: Vec2, s: Double) -> Vec2 { Vec2(x: a.x * s, z: a.z * s) }

    var length: Double { (x * x + z * z).squareRoot() }
    func dot(_ o: Vec2) -> Double { x * o.x + z * o.z }
    var normalized: Vec2 {
        let l = length
        return l > 1e-12 ? self * (1 / l) : .zero
    }
}

/// Saran putt dari posisi bola ke lubang.
struct PuttResult {
    let ball: Vec2
    let hole: Vec2
    /// Jarak bola ke lubang (m).
    let distance: Double
    /// Beda tinggi lubang terhadap bola (m). Positif = menanjak.
    let heightChange: Double
    /// Rata-rata kemiringan di sepanjang garis bola–lubang (%).
    let averageSlopePercent: Double
    /// Sudut bidik terhadap garis lurus ke lubang (radian). Positif = ke kanan.
    let aimAngle: Double
    /// Seberapa jauh titik bidik dari lubang, diukur di samping lubang (m). Positif = kanan.
    let aimOffset: Double
    /// Titik bidik di samping lubang.
    let aimPoint: Vec2
    /// Kekuatan pukulan dinyatakan sebagai jarak putt datar yang setara (m).
    let effectiveDistance: Double
    /// Lintasan bola hasil simulasi.
    let path: [Vec2]
    /// Apakah bola masuk dalam simulasi.
    let holed: Bool
}

/// Simulasi bola menggelinding di atas peta kemiringan.
///
/// Model: perlambatan gesek konstan yang diturunkan dari angka Stimpmeter, ditambah
/// percepatan gravitasi untuk bola menggelinding (5/7 · g · kemiringan).
struct PuttSimulator {
    static let g = 9.81
    static let holeRadius = 0.054
    /// Bola di Stimpmeter dilepas dengan kecepatan ±1,83 m/s.
    static let stimpReleaseSpeed = 1.83
    /// Bola yang lebih cepat dari ini akan melompati lubang.
    static let captureSpeed = 1.3
    /// Bola idealnya berhenti sekitar 30 cm melewati lubang.
    static let overshoot = 0.3

    let map: SlopeMap
    let deceleration: Double

    init(map: SlopeMap, stimp: Double) {
        self.map = map
        let rollDistance = max(stimp, 4) * 0.3048
        deceleration = Self.stimpReleaseSpeed * Self.stimpReleaseSpeed / (2 * rollDistance)
    }

    func gradient(at p: Vec2) -> Vec2 {
        guard let s = map.sample(x: p.x, z: p.z) else { return .zero }
        return Vec2(x: s.gx, z: s.gz)
    }

    struct Roll {
        var path: [Vec2]
        var end: Vec2
        var minHoleDistance: Double
        var holed: Bool
    }

    func roll(from start: Vec2, velocity v0: Vec2, hole: Vec2?, capture: Bool, recordPath: Bool) -> Roll {
        let dt = 0.004
        let slopeFactor = 5.0 / 7.0 * Self.g
        var p = start
        var v = v0
        var path: [Vec2] = recordPath ? [start] : []
        var lastRecorded = start
        var minD = Double.infinity
        var holed = false

        for _ in 0..<6000 {
            let gAcc = gradient(at: p) * (-slopeFactor)
            let speed = v.length
            if speed < deceleration * dt {
                // Bola hampir diam: tetap diam kecuali lereng cukup curam untuk menggerakkannya.
                let pull = gAcc.length
                if pull <= deceleration { break }
                v = gAcc.normalized * ((pull - deceleration) * dt)
            } else {
                v = v + (gAcc - v * (deceleration / speed)) * dt
            }
            p = p + v * dt

            if let h = hole {
                let d = (p - h).length
                if d < minD { minD = d }
                if capture && d < Self.holeRadius && v.length < Self.captureSpeed {
                    holed = true
                    p = h
                    break
                }
            }
            if recordPath && (p - lastRecorded).length > 0.03 {
                path.append(p)
                lastRecorded = p
            }
        }
        if recordPath { path.append(p) }
        return Roll(path: path, end: p, minHoleDistance: minD, holed: holed)
    }

    /// Mencari arah dan kekuatan pukulan agar bola melewati lubang.
    func solve(ball: Vec2, hole: Vec2) -> PuttResult? {
        let toHole = hole - ball
        let distance = toHole.length
        guard distance > 0.2 else { return nil }
        let dir = toHole * (1 / distance)
        let right = Vec2(x: -dir.z, z: dir.x)
        let target = distance + Self.overshoot

        func aimDir(_ th: Double) -> Vec2 { dir * cos(th) + right * sin(th) }

        func along(_ th: Double, _ speed: Double) -> Double {
            let r = roll(from: ball, velocity: aimDir(th) * speed, hole: nil, capture: false, recordPath: false)
            return (r.end - ball).dot(dir)
        }

        func speedFor(_ th: Double) -> Double? {
            var lo = 0.05, hi = 8.0
            guard along(th, hi) >= target else { return nil }
            for _ in 0..<22 {
                let mid = (lo + hi) / 2
                if along(th, mid) < target { lo = mid } else { hi = mid }
            }
            return (lo + hi) / 2
        }

        func evaluate(_ th: Double) -> (miss: Double, speed: Double)? {
            guard let s = speedFor(th) else { return nil }
            let r = roll(from: ball, velocity: aimDir(th) * s, hole: hole, capture: false, recordPath: false)
            return (r.minHoleDistance, s)
        }

        let deg = Double.pi / 180
        var best: (th: Double, miss: Double, speed: Double)?
        func consider(_ th: Double) {
            if let e = evaluate(th), e.miss < (best?.miss ?? .infinity) {
                best = (th, e.miss, e.speed)
            }
        }
        for k in -30...30 { consider(Double(k) * deg) }
        guard let coarse = best else { return nil }
        for k in -10...10 where k != 0 { consider(coarse.th + Double(k) * 0.1 * deg) }
        guard let chosen = best else { return nil }

        let finalRoll = roll(from: ball, velocity: aimDir(chosen.th) * chosen.speed, hole: hole, capture: true, recordPath: true)

        let hb = map.sample(x: ball.x, z: ball.z)?.height ?? 0
        let hh = map.sample(x: hole.x, z: hole.z)?.height ?? hb
        var slopeSum = 0.0
        let steps = 20
        for n in 0...steps {
            let q = ball + toHole * (Double(n) / Double(steps))
            slopeSum += gradient(at: q).length * 100
        }

        let offset = distance * tan(chosen.th)
        return PuttResult(
            ball: ball,
            hole: hole,
            distance: distance,
            heightChange: hh - hb,
            averageSlopePercent: slopeSum / Double(steps + 1),
            aimAngle: chosen.th,
            aimOffset: offset,
            aimPoint: hole + right * offset,
            effectiveDistance: chosen.speed * chosen.speed / (2 * deceleration),
            path: finalRoll.path,
            holed: finalRoll.holed
        )
    }
}
