import SwiftUI
import SwiftData

struct AircraftFormView: View {

    enum Mode {
        case add
        case edit(Aircraft)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var registration = ""
    @State private var type = ""
    @State private var msn = ""

    @State private var lastCompleted: [AircraftDocumentType: Date?] = [:]
    @State private var expiry: [AircraftDocumentType: Date?] = [:]

    private var titleText: String {
        switch mode {
        case .add:
            return "Add Aircraft"
        case .edit:
            return "Edit Aircraft"
        }
    }

    private func existingDocument(for type: AircraftDocumentType, in aircraft: Aircraft) -> AircraftDocument? {
        aircraft.documents.first { $0.type == type }
    }

    private func loadValues() {
        switch mode {
        case .add:
            registration = ""
            type = ""
            msn = ""

            lastCompleted = [:]
            expiry = [:]

            for docType in AircraftDocumentType.allCases {
                lastCompleted[docType] = nil
                expiry[docType] = nil
            }

        case .edit(let aircraft):
            registration = aircraft.registration
            type = aircraft.type
            msn = aircraft.modelSerialNumber

            lastCompleted = [:]
            expiry = [:]

            for docType in AircraftDocumentType.allCases {
                let existing = existingDocument(for: docType, in: aircraft)
                lastCompleted[docType] = existing?.lastCompleted
                expiry[docType] = existing?.expiry
            }
        }
    }

    var body: some View {

        Form {

            Section("Aircraft") {

                TextField("Registration", text: $registration)
                TextField("Type", text: $type)
                TextField("Model Serial Number", text: $msn)

            }

            Section("Documents") {

                ForEach(AircraftDocumentType.allCases) { doc in

                    VStack(alignment: .leading, spacing: 10) {

                        Text(doc.rawValue)
                            .font(.headline)

                        OptionalDatePicker(
                            title: "Last Completed",
                            date: Binding(
                                get: { lastCompleted[doc] ?? nil },
                                set: { lastCompleted[doc] = $0 }
                            )
                        )

                        OptionalDatePicker(
                            title: "Expiry",
                            date: Binding(
                                get: { expiry[doc] ?? nil },
                                set: { expiry[doc] = $0 }
                            )
                        )
                    }
                }
            }
        }

        .navigationTitle(titleText)
        .onAppear {
            loadValues()
        }

        .toolbar {

            ToolbarItem {

                Button("Save") {

                    save()

                }
            }
        }
    }

    private func save() {

        let aircraft: Aircraft

        switch mode {

        case .add:
            aircraft = Aircraft()
            modelContext.insert(aircraft)

        case .edit(let existing):
            aircraft = existing
        }

        aircraft.registration = registration
        aircraft.type = type
        aircraft.modelSerialNumber = msn

        for docType in AircraftDocumentType.allCases {
            let completedDate = lastCompleted[docType] ?? nil
            let expiryDate = expiry[docType] ?? nil

            if let existing = existingDocument(for: docType, in: aircraft) {
                existing.lastCompleted = completedDate
                existing.expiry = expiryDate
            } else {
                let newDocument = AircraftDocument(
                    type: docType,
                    lastCompleted: completedDate,
                    expiry: expiryDate
                )
                aircraft.documents.append(newDocument)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Aircraft save failed:", error)
        }

        dismiss()
    }
}
