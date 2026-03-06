import Foundation

extension Airport {
    var outputIATAOrICAO: String {
        if !iata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return iata.uppercased()
        }
        return icao.uppercased()
    }
}
