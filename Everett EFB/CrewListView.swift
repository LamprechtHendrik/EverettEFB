import SwiftUI
import SwiftData

struct CrewListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\CrewMember.surname), SortDescriptor(\CrewMember.name)])
    private var crew: [CrewMember]

    @State private var showAdd = false

    var body: some View {
        List {
            LogoView()
            if crew.isEmpty {
                ContentUnavailableView(
                    "No crew yet",
                    systemImage: "person.3",
                    description: Text("Tap + to add your first crew member.")
                )
            } else {
                ForEach(crew) { member in
                    NavigationLink {
                        CrewDocumentsView(member: member)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(member.surname), \(member.name)")
                                    .font(.headline)

                                Text("\(member.role.rawValue) • Lic: \(member.licenseNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusBadge(status: member.overallStatus(cautionDays: 30))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        modelContext.delete(crew[idx])
                    }
                }
            }
        }
        .navigationTitle("Crew")
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
                CrewFormView(mode: .add)
            }
        }
    }
}

#Preview {
    NavigationStack { CrewListView() }
        .modelContainer(for: [CrewMember.self, TrainingRecord.self], inMemory: true)
}
