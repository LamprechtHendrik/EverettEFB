import SwiftUI
import SwiftData
import PDFKit
import PencilKit

struct FlightDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Aircraft.registration)])
    private var aircraft: [Aircraft]

    @Query(sort: [SortDescriptor(\CrewMember.surname), SortDescriptor(\CrewMember.name)])
    private var crew: [CrewMember]

    @Bindable var flight: Flight

    @State private var showEditFlight = false
    @State private var editLegTarget: FlightLeg?
    @State private var deleteLegTarget: FlightLeg?
    @State private var signOnTarget: FlightDaySign?
    @State private var signOffTarget: FlightDaySign?
    @State private var showFinalizeAlert = false
    @State private var showDispatchDocument = false
    @State private var dispatchSignTarget: FlightDaySign?

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

            Section("Dispatch Document") {
                Button {
                    showDispatchDocument = true
                } label: {
                    Label("Open Dispatch Document", systemImage: "doc.text.viewfinder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    dispatchSignTarget = existingOrEnsuredRecord(for: flight.displayDate)
                } label: {
                    Label("Sign Dispatch Document", systemImage: "signature")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                Text("Dispatch package access and captain signing will be launched from here, in the same way day sign-on and sign-off are launched from this flight detail view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showDispatchDocument) {
            NavigationStack {
                GeneratedDispatchPDFView(
                    flight: flight,
                    aircraft: linkedAircraft,
                    pic: linkedPIC,
                    sic: linkedSIC,
                    cabinCrew: linkedCabinCrew
                )
            }
        }
        .sheet(item: $dispatchSignTarget) { record in
            NavigationStack {
                DispatchDocumentSignView(
                    flight: flight,
                    daySign: record,
                    aircraft: linkedAircraft,
                    pic: linkedPIC,
                    sic: linkedSIC,
                    cabinCrew: linkedCabinCrew
                )
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

    private var linkedAircraft: Aircraft? {
        let reg = flight.aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !reg.isEmpty else { return nil }
        return aircraft.first {
            $0.registration.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == reg
        }
    }

    private var linkedPIC: CrewMember? {
        linkedCrewMember(named: flight.pic)
    }

    private var linkedSIC: CrewMember? {
        linkedCrewMember(named: flight.sic)
    }

    private var linkedCabinCrew: CrewMember? {
        linkedCrewMember(named: flight.cabinCrew)
    }

    private func linkedCrewMember(named displayName: String) -> CrewMember? {
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }

        return crew.first {
            $0.fullDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleaned
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
                Text("The first leg of this day cannot be filled in until all crew have signed on.")
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

                Text(leg.date.efbDate)
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

private struct GeneratedDispatchPDFView: View {
    let flight: Flight
    let aircraft: Aircraft?
    let pic: CrewMember?
    let sic: CrewMember?
    let cabinCrew: CrewMember?

    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let document {
                PDFKitView(document: document)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to generate dispatch package",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Generating dispatch package...")
            }
        }
        .navigationTitle("Dispatch Document")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
    }

    @MainActor
    private func generatePDF() async {
        do {
            let generator = DispatchPDFGenerator()
            let input = DispatchPDFGenerator.PackageInput(
                flight: flight,
                aircraft: aircraft,
                pic: pic,
                sic: sic,
                cabinCrew: cabinCrew
            )
            document = try generator.generatePDF(for: input)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DispatchDocumentSignView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flight: Flight
    @Bindable var daySign: FlightDaySign
    let aircraft: Aircraft?
    let pic: CrewMember?
    let sic: CrewMember?
    let cabinCrew: CrewMember?

    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    if let document {
                        PDFKitView(document: document)
                            .frame(height: 480)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "Unable to generate dispatch package",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    } else {
                        ProgressView("Generating dispatch package...")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Captain Signature")
                            .font(.headline)
                        Spacer()
                        Text(flight.pic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    SignatureCanvasView(drawingData: signatureBinding)
                        .frame(height: 180)

                    HStack {
                        Spacer()
                        Button("Clear Signature") {
                            daySign.picSignOnDrawing = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("Sign Dispatch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSignature()
                }
                .disabled(daySign.picSignOnDrawing == nil)
            }
        }
        .task {
            await generatePDF()
        }
        .onChange(of: daySign.picSignOnDrawing) { _, _ in
            Task {
                await generatePDF()
            }
        }
    }

    private var signatureBinding: Binding<Data?> {
        Binding(
            get: { daySign.picSignOnDrawing },
            set: { daySign.picSignOnDrawing = $0 }
        )
    }

    @MainActor
    private func generatePDF() async {
        do {
            let generator = DispatchPDFGenerator()
            let input = DispatchPDFGenerator.PackageInput(
                flight: flight,
                aircraft: aircraft,
                pic: pic,
                sic: sic,
                cabinCrew: cabinCrew
            )
            document = try generator.generatePDF(for: input, signatureData: daySign.picSignOnDrawing)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSignature() {
        if daySign.picSignOnName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            daySign.picSignOnName = flight.pic
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Save dispatch signature failed:", error)
        }
    }
}
