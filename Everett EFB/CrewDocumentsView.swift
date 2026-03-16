import SwiftUI
import SwiftData

struct CrewDocumentsView: View {
    @Bindable var member: CrewMember

    private let cautionDays = 30

    var body: some View {
        List {
            Section("Crew") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text("\(member.name) \(member.surname)").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Role")
                    Spacer()
                    Text(member.role.rawValue).foregroundStyle(.secondary)
                }
                HStack {
                    Text("License")
                    Spacer()
                    Text(member.licenseNumber).foregroundStyle(.secondary)
                }
            }

            Section("Recencies") {
                CrewBoolRow(title: "Line training record", value: member.lineTrainingRecord)
                CrewBoolRow(title: "Line training report", value: member.lineTrainingReport)
                CrewBoolRow(title: "Induction checklist", value: member.inductionChecklist)
                CrewBoolRow(title: "CV", value: member.cv)
                CrewBoolRow(title: "Personal data sheet", value: member.personalDataSheet)
                CrewBoolRow(title: "Drug and alcohol policy", value: member.drugAndAlcoholPolicy)
                CrewBoolRow(title: "Internet usage policy", value: member.internetUsagePolicy)
            }

            Section("Training") {
                ForEach(TrainingType.allCases) { t in
                    let record = trainingRecord(for: t)
                    CrewDateRow(
                        title: t.rawValue,
                        last: record?.lastConducted,
                        expiry: record?.expiry,
                        status: Compliance.status(forExpiry: record?.expiry, cautionDays: cautionDays)
                    )
                }
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                NavigationLink("Edit") {
                    CrewFormView(mode: .edit(member))
                }
            }
        }
    }

    private func trainingRecord(for type: TrainingType) -> TrainingRecord? {
        member.trainings.first(where: { $0.typeRaw == type.rawValue })
    }
}

private struct CrewBoolRow: View {
    let title: String
    let value: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            StatusBadge(status: value ? .ok : .caution)
        }
        .padding(.vertical, 2)
    }
}

private struct CrewDateRow: View {
    let title: String
    let last: Date?
    let expiry: Date?
    let status: ComplianceStatus

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(last?.efbDate ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(expiry?.efbDate ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            StatusBadge(status: status)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
