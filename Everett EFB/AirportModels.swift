import Foundation
import SwiftData

@Model
final class Airport {
    var icao: String
    var iata: String
    var name: String
    var countryISO: String
    var latitude: Double
    var longitude: Double
    var longestRunway: Int

    init(
        icao: String = "",
        iata: String = "",
        name: String = "",
        countryISO: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        longestRunway: Int = 0
    ) {
        self.icao = icao.uppercased()
        self.iata = iata.uppercased()
        self.name = name
        self.countryISO = countryISO.uppercased()
        self.latitude = latitude
        self.longitude = longitude
        self.longestRunway = longestRunway
    }

    var coordinateText: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
