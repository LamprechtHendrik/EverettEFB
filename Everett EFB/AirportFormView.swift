import SwiftUI
import SwiftData

struct AirportFormView: View {
    enum Mode {
        case add
        case edit(Airport)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var icao: String = ""
    @State private var iata: String = ""
    @State private var name: String = ""
    @State private var countryISO: String = ""

    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""

    @State private var autoFillEnabled = true
    @State private var infoText: String?

    // Avoid re-filling repeatedly when we set fields programmatically
    @State private var isApplyingAutoFill = false

    var body: some View {
        Form {
            Section("Designators") {
                TextField("ICAO (e.g. FQMA)", text: $icao)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: icao) {
                        attemptAutoFill(trigger: .icao)
                    }

                TextField("IATA (e.g. MPM)", text: $iata)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: iata) {
                        attemptAutoFill(trigger: .iata)
                    }

                Toggle("Auto-fill details from database", isOn: $autoFillEnabled)

                if let infoText {
                    Text(infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Details") {
                TextField("Airport name", text: $name)
                TextField("Country (ISO, e.g. MZ)", text: $countryISO)
                    .textInputAutocapitalization(.characters)
            }

            Section("Coordinates") {
                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
            }

            Section {
                Button("Save") { save() }
                    .disabled(icao.trimmed.isEmpty && iata.trimmed.isEmpty)
            }
        }
        .navigationTitle(modeTitle)
        .onAppear { loadIfEditing() }
    }

    private enum Trigger {
        case icao
        case iata
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Airport"
        case .edit: return "Edit Airport"
        }
    }

    private func loadIfEditing() {
        guard case .edit(let a) = mode else { return }
        icao = a.icao
        iata = a.iata
        name = a.name
        countryISO = a.countryISO
        latitudeText = String(a.latitude)
        longitudeText = String(a.longitude)
    }

    private func attemptAutoFill(trigger: Trigger) {
        guard autoFillEnabled else { return }
        guard !isApplyingAutoFill else { return }

        let currentICAO = icao.trimmedUpper
        let currentIATA = iata.trimmedUpper

        // If user just typed ICAO, prefer ICAO; if typed IATA and ICAO empty, try IATA.
        let match: Airport?
        switch trigger {
        case .icao:
            match = AirportAutoFill.findByICAO(currentICAO, in: modelContext)
                ?? AirportAutoFill.findByIATA(currentIATA, in: modelContext)
        case .iata:
            // If ICAO is already entered, still prefer ICAO (less ambiguous)
            match = AirportAutoFill.findBestMatch(icao: currentICAO, iata: currentIATA, in: modelContext)
        }

        guard let found = match else {
            infoText = "No match found in database."
            return
        }

        // Apply autofill
        isApplyingAutoFill = true
        defer { isApplyingAutoFill = false }

        // Only overwrite fields that are blank or obviously placeholder,
        // but do fill missing ICAO/IATA whichever user didn’t enter.
        if currentICAO.isEmpty { icao = found.icao }
        if currentIATA.isEmpty { iata = found.iata }

        if name.trimmed.isEmpty { name = found.name }
        if countryISO.trimmed.isEmpty { countryISO = found.countryISO }

        // Coordinates: if empty, fill them; if user already typed, we respect it.
        if latitudeText.trimmed.isEmpty { latitudeText = String(found.latitude) }
        if longitudeText.trimmed.isEmpty { longitudeText = String(found.longitude) }

        infoText = "Auto-filled from airport database."
    }

    private func save() {
        let airport: Airport
        switch mode {
        case .add:
            airport = Airport()
            modelContext.insert(airport)
        case .edit(let existing):
            airport = existing
        }

        airport.icao = icao.trimmedUpper
        airport.iata = iata.trimmedUpper
        airport.name = name.trimmed
        airport.countryISO = countryISO.trimmedUpper

        // If user leaves coords blank, we keep current values (or 0 if brand new).
        if let lat = Double(latitudeText.trimmed) { airport.latitude = lat }
        if let lon = Double(longitudeText.trimmed) { airport.longitude = lon }

        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedUpper: String { trimmed.uppercased() }
}
