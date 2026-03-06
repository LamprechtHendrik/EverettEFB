import SwiftUI
import SwiftData

struct AirportSelectView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Airport.icao), SortDescriptor(\Airport.iata)])
    private var airports: [Airport]

    @State private var searchText: String = ""

    let title: String
    @Binding var selectedCode: String

    var body: some View {
        List {
            ForEach(filteredAirports) { a in
                Button {
                    selectedCode = airportCode(a)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(airportCode(a))  •  \(a.name)")
                            .font(.headline)

                        Text("\(a.countryISO)  •  ICAO \(a.icao.isEmpty ? "-" : a.icao)  •  IATA \(a.iata.isEmpty ? "-" : a.iata)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }

    private var filteredAirports: [Airport] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return airports }

        return airports.filter { a in
            a.name.lowercased().contains(q) ||
            a.icao.lowercased().contains(q) ||
            a.iata.lowercased().contains(q) ||
            airportCode(a).lowercased().contains(q)
        }
    }

    private func airportCode(_ a: Airport) -> String {
        // Prefer ICAO if present, otherwise IATA
        if !a.icao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return a.icao.uppercased()
        }
        return a.iata.uppercased()
    }
}
