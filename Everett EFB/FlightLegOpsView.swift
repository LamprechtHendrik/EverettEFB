import SwiftUI
import SwiftData

struct FlightLegOpsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flight: Flight
    @Bindable var leg: FlightLeg

    @Query(sort: [SortDescriptor(\Airport.icao), SortDescriptor(\Airport.iata)])
    private var airports: [Airport]

    @State private var showAddDocument = false
    @State private var signOffTarget: FlightDaySign?

    @State private var blockOffText = ""
    @State private var blockOnText = ""
    @State private var takeOffText = ""
    @State private var landingText = ""

    @State private var depFuelText = ""
    @State private var ldgFuelText = ""
    @State private var paxText = ""
    @State private var cargoText = ""
    @State private var upliftText = ""
    @State private var fuelInvoiceText = ""
    @State private var locSearch = ""

    var body: some View {
        Form {
            if flight.isClosed {
                Section {
                    Text("Flight report finalized. Editing is disabled.")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                HStack(spacing: 12) {
                    NavigationLink {
                        LegDocumentsView(leg: leg)
                    } label: {
                        Label("Documents", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showAddDocument = true
                    } label: {
                        Label("Add Document", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Leg") {
                LabeledContent("Route", value: "\(leg.departure) → \(leg.destination)")
                LabeledContent("Call sign", value: leg.callSign.isEmpty ? "-" : leg.callSign)
                LabeledContent("Date", value: leg.date.formatted(date: .abbreviated, time: .omitted))
            }

            Section("Times") {
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Block Off")
                                .frame(width: 110, alignment: .leading)
                            timeField("hhmm", text: $blockOffText)
                        }

                        HStack {
                            Text("Block On")
                                .frame(width: 110, alignment: .leading)
                            timeField("hhmm", text: $blockOnText)
                        }

                        DisplayRow(
                            title: "Block Time",
                            value: TimeEntryHelper.formattedDuration(
                                TimeEntryHelper.durationMinutes(from: blockOffText, to: blockOnText)
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Take Off")
                                .frame(width: 110, alignment: .leading)
                            timeField("hhmm", text: $takeOffText)
                        }

                        HStack {
                            Text("Landing")
                                .frame(width: 110, alignment: .leading)
                            timeField("hhmm", text: $landingText)
                        }

                        DisplayRow(
                            title: "Flight Time",
                            value: TimeEntryHelper.formattedDuration(
                                TimeEntryHelper.durationMinutes(from: takeOffText, to: landingText)
                            )
                        )
                    }
                }
            }

            Section("Fuel / Load") {
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 10) {
                        NumberRow(title: "Dep Fuel", text: $depFuelText)
                        NumberRow(title: "LDG Fuel", text: $ldgFuelText)

                        DisplayRow(
                            title: "Fuel Used",
                            value: fuelUsedText
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        NumberRow(title: "Pax", text: $paxText)
                        NumberRow(title: "Cargo", text: $cargoText)
                    }
                }
            }

            Section("Other") {
                NumberRow(title: "Uplift", text: $upliftText)

                HStack {
                    Text("Fuel Invoice")
                        .frame(width: 110, alignment: .leading)

                    TextField("", text: $fuelInvoiceText)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.4))
                        )
                        .autocorrectionDisabled()
                }

                PredictiveSearchField(
                    title: "LOC",
                    text: $locSearch,
                    suggestions: filteredAirports(for: locSearch),
                    displayText: { $0.outputIATAOrICAO },
                    secondaryText: { "\($0.name) • ICAO \($0.icao) • IATA \($0.iata)" },
                    onSelect: { selected in
                        locSearch = selected.outputIATAOrICAO
                    }
                )
            }

            Section("Finalize Leg") {
                if leg.isFinalized {
                    Text("This leg is finalized.")
                        .foregroundStyle(.green)
                } else if requiresSignOffBeforeFinalize {
                    Text("This is the last leg of the day. Sign off is required before finalizing it.")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                    Button {
                        signOffTarget = daySignRecord
                    } label: {
                        Label("Sign Off Day", systemImage: "signature")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if daySignRecord.allSignedOff {
                        Button {
                            save()
                            leg.isFinalized = true
                            try? modelContext.save()
                            dismiss()
                        } label: {
                            Label("Finalize Leg", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button {
                        save()
                        leg.isFinalized = true
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Label("Finalize Leg", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Leg \(leg.sequence)")
        .disabled(flight.isClosed)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Save") {
                    save()
                }
            }
        }
        .sheet(isPresented: $showAddDocument) {
            NavigationStack {
                AddLegDocumentView(leg: leg)
            }
        }
        .sheet(item: $signOffTarget) { record in
            NavigationStack {
                FlightDaySignView(flight: flight, daySign: record, mode: .signOff)
            }
        }
        .onAppear {
            blockOffText = TimeEntryHelper.display(from: leg.blockOff)
            blockOnText = TimeEntryHelper.display(from: leg.blockOn)
            takeOffText = TimeEntryHelper.display(from: leg.takeOff)
            landingText = TimeEntryHelper.display(from: leg.landing)

            depFuelText = leg.depFuel.map { String($0) } ?? ""
            ldgFuelText = leg.ldgFuel.map { String($0) } ?? ""
            paxText = leg.pax.map { String($0) } ?? ""
            cargoText = leg.cargo.map { String($0) } ?? ""
            upliftText = leg.uplift.map { String($0) } ?? ""
            fuelInvoiceText = leg.fuelInvoice
            locSearch = leg.loc
        }
    }

    private var daySignRecord: FlightDaySign {
        if let existing = flight.daySign(for: leg.date) {
            return existing
        }

        let record = flight.ensureDaySign(for: leg.date)
        modelContext.insert(record)
        return record
    }

    private var requiresSignOffBeforeFinalize: Bool {
        flight.isLastLegOfDay(leg) && !daySignRecord.allSignedOff
    }

    private func save() {
        blockOffText = TimeEntryHelper.normalizedDisplay(blockOffText) ?? blockOffText
        blockOnText = TimeEntryHelper.normalizedDisplay(blockOnText) ?? blockOnText
        takeOffText = TimeEntryHelper.normalizedDisplay(takeOffText) ?? takeOffText
        landingText = TimeEntryHelper.normalizedDisplay(landingText) ?? landingText

        leg.blockOff = TimeEntryHelper.date(from: blockOffText, on: leg.date)
        leg.blockOn = TimeEntryHelper.date(from: blockOnText, on: leg.date)
        leg.takeOff = TimeEntryHelper.date(from: takeOffText, on: leg.date)
        leg.landing = TimeEntryHelper.date(from: landingText, on: leg.date)

        leg.depFuel = Int(depFuelText.trimmingCharacters(in: .whitespacesAndNewlines))
        leg.ldgFuel = Int(ldgFuelText.trimmingCharacters(in: .whitespacesAndNewlines))
        leg.pax = Int(paxText.trimmingCharacters(in: .whitespacesAndNewlines))
        leg.cargo = Int(cargoText.trimmingCharacters(in: .whitespacesAndNewlines))
        leg.uplift = Int(upliftText.trimmingCharacters(in: .whitespacesAndNewlines))

        leg.fuelInvoice = fuelInvoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        leg.loc = locSearch.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        do {
            try modelContext.save()
        } catch {
            print("❌ Save leg ops failed:", error)
        }
    }

    private func timeField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(8)
            .frame(width: 100)
            .background(Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.4))
            )
    }

    private var fuelUsedText: String {
        guard
            let dep = Int(depFuelText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let ldg = Int(ldgFuelText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return "-"
        }

        let used = dep - ldg
        guard used >= 0 else {
            return "-"
        }

        return "\(used)"
    }

    private func filteredAirports(for query: String) -> [Airport] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(airports.prefix(8)) }

        return Array(
            airports.filter {
                $0.name.lowercased().contains(q) ||
                $0.icao.lowercased().contains(q) ||
                $0.iata.lowercased().contains(q)
            }
            .prefix(8)
        )
    }
}
