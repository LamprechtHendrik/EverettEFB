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
                Button("Save") { save() }
                    .disabled(!canSave)
            }
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
            }
        }
    }

    private var canSave: Bool {
        let validTime = TimeEntryHelper.normalizedDisplay(signTimeText) != nil
        if mode == .signOn {
            return validTime &&
                daySign.picSignOnDrawing != nil &&
                daySign.sicSignOnDrawing != nil &&
                daySign.cabinSignOnDrawing != nil
        } else {
            return validTime &&
                daySign.picSignOffDrawing != nil &&
                daySign.sicSignOffDrawing != nil &&
                daySign.cabinSignOffDrawing != nil
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(daySign.date.formatted(date: .complete, time: .omitted))
                .font(.headline)
            Text("Flight Report: \(flight.reportNumber)")
                .foregroundStyle(.secondary)
            Text("Aircraft: \(flight.aircraftReg)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var signTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .signOn ? "Sign On Time" : "Sign Off Time")
                .font(.headline)

            HStack {
                Text("Time")
                    .frame(width: 110, alignment: .leading)

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

            Text("Enter as hhmm or hmm. It will save as HH:MM.")
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
            signatureBlock(title: "Cabin Crew", name: cabinName, drawing: cabinDrawing)
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

    private func save() {
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
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Save day sign failed:", error)
        }
    }
}
