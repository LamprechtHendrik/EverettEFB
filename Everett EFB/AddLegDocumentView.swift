import SwiftUI
import SwiftData

struct AddLegDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var leg: FlightLeg

    @State private var selectedType: LegDocumentType = .paxManifest
    @State private var fileName: String = ""

    var body: some View {
        Form {
            Picker("Document Type", selection: $selectedType) {
                ForEach(LegDocumentType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            TextField("File name / reference", text: $fileName)

            Button("Save") {
                let doc = LegDocument(type: selectedType, fileName: fileName.trimmingCharacters(in: .whitespacesAndNewlines))
                leg.documents.append(doc)

                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    print("❌ Save leg document failed:", error)
                }
            }
        }
        .navigationTitle("Add Document")
    }
}
