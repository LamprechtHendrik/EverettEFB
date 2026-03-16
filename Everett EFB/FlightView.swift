import SwiftUI
import SwiftData

struct FlightsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Flight> { $0.isClosed == false },
        sort: [SortDescriptor(\Flight.createdAt, order: .reverse)]
    )
    private var openFlights: [Flight]

    @State private var showAdd = false

    var body: some View {
        List {
            LogoView()

            if openFlights.isEmpty {
                ContentUnavailableView(
                    "No open flights",
                    systemImage: "airplane",
                    description: Text("Tap + to add your first flight.")
                )
            } else {
                ForEach(openFlights) { flight in
                    NavigationLink {
                        FlightDetailView(flight: flight)
                    } label: {
                        FlightRow(flight: flight)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Flights")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                FlightFormView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(openFlights[idx])
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Delete flight failed:", error)
        }
    }
}

private struct FlightRow: View {
    let flight: Flight

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(flight.displayDate.efbDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("FRN \(flight.reportNumber)")
                    .font(.headline)

                Text("\(flight.aircraftReg) • PIC: \(flight.pic)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        FlightsView()
    }
    .modelContainer(for: [Flight.self, FlightLeg.self, FlightDaySign.self, LegDocument.self, LegDelayEntry.self], inMemory: true)
}
