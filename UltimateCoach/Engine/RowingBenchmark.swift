import Foundation

struct RowingBenchmark {
    let minutes: Int
    let previousMeters: Int
    let latestMeters: Int
    let previousDate: Date
    let latestDate: Date

    static func latest(in program: Program) -> Self? {
        struct Session: Hashable {
            let slot: Int
            let prescription: String
            let pace: String?
            let zone: String?
            let minutes: Int
        }

        let days = program.days.filter { $0.status == .finished && !$0.isDeload }.sorted {
            ($0.conditioning?.loggedAt ?? $0.finishedAt ?? .distantPast, $0.weekIdx, $0.dayIdx) >
                ($1.conditioning?.loggedAt ?? $1.finishedAt ?? .distantPast, $1.weekIdx, $1.dayIdx)
        }
        var latestBySession: [Session: (meters: Int, date: Date)] = [:]
        var result: Self?
        for day in days {
            guard let row = day.conditioning, row.type == "row",
                  let date = row.loggedAt ?? day.finishedAt, let minutes = row.loggedMinutes, minutes > 0,
                  let meters = row.loggedMeters, meters > 0,
                  case .single(.time) = RowingPrescription(row.protocolText)?.workout else { continue }
            let session = Session(slot: day.dayIdx, prescription: row.protocolText, pace: row.targetPace,
                                  zone: row.targetZone, minutes: minutes)
            if let latest = latestBySession[session] {
                if latest.date > (result?.latestDate ?? .distantPast) {
                    result = Self(minutes: minutes, previousMeters: meters, latestMeters: latest.meters,
                                  previousDate: date, latestDate: latest.date)
                }
            } else {
                latestBySession[session] = (meters, date)
            }
        }
        return result
    }
}
