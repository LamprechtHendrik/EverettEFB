import SwiftUI
import SwiftData

struct FlightFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\CrewMember.surname), SortDescriptor(\CrewMember.name)])
    private var crew: [CrewMember]

    @Query(sort: [SortDescriptor(\Aircraft.registration)])
    private var aircraft: [Aircraft]

    @Query(sort: [SortDescriptor(\Airport.icao), SortDescriptor(\Airport.iata)])
    private var airports: [Airport]

    // Flight-level fields
    @State private var reportNumber = ""
    @State private var aircraftReg = ""
    @State private var pic = ""
    @State private var sic = ""
    @State private var cabinCrew = ""
    @State private var client = ""

    // Dynamic legs
    @State private var legs: [LegDraft] = [LegDraft(sequence: 1)]

    var body: some View {
        Form {
            Section("Flight") {
                TextField("Flight report number", text: $reportNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                PredictiveSearchField(
                    title: "Aircraft reg",
                    text: $aircraftReg,
                    suggestions: filteredAircraft,
                    displayText: { $0.registration.uppercased() },
                    secondaryText: { "\($0.type) • MSN \($0.modelSerialNumber)" },
                    onSelect: { selected in
                        aircraftReg = selected.registration.uppercased()
                    }
                )

                PredictiveSearchField(
                    title: "PIC (Pilot)",
                    text: $pic,
                    suggestions: filteredPICCrew,
                    displayText: { $0.fullDisplayName },
                    secondaryText: { "Pilot • Lic \($0.licenseNumber)" },
                    onSelect: { selected in
                        pic = selected.fullDisplayName
                    }
                )

                PredictiveSearchField(
                    title: "FO / SIC (Pilot)",
                    text: $sic,
                    suggestions: filteredSICCrew,
                    displayText: { $0.fullDisplayName },
                    secondaryText: { "Pilot • Lic \($0.licenseNumber)" },
                    onSelect: { selected in
                        sic = selected.fullDisplayName
                    }
                )

                PredictiveSearchField(
                    title: "Cabin crew",
                    text: $cabinCrew,
                    suggestions: filteredCabinCrew,
                    displayText: { $0.fullDisplayName },
                    secondaryText: { _ in "Cabin Crew" },
                    onSelect: { selected in
                        cabinCrew = selected.fullDisplayName
                    }
                )

                TextField("Client", text: $client)
                    .autocorrectionDisabled()
            }

            Section("Legs") {
                ForEach($legs) { $leg in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Leg \(leg.sequence)")
                            .font(.headline)

                        DatePicker("Date", selection: $leg.date, displayedComponents: .date)

                        DatePicker("Departure time", selection: $leg.departureTime, displayedComponents: .hourAndMinute)

                        TextField("Call sign", text: $leg.callSign)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        PredictiveSearchField(
                            title: "Departure",
                            text: $leg.departure,
                            suggestions: filteredAirports(for: leg.departure),
                            displayText: { $0.preferredCode },
                            secondaryText: { "\($0.secondaryDisplay) • \($0.name)" },
                            onSelect: { selected in
                                leg.departure = selected.preferredCode
                            }
                        )

                        PredictiveSearchField(
                            title: "Destination",
                            text: $leg.destination,
                            suggestions: filteredAirports(for: leg.destination),
                            displayText: { $0.preferredCode },
                            secondaryText: { "\($0.secondaryDisplay) • \($0.name)" },
                            onSelect: { selected in
                                leg.destination = selected.preferredCode
                            }
                        )
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: deleteLegs)

                Button {
                    addLeg()
                } label: {
                    Label("Add leg", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Add Flight")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Filtering

    private var filteredAircraft: [Aircraft] {
        let q = aircraftReg.trimmed.lowercased()
        guard !q.isEmpty else { return Array(aircraft.prefix(8)) }

        return Array(
            aircraft.filter {
                $0.registration.lowercased().contains(q) ||
                $0.type.lowercased().contains(q) ||
                $0.modelSerialNumber.lowercased().contains(q)
            }
            .prefix(8)
        )
    }

    private var filteredPICCrew: [CrewMember] {
        filterCrew(query: pic, role: .pilot)
    }

    private var filteredSICCrew: [CrewMember] {
        filterCrew(query: sic, role: .pilot)
    }

    private var filteredCabinCrew: [CrewMember] {
        filterCrew(query: cabinCrew, role: .cabinCrew)
    }

    private func filterCrew(query: String, role: CrewRole) -> [CrewMember] {
        let q = query.trimmed.lowercased()
        let pool = crew.filter { $0.role == role }

        guard !q.isEmpty else { return Array(pool.prefix(8)) }

        return Array(
            pool.filter {
                $0.name.lowercased().contains(q) ||
                $0.surname.lowercased().contains(q) ||
                $0.fullDisplayName.lowercased().contains(q) ||
                $0.licenseNumber.lowercased().contains(q)
            }
            .prefix(8)
        )
    }

    private func filteredAirports(for query: String) -> [Airport] {
        let q = query.trimmed.lowercased()
        guard !q.isEmpty else { return Array(airports.prefix(8)) }

        return Array(
            airports.filter {
                $0.searchBlob.contains(q)
            }
            .prefix(8)
        )
    }

    // MARK: - Validation

    private var canSave: Bool {
        !reportNumber.trimmed.isEmpty &&
        !aircraftReg.trimmed.isEmpty &&
        !pic.trimmed.isEmpty &&
        legs.allSatisfy {
            !$0.departure.trimmed.isEmpty &&
            !$0.destination.trimmed.isEmpty
        }
    }

    // MARK: - Legs

    private func addLeg() {
        let next = (legs.map(\.sequence).max() ?? 0) + 1
        legs.append(LegDraft(sequence: next))
    }

    private func deleteLegs(at offsets: IndexSet) {
        legs.remove(atOffsets: offsets)
        for i in legs.indices {
            legs[i].sequence = i + 1
        }
    }

    // MARK: - Save

    private func save() {
        let flight = Flight(
            reportNumber: reportNumber.trimmedUpper,
            aircraftReg: aircraftReg.trimmedUpper,
            pic: pic.trimmed,
            sic: sic.trimmed,
            cabinCrew: cabinCrew.trimmed,
            client: client.trimmed,
            isClosed: false
        )

        let sortedDrafts = legs.sorted(by: { $0.sequence < $1.sequence })
        for d in sortedDrafts {
            let leg = FlightLeg(
                sequence: d.sequence,
                date: d.date,
                departureTime: d.departureTime,
                callSign: d.callSign.trimmedUpper,
                departure: d.departure.trimmedUpper,
                destination: d.destination.trimmedUpper
            )
            flight.legs.append(leg)
        }

        modelContext.insert(flight)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Flight save failed:", error)
        }
    }
}

// MARK: - Draft model

private struct LegDraft: Identifiable {
    let id = UUID()
    var sequence: Int
    var date: Date = Date()
    var departureTime: Date = Date()
    var callSign: String = ""
    var departure: String = ""
    var destination: String = ""
}

// MARK: - String helpers

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedUpper: String {
        trimmed.uppercased()
    }
}
