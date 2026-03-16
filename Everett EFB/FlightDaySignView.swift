import SwiftUI
import SwiftData

struct FlightDaySignView: View {
    enum Mode {
        case signOn
        case signOff
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flight: Flight
    @Bindable var daySign: FlightDaySign
    let mode: Mode

    @State private var signTimeText = ""
    @State private var intermediateSignOffText = ""
    @State private var intermediateSignOnText = ""
    @State private var showSplitDutyPrompt = false
    @State private var splitDutyValidationMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                signTimeCard

                if mode == .signOn {
                    signatureSection(
                        title: "Sign On",
                        picName: flight.pic,
                        sicName: flight.sic,
                        cabinName: flight.cabinCrew,
                        picDrawing: bindingForDrawing(\.picSignOnDrawing),
                        sicDrawing: bindingForDrawing(\.sicSignOnDrawing),
                        cabinDrawing: bindingForDrawing(\.cabinSignOnDrawing)
                    )
                } else {
                    signatureSection(
                        title: "Sign Off",
                        picName: flight.pic,
                        sicName: flight.sic,
                        cabinName: flight.cabinCrew,
                        picDrawing: bindingForDrawing(\.picSignOffDrawing),
                        sicDrawing: bindingForDrawing(\.sicSignOffDrawing),
                        cabinDrawing: bindingForDrawing(\.cabinSignOffDrawing)
                    )
                }
            }
            .padding()
        }
        .navigationTitle(mode == .signOn ? "Day Sign On" : "Day Sign Off")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { handleSaveTapped() }
                    .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "Was Split Duty used?",
            isPresented: $showSplitDutyPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes") {
                daySign.splitDutyStatus = .yes
                splitDutyValidationMessage = "Enter Intermediate Sign Off (Local) and Intermediate Sign On (Local), then save again."
            }

            Button("No") {
                daySign.splitDutyStatus = .notApplicable
                intermediateSignOffText = ""
                intermediateSignOnText = ""
                commitSave()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Before finalizing the day sign off, confirm whether the crew had Split Duty.")
        }
        .alert("Split Duty", isPresented: Binding(
            get: { splitDutyValidationMessage != nil },
            set: { if !$0 { splitDutyValidationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                splitDutyValidationMessage = nil
            }
        } message: {
            Text(splitDutyValidationMessage ?? "")
        }
        .onAppear {
            if mode == .signOn {
                if daySign.picSignOnName.isEmpty { daySign.picSignOnName = flight.pic }
                if daySign.sicSignOnName.isEmpty { daySign.sicSignOnName = flight.sic }
                if daySign.cabinSignOnName.isEmpty { daySign.cabinSignOnName = flight.cabinCrew }
                signTimeText = daySign.signOnTime
            } else {
                if daySign.picSignOffName.isEmpty { daySign.picSignOffName = flight.pic }
                if daySign.sicSignOffName.isEmpty { daySign.sicSignOffName = flight.sic }
                if daySign.cabinSignOffName.isEmpty { daySign.cabinSignOffName = flight.cabinCrew }
                signTimeText = daySign.signOffTime
                intermediateSignOffText = daySign.intermediateSignOffTime
                intermediateSignOnText = daySign.intermediateSignOnTime
            }
        }
    }

    private var canSave: Bool {
        let validTime = TimeEntryHelper.normalizedDisplay(signTimeText) != nil

        if mode == .signOn {
            return validTime &&
                daySign.picSignOnDrawing != nil &&
                daySign.sicSignOnDrawing != nil &&
                (!requiresCabinCrew || daySign.cabinSignOnDrawing != nil)
        }

        let validSplitDutyFields: Bool
        switch daySign.splitDutyStatus {
        case .yes:
            validSplitDutyFields =
                TimeEntryHelper.normalizedDisplay(intermediateSignOffText) != nil &&
                TimeEntryHelper.normalizedDisplay(intermediateSignOnText) != nil
        case .no, .notApplicable, .notAsked:
            validSplitDutyFields = true
        }

        return validTime &&
            validSplitDutyFields &&
            daySign.picSignOffDrawing != nil &&
            daySign.sicSignOffDrawing != nil &&
            (!requiresCabinCrew || daySign.cabinSignOffDrawing != nil)
    }

    private var requiresCabinCrew: Bool {
        let value = flight.cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }

        let normalized = value.lowercased()
        return normalized != "n/a" && normalized != "na" && normalized != "-"
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(daySign.date.efbDate)
                .font(.headline)
            Text("Flight Report: \(flight.reportNumber)")
                .foregroundStyle(.secondary)
            Text("Aircraft: \(flight.aircraftReg)")
                .foregroundStyle(.secondary)
            Text("Type of Flight: \(flight.flightType.rawValue)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var signTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .signOn ? "Sign On Time (Local)" : "Sign Off Time (Local)")
                .font(.headline)

            HStack {
                Text("Time (Local)")
                    .frame(width: 150, alignment: .leading)

                TextField("hhmm", text: $signTimeText)
                    .keyboardType(.numberPad)
                    .padding(8)
                    .frame(width: 120)
                    .background(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.4))
                    )
            }

            if mode == .signOff {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Duty")
                        .font(.headline)

                    if daySign.splitDutyStatus == .notAsked {
                        Text("You will be asked about Split Duty when saving Sign Off.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Selection: \(daySign.splitDutyStatus == .notApplicable ? "No" : daySign.splitDutyStatus.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if daySign.splitDutyStatus == .yes {
                        HStack {
                            Text("Intermediate Sign Off (Local)")
                                .frame(width: 220, alignment: .leading)

                            TextField("hhmm", text: $intermediateSignOffText)
                                .keyboardType(.numberPad)
                                .padding(8)
                                .frame(width: 120)
                                .background(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.4))
                                )
                        }

                        HStack {
                            Text("Intermediate Sign On (Local)")
                                .frame(width: 220, alignment: .leading)

                            TextField("hhmm", text: $intermediateSignOnText)
                                .keyboardType(.numberPad)
                                .padding(8)
                                .frame(width: 120)
                                .background(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.4))
                                )
                        }

                        Text("Total Split Duty will be calculated automatically on the flight report, including when it runs past midnight.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Enter all times as hhmm or hmm. They will save as HH:MM.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func signatureSection(
        title: String,
        picName: String,
        sicName: String,
        cabinName: String,
        picDrawing: Binding<Data?>,
        sicDrawing: Binding<Data?>,
        cabinDrawing: Binding<Data?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .bold()

            signatureBlock(title: "PIC", name: picName, drawing: picDrawing)
            signatureBlock(title: "SIC / FO", name: sicName, drawing: sicDrawing)

            if requiresCabinCrew {
                signatureBlock(title: "Cabin Crew", name: cabinName, drawing: cabinDrawing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signatureBlock(title: String, name: String, drawing: Binding<Data?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(name.isEmpty ? "-" : name)
                    .foregroundStyle(.secondary)
            }

            SignatureCanvasView(drawingData: drawing)
                .frame(height: 140)

            HStack {
                Spacer()
                Button("Clear Signature") {
                    drawing.wrappedValue = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bindingForDrawing(_ keyPath: ReferenceWritableKeyPath<FlightDaySign, Data?>) -> Binding<Data?> {
        Binding(
            get: { daySign[keyPath: keyPath] },
            set: { daySign[keyPath: keyPath] = $0 }
        )
    }

    private func handleSaveTapped() {
        if mode == .signOff && daySign.splitDutyStatus == .notAsked {
            showSplitDutyPrompt = true
            return
        }

        if mode == .signOff && daySign.splitDutyStatus == .yes {
            let off = TimeEntryHelper.normalizedDisplay(intermediateSignOffText)
            let on = TimeEntryHelper.normalizedDisplay(intermediateSignOnText)

            guard off != nil, on != nil else {
                splitDutyValidationMessage = "Enter valid Intermediate Sign Off and Intermediate Sign On times before saving Sign Off."
                return
            }
        }

        commitSave()
    }

    private func commitSave() {
        let time = TimeEntryHelper.normalizedDisplay(signTimeText) ?? signTimeText

        if mode == .signOn {
            daySign.signOnTime = time
            daySign.picSignOnName = flight.pic
            daySign.sicSignOnName = flight.sic
            daySign.cabinSignOnName = flight.cabinCrew
        } else {
            daySign.signOffTime = time
            daySign.picSignOffName = flight.pic
            daySign.sicSignOffName = flight.sic
            daySign.cabinSignOffName = flight.cabinCrew

            switch daySign.splitDutyStatus {
            case .yes:
                daySign.intermediateSignOffTime = TimeEntryHelper.normalizedDisplay(intermediateSignOffText) ?? intermediateSignOffText
                daySign.intermediateSignOnTime = TimeEntryHelper.normalizedDisplay(intermediateSignOnText) ?? intermediateSignOnText
            case .no, .notApplicable:
                daySign.intermediateSignOffTime = ""
                daySign.intermediateSignOnTime = ""
            case .notAsked:
                break
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Save day sign failed:", error)
        }
    }
}
