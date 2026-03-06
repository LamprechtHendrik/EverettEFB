import SwiftUI
import SwiftData

struct FlightDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var flight: Flight

    @State private var showEditFlight = false
    @State private var editLegTarget: FlightLeg?
    @State private var deleteLegTarget: FlightLeg?
    @State private var signOnTarget: FlightDaySign?
    @State private var signOffTarget: FlightDaySign?
    @State private var showFinalizeAlert = false

    var body: some View {
        List {
            Section("Flight") {
                LabeledContent("Date", value: flight.displayDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Report #", value: flight.reportNumber)
                LabeledContent("Aircraft", value: flight.aircraftReg)
                LabeledContent("PIC", value: flight.pic)
                if !flight.sic.isEmpty { LabeledContent("SIC", value: flight.sic) }
                if !flight.cabinCrew.isEmpty { LabeledContent("Cabin", value: flight.cabinCrew) }
                if !flight.client.isEmpty { LabeledContent("Client", value: flight.client) }

                if !flight.isClosed {
                    Button {
                        showEditFlight = true
                    } label: {
                        Label("Edit flight details", systemImage: "pencil")
                    }
                }
            }

            if groupedDays.isEmpty {
                Section("Legs") {
                    ContentUnavailableView(
                        "No legs yet",
                        systemImage: "airplane",
                        description: Text("Add a leg to start the flight.")
                    )

                    if !flight.isClosed {
                        NavigationLink {
                            FlightLegEditView(flight: flight, leg: nil, mode: .add)
                        } label: {
                            Label("Add leg", systemImage: "plus.circle.fill")
                        }
                    }
                }
            } else {
                ForEach(groupedDays, id: \.day) { dayGroup in
                    Section {
                        dayHeader(for: dayGroup.day)

                        ForEach(dayGroup.legs) { leg in
                            legRow(for: leg, day: dayGroup.day)
                        }

                        if !flight.isClosed {
                            NavigationLink {
                                FlightLegEditView(flight: flight, leg: nil, mode: .add)
                            } label: {
                                Label("Add leg", systemImage: "plus.circle.fill")
                            }
                        }
                    } header: {
                        Text(dayGroup.day.formatted(date: .complete, time: .omitted))
                    }
                }
            }

            Section("Finalize Flight Report") {
                if flight.isClosed {
                    Label("Flight Report Finalized", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)

                    Text("This flight is now read-only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showFinalizeAlert = true
                    } label: {
                        Label("Finalize Flight Report", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!flight.canFinalizeReport)

                    if !flight.canFinalizeReport {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Flight cannot be finalized yet.")
                                .font(.footnote)
                                .foregroundStyle(.orange)

                            Text("Requirements:")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("• All legs must be finalized")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("• Every operating day must have Sign On completed")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("• Every operating day must have Sign Off completed")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Flight")
        .toolbar {
            if !flight.isClosed {
                EditButton()
            }
        }
        .sheet(isPresented: $showEditFlight) {
            NavigationStack {
                FlightEditView(flight: flight)
            }
        }
        .sheet(item: $editLegTarget) { leg in
            NavigationStack {
                FlightLegEditView(flight: flight, leg: leg, mode: .edit)
            }
        }
        .sheet(item: $signOnTarget) { record in
            NavigationStack {
                FlightDaySignView(flight: flight, daySign: record, mode: .signOn)
            }
        }
        .sheet(item: $signOffTarget) { record in
            NavigationStack {
                FlightDaySignView(flight: flight, daySign: record, mode: .signOff)
            }
        }
        .alert("Delete leg?", isPresented: Binding(
            get: { deleteLegTarget != nil },
            set: { if !$0 { deleteLegTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let leg = deleteLegTarget {
                    deleteLeg(leg)
                }
                deleteLegTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteLegTarget = nil
            }
        } message: {
            if let leg = deleteLegTarget {
                Text("Leg \(leg.sequence): \(leg.departure) → \(leg.destination)")
            }
        }
        .alert("Finalize flight report?", isPresented: $showFinalizeAlert) {
            Button("Finalize", role: .destructive) {
                finalizeFlight()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Once finalized, this flight becomes read-only.")
        }
    }

    private var sortedLegs: [FlightLeg] {
        flight.legs.sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.sequence < $1.sequence
            }
            return $0.date < $1.date
        }
    }

    private var groupedDays: [(day: Date, legs: [FlightLeg])] {
        let grouped = Dictionary(grouping: sortedLegs) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    @ViewBuilder
    private func dayHeader(for day: Date) -> some View {
        let record = existingOrEnsuredRecord(for: day)
        let canSignOff = canShowSignOff(for: day)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusPill(title: "Sign On", done: record.allSignedOn, time: record.signOnTime)
                statusPill(title: "Sign Off", done: record.allSignedOff, time: record.signOffTime)
            }

            if !flight.isClosed {
                HStack(spacing: 12) {
                    if record.allSignedOn {
                        Button {
                            signOnTarget = record
                        } label: {
                            Label("Edit Sign On", systemImage: "pencil.and.scribble")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            signOnTarget = record
                        } label: {
                            Label("Sign On Day", systemImage: "pencil.and.scribble")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if canSignOff || record.allSignedOff {
                        if record.allSignedOff {
                            Button {
                                signOffTarget = record
                            } label: {
                                Label("Edit Sign Off", systemImage: "signature")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                signOffTarget = record
                            } label: {
                                Label("Sign Off Day", systemImage: "signature")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            if !record.allSignedOn {
                Text("The first leg of this day cannot be filled in until all 3 crew have signed on.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if !record.allSignedOff && !canSignOff {
                Text("Sign off becomes available only after the last leg of this day has been completed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func legRow(for leg: FlightLeg, day: Date) -> some View {
        let record = existingOrEnsuredRecord(for: day)
        let isFirst = flight.isFirstLegOfDay(leg)
        let canOpen = !isFirst || record.allSignedOn

        HStack(spacing: 12) {
            if canOpen {
                NavigationLink {
                    FlightLegOpsView(flight: flight, leg: leg)
                } label: {
                    legInfo(leg)
                }
            } else {
                Button {
                    signOnTarget = record
                } label: {
                    legInfo(leg)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !flight.isClosed {
                HStack(spacing: 10) {
                    Button {
                        editLegTarget = leg
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        deleteLegTarget = leg
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func legInfo(_ leg: FlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leg \(leg.sequence): \(leg.departure) → \(leg.destination)")
                .font(.headline)

            HStack(spacing: 10) {
                if !leg.callSign.isEmpty {
                    Text(leg.callSign)
                }

                Text(leg.date.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)

                if leg.isFinalized {
                    Text("Finalized")
                        .foregroundStyle(.green)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private func statusPill(title: String, done: Bool, time: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "exclamationmark.circle")
            Text(done && !time.isEmpty ? "\(title) \(time)" : title)
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .foregroundStyle(done ? .green : .orange)
        .background((done ? Color.green : Color.orange).opacity(0.15))
        .clipShape(Capsule())
    }

    private func canShowSignOff(for day: Date) -> Bool {
        guard let lastLeg = flight.lastLeg(on: day) else { return false }
        return lastLeg.isCompleted
    }

    private func existingOrEnsuredRecord(for day: Date) -> FlightDaySign {
        if let existing = flight.daySign(for: day) {
            return existing
        }

        let newRecord = flight.ensureDaySign(for: day)
        modelContext.insert(newRecord)
        saveContext("create day sign")
        return newRecord
    }

    private func deleteLeg(_ leg: FlightLeg) {
        if let idx = flight.legs.firstIndex(where: { $0.persistentModelID == leg.persistentModelID }) {
            let removed = flight.legs.remove(at: idx)
            modelContext.delete(removed)
        }
        resequenceLegs()
        saveContext("delete leg")
    }

    private func resequenceLegs() {
        let legs = flight.legs.sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.sequence < $1.sequence
            }
            return $0.date < $1.date
        }

        for (i, l) in legs.enumerated() {
            l.sequence = i + 1
        }
    }

    private func finalizeFlight() {
        guard flight.canFinalizeReport else { return }

        flight.isClosed = true
        saveContext("finalize flight")
    }

    private func saveContext(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to \(what):", error)
        }
    }
}
