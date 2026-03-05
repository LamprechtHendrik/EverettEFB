import SwiftUI
import SwiftData

struct AirportListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Airport.icao), SortDescriptor(\Airport.iata)])
    private var airports: [Airport]

    @State private var showAdd = false

    var body: some View {
        List {
            if airports.isEmpty {
                ContentUnavailableView(
                    "No Airports",
                    systemImage: "building.2",
                    description: Text("Tap + to add an airport.")
                )
            } else {
                ForEach(airports) { a in
                    NavigationLink {
                        AirportFormView(mode: .edit(a))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(a.icao) • \(a.iata.isEmpty ? "—" : a.iata)")
                                .font(.headline)

                            Text(a.coordinateText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { modelContext.delete(airports[i]) }
                }
            }
        }
        .navigationTitle("Airports")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { AirportFormView(mode: .add) }
        }
    }
}
