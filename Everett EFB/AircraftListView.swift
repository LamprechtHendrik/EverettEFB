import SwiftUI
import SwiftData

struct AircraftListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Aircraft.registration)
    private var aircraft: [Aircraft]

    @State private var showAdd = false

    var body: some View {
        List {
            LogoView()
            if aircraft.isEmpty {
                ContentUnavailableView(
                    "No Aircraft",
                    systemImage: "airplane",
                    description: Text("Tap + to add your first aircraft.")
                )
            } else {
                ForEach(aircraft) { a in
                    NavigationLink {
                        AircraftDocumentsView(aircraft: a)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.registration)
                                    .font(.headline)

                                Text("\(a.type) • MSN \(a.modelSerialNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusBadge(status: a.overallStatus(cautionDays: 30))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        modelContext.delete(aircraft[idx])
                    }
                }
            }
        }
        .navigationTitle("Aircraft")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AircraftFormView(mode: .add)
            }
        }
    }
}

#Preview {
    NavigationStack { AircraftListView() }
        .modelContainer(for: [Aircraft.self, AircraftDocument.self], inMemory: true)
}
