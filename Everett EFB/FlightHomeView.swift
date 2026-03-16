import SwiftUI
import SwiftData

struct FlightsHomeView: View {
    @Environment(\.modelContext) private var modelContext

    // Open flights only
    @Query(filter: #Predicate<Flight> { $0.isClosed == false },
           sort: [SortDescriptor(\Flight.createdAt, order: .reverse)])
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
                ForEach(openFlights) { f in
                    NavigationLink {
                        FlightDetailView(flight: f)
                    } label: {
                        FlightRow(flight: f)
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
        do { try modelContext.save() } catch {
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
