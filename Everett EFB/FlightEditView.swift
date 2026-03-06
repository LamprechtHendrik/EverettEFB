import SwiftUI
import SwiftData

struct FlightEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\CrewMember.surname), SortDescriptor(\CrewMember.name)])
    private var crew: [CrewMember]

    @Query(sort: [SortDescriptor(\Aircraft.registration)])
    private var aircraft: [Aircraft]

    @Bindable var flight: Flight

    @State private var reportNumber = ""
    @State private var aircraftReg = ""
    @State private var pic = ""
    @State private var sic = ""
    @State private var cabinCrew = ""
    @State private var client = ""

    var body: some View {
        Form {
            Section("Flight") {
                TextField("Flight report number", text: $reportNumber)
                    .textInputAutocapitalization(.characters)

                Picker("Aircraft reg", selection: $aircraftReg) {
                    Text("Select…").tag("")
                    ForEach(aircraftRegs, id: \.self) { reg in
                        Text(reg).tag(reg)
                    }
                }

                Picker("PIC (Pilot)", selection: $pic) {
                    Text("Select…").tag("")
                    ForEach(pilotNames, id: \.self) { n in
                        Text(n).tag(n)
                    }
                }

                Picker("FO / SIC (Pilot)", selection: $sic) {
                    Text("Select…").tag("")
                    ForEach(pilotNames, id: \.self) { n in
                        Text(n).tag(n)
                    }
                }

                Picker("Cabin crew", selection: $cabinCrew) {
                    Text("Select…").tag("")
                    ForEach(cabinNames, id: \.self) { n in
                        Text(n).tag(n)
                    }
                }

                TextField("Client", text: $client)
            }
        }
        .navigationTitle("Edit Flight")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            reportNumber = flight.reportNumber
            aircraftReg = flight.aircraftReg
            pic = flight.pic
            sic = flight.sic
            cabinCrew = flight.cabinCrew
            client = flight.client

            if aircraftReg.isEmpty { aircraftReg = aircraftRegs.first ?? "" }
        }
    }

    private var aircraftRegs: [String] {
        aircraft.map { $0.registration.uppercased() }.sorted()
    }

    private var pilotNames: [String] {
        crew.filter { $0.role == .pilot }.map { "\($0.surname), \($0.name)" }.sorted()
    }

    private var cabinNames: [String] {
        crew.filter { $0.role == .cabinCrew }.map { "\($0.surname), \($0.name)" }.sorted()
    }

    private var canSave: Bool {
        !reportNumber.trimmed.isEmpty &&
        !aircraftReg.trimmed.isEmpty &&
        !pic.trimmed.isEmpty
    }

    private func save() {
        flight.reportNumber = reportNumber.trimmedUpper
        flight.aircraftReg = aircraftReg.trimmedUpper
        flight.pic = pic.trimmed
        flight.sic = sic.trimmed
        flight.cabinCrew = cabinCrew.trimmed
        flight.client = client.trimmed

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Flight edit save failed:", error)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedUpper: String { trimmed.uppercased() }
}
