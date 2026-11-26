import Foundation
import SwiftData

/// Satu ronde golf. Disimpan di iPhone dengan SwiftData.
@Model
final class Round {
    var date: Date
    var courseName: String
    /// Par tiap hole.
    var pars: [Int]
    /// Jumlah pukulan tiap hole. 0 = belum diisi.
    var strokes: [Int]
    /// Jumlah putt tiap hole.
    var putts: [Int]

    init(date: Date = .now, courseName: String, pars: [Int]) {
        self.date = date
        self.courseName = courseName
        self.pars = pars
        self.strokes = Array(repeating: 0, count: pars.count)
        self.putts = Array(repeating: 0, count: pars.count)
    }

    var holeCount: Int { pars.count }

    var holesPlayed: Int { strokes.filter { $0 > 0 }.count }

    var isComplete: Bool { holeCount > 0 && holesPlayed == holeCount }

    var totalStrokes: Int { strokes.reduce(0, +) }

    var totalPar: Int { pars.reduce(0, +) }

    var totalPutts: Int { putts.reduce(0, +) }

    /// Par dari hole yang sudah dimainkan saja.
    var playedPar: Int {
        zip(pars, strokes).filter { $0.1 > 0 }.reduce(0) { $0 + $1.0 }
    }

    /// Selisih skor terhadap par untuk hole yang sudah dimainkan.
    var toPar: Int { totalStrokes - playedPar }

    var handicapEntry: HandicapCalculator.Entry? {
        guard isComplete else { return nil }
        return HandicapCalculator.Entry(date: date, strokes: totalStrokes, par: totalPar, holes: holeCount)
    }
}
