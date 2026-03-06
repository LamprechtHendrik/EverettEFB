import Foundation
import SwiftData

enum AirportSeeder {

    static let seededKey = "airport_database_seeded_v4"

    static let allowedCountries: Set<String> = ["BW","KE","MZ","NA","TZ","ZA","ZW"]

    // 1300 meters in feet (rounded up)
    static let minRunwayFeet: Int = 4265

    static func seedIfNeeded(modelContext: ModelContext) {

        if UserDefaults.standard.bool(forKey: seededKey) {
            print("ℹ️ Airports already seeded.")
            return
        }

        guard
            let airportsURL = Bundle.main.url(forResource: "airports", withExtension: "csv"),
            let runwaysURL = Bundle.main.url(forResource: "runways", withExtension: "csv")
        else {
            print("❌ Missing airports.csv or runways.csv in app bundle. Check Target Membership.")
            return
        }

        do {
            let airportsText = try String(contentsOf: airportsURL, encoding: .utf8)
            let runwaysText = try String(contentsOf: runwaysURL, encoding: .utf8)

            let airportsRows = parseCSV(airportsText)
            let runwaysRows = parseCSV(runwaysText)

            print("ℹ️ Parsed airports rows:", airportsRows.count)
            print("ℹ️ Parsed runways rows:", runwaysRows.count)

            // OurAirports airports.csv indices:
            // 0 id
            // 1 ident
            // 3 name
            // 4 latitude_deg
            // 5 longitude_deg
            // 8 iso_country
            // 13 iata_code

            // OurAirports runways.csv indices:
            // 1 airport_ref (matches airports.id)
            // 3 length_ft
            // 5 surface

            // Map airport_id -> longest paved runway length_ft
            var longestPavedRunwayByAirportID: [String: Int] = [:]

            for row in runwaysRows.dropFirst() {
                guard row.count > 5 else { continue }

                let airportRef = row[1].trim
                let lengthFt = Int(row[3].trim) ?? 0
                let surface = row[5].trim.lowercased()

                guard !airportRef.isEmpty else { continue }
                guard lengthFt >= minRunwayFeet else { continue }
                guard isPaved(surface) else { continue }

                let current = longestPavedRunwayByAirportID[airportRef] ?? 0
                if lengthFt > current {
                    longestPavedRunwayByAirportID[airportRef] = lengthFt
                }
            }

            print("ℹ️ Airports with qualifying runway:", longestPavedRunwayByAirportID.count)

            var inserted = 0

            for row in airportsRows.dropFirst() {
                guard row.count > 13 else { continue } // only need up to iata_code at index 13

                let id = row[0].trim
                let ident = row[1].trim.uppercased()
                let name = row[3].trim
                let lat = Double(row[4].trim)
                let lon = Double(row[5].trim)
                let country = row[8].trim.uppercased()
                let iata = row[13].trim.uppercased()

                guard allowedCountries.contains(country) else { continue }
                guard let longestFt = longestPavedRunwayByAirportID[id] else { continue }
                guard !ident.isEmpty else { continue }
                guard let latitude = lat, let longitude = lon else { continue }

                let airport = Airport(
                    icao: ident,
                    iata: iata,
                    name: name,
                    countryISO: country,
                    latitude: latitude,
                    longitude: longitude,
                    longestRunway: longestFt
                )

                modelContext.insert(airport)
                inserted += 1
            }

            try modelContext.save()
            UserDefaults.standard.set(true, forKey: seededKey)

            print("✅ Seeded airports: \(inserted) (countries: \(allowedCountries.sorted()), runway >1300m paved)")

        } catch {
            print("❌ Airport seed failed:", error)
        }
    }

    private static func isPaved(_ surface: String) -> Bool {
        // Common OurAirports surface values include ASP, CON, asphalt, concrete, etc.
        let s = surface.lowercased()
        return s.contains("asp") || s.contains("con") || s.contains("asphalt") || s.contains("concrete") || s.contains("paved")
    }

    // Robust CSV parser (handles quoted commas)
    private static func parseCSV(_ text: String) -> [[String]] {
        var result: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]

            if c == "\"" {
                let next = text.index(after: i)
                if inQuotes, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if (c == "\n" || c == "\r") && !inQuotes {
                if c == "\r" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\n" {
                        i = next
                    }
                }
                row.append(field)
                field = ""
                if !(row.count == 1 && row[0].isEmpty) {
                    result.append(row)
                }
                row = []
            } else {
                field.append(c)
            }

            i = text.index(after: i)
        }

        row.append(field)
        if !(row.count == 1 && row[0].isEmpty) {
            result.append(row)
        }

        return result
    }
}

private extension String {
    var trim: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
