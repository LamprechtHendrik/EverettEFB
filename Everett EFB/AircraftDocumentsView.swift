import SwiftUI
import SwiftData

struct AircraftDocumentsView: View {
    @Bindable var aircraft: Aircraft
    @Environment(\.modelContext) private var modelContext

    private let cautionDays = 30

    var body: some View {
        List {
            Section("Aircraft") {
                HStack {
                    Text("Registration")
                    Spacer()
                    Text(aircraft.registration).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Type")
                    Spacer()
                    Text(aircraft.type).foregroundStyle(.secondary)
                }
                HStack {
                    Text("MSN")
                    Spacer()
                    Text(aircraft.modelSerialNumber).foregroundStyle(.secondary)
                }
            }

            ForEach(AircraftDocGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(docs(in: group)) { row in
                        AircraftDocRowView(
                            title: row.type.rawValue,
                            last: row.lastCompleted,
                            expiry: row.expiry,
                            status: Compliance.status(forExpiry: row.expiry, cautionDays: cautionDays)
                        )
                    }
                }
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                NavigationLink("Edit") {
                    AircraftFormView(mode: .edit(aircraft))
                }
            }
        }
        .onAppear {
            ensureAllDocumentRowsExist()
        }
    }

    private func docs(in group: AircraftDocGroup) -> [AircraftDocument] {
        aircraft.documents
            .filter { $0.type.group == group }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }

    /// Create empty rows so the list always shows every expected item like your screenshot.
    private func ensureAllDocumentRowsExist() {
        var existing = Set(aircraft.documents.map { $0.typeRaw })

        for t in AircraftDocumentType.allCases {
            if !existing.contains(t.rawValue) {
                aircraft.documents.append(AircraftDocument(type: t))
                existing.insert(t.rawValue)
            }
        }
    }
}

private struct AircraftDocRowView: View {
    let title: String
    let last: Date?
    let expiry: Date?
    let status: ComplianceStatus

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d/M/yyyy"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Name
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Last
            Text(last.map(df.string) ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            // Expiry
            Text(expiry.map(df.string) ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            // Status (like screenshot)
            StatusBadge(status: status)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
