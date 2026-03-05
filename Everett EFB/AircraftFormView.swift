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

        .navigationTitle("Aircraft")

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

        dismiss()
    }
}
