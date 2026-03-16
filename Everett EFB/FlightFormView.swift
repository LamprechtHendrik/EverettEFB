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
    @State private var flightType: FlightType = .nonScheduled

    // Compliance overrides
    @State private var aircraftNR: [String: Bool] = [:]
    @State private var picNR: [String: Bool] = [:]
    @State private var sicNR: [String: Bool] = [:]
    @State private var cabinNR: [String: Bool] = [:]

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

                if let selectedAircraft {
                    aircraftStatusRow(aircraft: selectedAircraft)

                    complianceIssueSection(
                        title: "Aircraft Documents",
                        issues: aircraftIssues(for: selectedAircraft),
                        overrides: $aircraftNR
                    )
                }

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

                if let selectedPIC {
                    crewStatusRow(title: "PIC Status", member: selectedPIC)

                    complianceIssueSection(
                        title: "PIC Documents",
                        issues: crewIssues(for: selectedPIC, prefix: "pic"),
                        overrides: $picNR
                    )
                }

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

                if let selectedSIC {
                    crewStatusRow(title: "SIC Status", member: selectedSIC)

                    complianceIssueSection(
                        title: "SIC Documents",
                        issues: crewIssues(for: selectedSIC, prefix: "sic"),
                        overrides: $sicNR
                    )
                }

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

                if let selectedCabinCrew {
                    crewStatusRow(title: "Cabin Crew Status", member: selectedCabinCrew)

                    complianceIssueSection(
                        title: "Cabin Crew Documents",
                        issues: crewIssues(for: selectedCabinCrew, prefix: "cabin"),
                        overrides: $cabinNR
                    )
                }

                TextField("Client", text: $client)

                Picker("Type of flight", selection: $flightType) {
                    ForEach(FlightType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            Section("Legs") {
                ForEach(legs.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Leg \(legs[index].sequence)")
                            .font(.headline)

                        DatePicker("Date", selection: $legs[index].date, displayedComponents: .date)

                        DatePicker("Departure time", selection: $legs[index].departureTime, displayedComponents: .hourAndMinute)

                        TextField("Call sign", text: $legs[index].callSign)

                        PredictiveSearchField(
                            title: "Departure",
                            text: $legs[index].departure,
                            suggestions: filteredAirports(for: legs[index].departure),
                            displayText: { $0.preferredCode },
                            secondaryText: { "\($0.secondaryDisplay) • \($0.name)" },
                            onSelect: { selected in
                                legs[index].departure = selected.preferredCode
                            }
                        )

                        PredictiveSearchField(
                            title: "Destination",
                            text: $legs[index].destination,
                            suggestions: filteredAirports(for: legs[index].destination),
                            displayText: { $0.preferredCode },
                            secondaryText: { "\($0.secondaryDisplay) • \($0.name)" },
                            onSelect: { selected in
                                legs[index].destination = selected.preferredCode
                            }
                        )
                    }
                }

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

    // MARK: Selected Aircraft

    private var selectedAircraft: Aircraft? {
        aircraft.first { $0.registration.lowercased() == aircraftReg.lowercased() }
    }

    private func aircraftStatusRow(aircraft: Aircraft) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Aircraft Status").font(.subheadline.weight(.semibold))
                Text("\(aircraft.type) • Reg \(aircraft.registration)")
                    .font(.caption)
            }

            Spacer()

            StatusBadge(status: aircraft.overallStatus(cautionDays: 30))
        }
    }

    // MARK: Selected Crew

    private var selectedPIC: CrewMember? { selectedCrewMember(named: pic, role: .pilot) }
    private var selectedSIC: CrewMember? { selectedCrewMember(named: sic, role: .pilot) }
    private var selectedCabinCrew: CrewMember? { selectedCrewMember(named: cabinCrew, role: .cabinCrew) }

    private func selectedCrewMember(named displayName: String, role: CrewRole) -> CrewMember? {
        crew.first { $0.role == role && $0.fullDisplayName.lowercased() == displayName.lowercased() }
    }

    private func crewStatusRow(title: String, member: CrewMember) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(member.role.rawValue) • Lic \(member.licenseNumber)")
                    .font(.caption)
            }

            Spacer()

            StatusBadge(status: member.overallStatus(cautionDays: 30))
        }
    }

    // MARK: Compliance Issues

    struct FlightComplianceIssue: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let status: ComplianceStatus
    }

    private func crewIssues(for member: CrewMember, prefix: String) -> [FlightComplianceIssue] {
        var issues: [FlightComplianceIssue] = []

        let recencyChecks: [(String, Bool)] = [
            ("Line training record", member.lineTrainingRecord),
            ("Line training report", member.lineTrainingReport),
            ("Induction checklist", member.inductionChecklist),
            ("CV", member.cv),
            ("Personal data sheet", member.personalDataSheet),
            ("Drug and alcohol policy", member.drugAndAlcoholPolicy),
            ("Internet usage policy", member.internetUsagePolicy)
        ]

        for (title, ok) in recencyChecks where !ok {
            issues.append(.init(id: "\(prefix)-rec-\(title)", title: title, subtitle: "Recency incomplete", status: .expired))
        }

        for training in member.trainings {
            let status = training.status()
            guard status == .expired else { continue }

            issues.append(.init(
                id: "\(prefix)-train-\(training.type.rawValue)",
                title: training.type.rawValue,
                subtitle: training.expiry?.formatted() ?? "No expiry",
                status: status
            ))
        }

        return issues
    }

    private func aircraftIssues(for aircraft: Aircraft) -> [FlightComplianceIssue] {
        aircraft.documents.compactMap { doc in
            let status = Compliance.status(forExpiry: doc.expiry)
            guard status == .expired else { return nil }

            return .init(
                id: "aircraft-\(doc.type.rawValue)",
                title: doc.type.rawValue,
                subtitle: doc.expiry?.formatted() ?? "No expiry",
                status: status
            )
        }
    }

    @ViewBuilder
    private func complianceIssueSection(
        title: String,
        issues: [FlightComplianceIssue],
        overrides: Binding<[String: Bool]>
    ) -> some View {
        if !issues.isEmpty {
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold))

                ForEach(issues) { issue in
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(issue.title).font(.subheadline)
                                Text(issue.subtitle).font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusBadge(status: issue.status)
                        }

                        Toggle("N/R for flight", isOn: Binding(
                            get: { overrides.wrappedValue[issue.id] ?? false },
                            set: { overrides.wrappedValue[issue.id] = $0 }
                        ))
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: Filtering

    private var filteredAircraft: [Aircraft] {
        let q = aircraftReg.lowercased()
        guard !q.isEmpty else { return Array(aircraft.prefix(8)) }

        return aircraft.filter {
            $0.registration.lowercased().contains(q) ||
            $0.type.lowercased().contains(q)
        }
    }

    private var filteredPICCrew: [CrewMember] { filterCrew(query: pic, role: .pilot) }
    private var filteredSICCrew: [CrewMember] { filterCrew(query: sic, role: .pilot) }
    private var filteredCabinCrew: [CrewMember] { filterCrew(query: cabinCrew, role: .cabinCrew) }

    private func filterCrew(query: String, role: CrewRole) -> [CrewMember] {
        let q = query.lowercased()
        let pool = crew.filter { $0.role == role }

        guard !q.isEmpty else { return Array(pool.prefix(8)) }

        return pool.filter {
            $0.name.lowercased().contains(q) ||
            $0.surname.lowercased().contains(q) ||
            $0.fullDisplayName.lowercased().contains(q)
        }
    }

    private func filteredAirports(for query: String) -> [Airport] {
        let q = query.lowercased()
        guard !q.isEmpty else { return Array(airports.prefix(8)) }

        return airports.filter { $0.searchBlob.contains(q) }
    }

    // MARK: Validation

    private var canSave: Bool {
        !reportNumber.isEmpty && !aircraftReg.isEmpty && !pic.isEmpty
    }

    // MARK: Legs

    private func addLeg() {
        let next = (legs.map(\.sequence).max() ?? 0) + 1
        legs.append(LegDraft(sequence: next))
    }

    // MARK: Save

    private func save() {
        let flight = Flight(
            reportNumber: reportNumber.uppercased(),
            aircraftReg: aircraftReg.uppercased(),
            pic: pic,
            sic: sic,
            cabinCrew: cabinCrew,
            client: client,
            flightTypeRaw: flightType.rawValue,
            isClosed: false
        )

        for d in legs {
            let leg = FlightLeg(
                sequence: d.sequence,
                date: d.date,
                departureTime: d.departureTime,
                callSign: d.callSign.uppercased(),
                departure: d.departure.uppercased(),
                destination: d.destination.uppercased()
            )

            flight.legs.append(leg)
        }

        modelContext.insert(flight)

        try? modelContext.save()
        dismiss()
    }
}

private struct LegDraft: Identifiable {
    let id = UUID()
    var sequence: Int
    var date: Date = Date()
    var departureTime: Date = Date()
    var callSign: String = ""
    var departure: String = ""
    var destination: String = ""
}
