import Foundation

struct AirportLookup {
    // Minimal starter set. Expand with your ops network.
    // Key: ICAO (preferred), fallback: IATA
    static let byICAO: [String: (Double, Double)] = [
        "FQMA": (-25.920836, 32.572606), // Maputo
        "FAOR": (-26.133693, 28.242317), // Johannesburg OR Tambo
        "FACT": (-33.969444, 18.597222)  // Cape Town
    ]

    static let byIATA: [String: (Double, Double)] = [
        "MPM": (-25.920836, 32.572606),
        "JNB": (-26.133693, 28.242317),
        "CPT": (-33.969444, 18.597222)
    ]

    static func coordinates(icao: String, iata: String) -> (Double, Double)? {
        let i = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let t = iata.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let hit = byICAO[i] { return hit }
        if let hit = byIATA[t] { return hit }
        return nil
    }
}
