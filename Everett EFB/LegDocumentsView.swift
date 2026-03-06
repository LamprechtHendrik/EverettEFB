import SwiftUI

struct LegDocumentsView: View {
    @Bindable var leg: FlightLeg

    var body: some View {
        List {
            if leg.documents.isEmpty {
                ContentUnavailableView(
                    "No documents",
                    systemImage: "doc",
                    description: Text("Add the required leg documents.")
                )
            } else {
                ForEach(leg.documents) { doc in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(doc.type.rawValue)
                            .font(.headline)
                        Text(doc.fileName.isEmpty ? "No file attached yet" : doc.fileName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Documents")
    }
}
