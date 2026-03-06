import Foundation

extension CrewMember {
    var fullDisplayName: String {
        "\(surname), \(name)"
    }
}

extension Airport {
    var preferredCode: String {
        if !icao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return icao.uppercased()
        }
        return iata.uppercased()
    }

    var searchBlob: String {
        "\(icao) \(iata) \(name)".lowercased()
    }

    var secondaryDisplay: String {
        "\(countryISO) • ICAO \(icao.isEmpty ? "-" : icao) • IATA \(iata.isEmpty ? "-" : iata)"
    }
}
