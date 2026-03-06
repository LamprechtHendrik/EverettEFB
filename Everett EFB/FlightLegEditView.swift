import SwiftUI
import SwiftData

struct FlightLegEditView: View {
    enum Mode { case add, edit }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var flight: Flight
    let leg: FlightLeg?
    let mode: Mode

    @State private var date: Date = Date()
    @State private var depTime: Date = Date()
    @State private var callSign: String = ""
    @State private var departure: String = ""
    @State private var destination: String = ""

    private enum AirportTarget: Identifiable {
        case dep, dest
        var id: Int { self == .dep ? 1 : 2 }
    }
    @State private var airportTarget: AirportTarget?

    var body: some View {
        Form {
            Section("Leg") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                DatePicker("Departure time", selection: $depTime, displayedComponents: .hourAndMinute)

                TextField("Call sign", text: $callSign)
                    .textInputAutocapitalization(.characters)

                HStack {
                    Text("Departure")
                    Spacer()
                    Button(departure.isEmpty ? "Select…" : departure) {
                        airportTarget = .dep
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Text("Destination")
                    Spacer()
                    Button(destination.isEmpty ? "Select…" : destination) {
                        airportTarget = .dest
                    }
                    .buttonStyle(.bordered)
                }
            }

            if mode == .edit {
                Section {
                    Button(role: .destructive) {
                        deleteThisLeg()
                    } label: {
                        Label("Delete leg", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(mode == .add ? "Add Leg" : "Edit Leg")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .sheet(item: $airportTarget) { t in
            NavigationStack {
                switch t {
                case .dep:
                    AirportSelectView(title: "Select Departure", selectedCode: $departure)
                case .dest:
                    AirportSelectView(title: "Select Destination", selectedCode: $destination)
                }
            }
        }
        .onAppear {
            if let leg {
                date = leg.date
                depTime = leg.departureTime
                callSign = leg.callSign
                departure = leg.departure
                destination = leg.destination
            } else {
                // sensible defaults for a new leg:
                date = flight.displayDate
            }
        }
    }

    private var canSave: Bool {
        !departure.trimmed.isEmpty && !destination.trimmed.isEmpty
    }

    private func save() {
        if let leg {
            leg.date = date
            leg.departureTime = depTime
            leg.callSign = callSign.trimmedUpper
            leg.departure = departure.trimmedUpper
            leg.destination = destination.trimmedUpper
        } else {
            let nextSeq = (flight.legs.map(\.sequence).max() ?? 0) + 1
            let newLeg = FlightLeg(
                sequence: nextSeq,
                date: date,
                departureTime: depTime,
                callSign: callSign.trimmedUpper,
                departure: departure.trimmedUpper,
                destination: destination.trimmedUpper
            )
            flight.legs.append(newLeg)
            modelContext.insert(newLeg)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Leg save failed:", error)
        }
    }

    private func deleteThisLeg() {
        guard let leg else { return }

        if let idx = flight.legs.firstIndex(where: { $0.persistentModelID == leg.persistentModelID }) {
            let removed = flight.legs.remove(at: idx)
            modelContext.delete(removed)
        }

        // resequence remaining
        let legs = flight.legs.sorted(by: { $0.sequence < $1.sequence })
        for (i, l) in legs.enumerated() { l.sequence = i + 1 }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Delete leg failed:", error)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedUpper: String { trimmed.uppercased() }
}
