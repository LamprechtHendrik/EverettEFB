import Foundation
import SwiftData

enum AirportAutoFill {
    static func findByICAO(_ icao: String, in context: ModelContext) -> Airport? {
        let key = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Airport>(
            predicate: #Predicate { $0.icao == key },
            sortBy: []
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func findByIATA(_ iata: String, in context: ModelContext) -> Airport? {
        let key = iata.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Airport>(
            predicate: #Predicate { $0.iata == key },
            sortBy: []
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// ICAO wins if both provided.
    static func findBestMatch(icao: String, iata: String, in context: ModelContext) -> Airport? {
        if let a = findByICAO(icao, in: context) { return a }
        if let a = findByIATA(iata, in: context) { return a }
        return nil
    }
}
